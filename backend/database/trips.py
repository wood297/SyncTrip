"""Two-table DynamoDB repository. No HTTP or UI dependencies."""
import boto3
from boto3.dynamodb.conditions import Attr, Key
from boto3.dynamodb.types import TypeSerializer
from botocore.config import Config
from botocore.exceptions import ClientError

from backend.config import Settings


class ConcurrentChange(Exception):
    pass


def encode(item):
    serializer = TypeSerializer()
    return {key: serializer.serialize(value) for key, value in item.items()}


class TripRepository:
    def __init__(self, table, activities_table=None, transaction_client=None):
        self.table = table
        self.activities_table = activities_table
        self.transaction_client = transaction_client

    def get_trip(self, trip_id: str) -> dict | None:
        return self.table.get_item(Key={"trip_id": trip_id}, ConsistentRead=True).get("Item")

    def list_trips(self):
        items, options = [], {"ConsistentRead": True}
        while True:
            response = self.table.scan(**options)
            items.extend(item for item in response.get("Items", []) if not item.get("_deleting"))
            if not response.get("LastEvaluatedKey"):
                return items
            options["ExclusiveStartKey"] = response["LastEvaluatedKey"]

    def create_trip(self, item):
        try:
            self.table.put_item(Item=item, ConditionExpression=Attr("trip_id").not_exists())
        except ClientError as error:
            self._raise_conditional(error)

    def update_trip(self, trip_id, changes):
        names = {f"#f{i}": key for i, key in enumerate(changes)}
        values = {f":v{i}": value for i, value in enumerate(changes.values())}
        expression = "SET " + ", ".join(f"#f{i} = :v{i}" for i in range(len(changes)))
        try:
            return self.table.update_item(
                Key={"trip_id": trip_id}, UpdateExpression=expression,
                ExpressionAttributeNames=names, ExpressionAttributeValues=values,
                ConditionExpression=Attr("trip_id").exists() & Attr("_deleting").not_exists(),
                ReturnValues="ALL_NEW",
            )["Attributes"]
        except ClientError as error:
            self._raise_conditional(error)

    def list_activities(self, trip_id):
        items = []
        options = {"KeyConditionExpression": Key("trip_id").eq(trip_id), "ConsistentRead": True}
        while True:
            response = self.activities_table.query(**options)
            items.extend(response.get("Items", []))
            if not response.get("LastEvaluatedKey"):
                return items
            options["ExclusiveStartKey"] = response["LastEvaluatedKey"]

    def get_activity(self, trip_id, activity_id):
        return self.activities_table.get_item(
            Key={"trip_id": trip_id, "activity_id": activity_id}, ConsistentRead=True,
        ).get("Item")

    def write_activity(self, trip_id, activity_id, item=None, expected_version=None, delete=False):
        # A low-level client is used here deliberately; it takes AttributeValue maps.
        parent = {"ConditionCheck": {
            "TableName": self.table.name, "Key": encode({"trip_id": trip_id}),
            "ConditionExpression": "attribute_exists(trip_id) AND attribute_not_exists(#deleting)",
            "ExpressionAttributeNames": {"#deleting": "_deleting"},
        }}
        condition = "attribute_not_exists(activity_id)" if expected_version is None else "#version = :version"
        operation = {"TableName": self.activities_table.name, "ConditionExpression": condition}
        if expected_version is not None:
            operation.update(ExpressionAttributeNames={"#version": "version"},
                             ExpressionAttributeValues=encode({":version": expected_version}))
        if delete:
            operation["Key"] = encode({"trip_id": trip_id, "activity_id": activity_id})
        else:
            operation["Item"] = encode(item)
        try:
            self.transaction_client.transact_write_items(
                TransactItems=[parent, {"Delete" if delete else "Put": operation}],
            )
        except ClientError as error:
            code = error.response["Error"]["Code"]
            reasons = error.response.get("CancellationReasons", [])
            if code == "TransactionCanceledException" and reasons and all(
                reason.get("Code") in ("None", "ConditionalCheckFailed", "TransactionConflict") for reason in reasons
            ):
                raise ConcurrentChange from error
            if code == "TransactionConflictException":
                raise ConcurrentChange from error
            raise

    def delete_trip(self, trip_id):
        # Mark first so transactional activity writes cannot race the cascade.
        try:
            self.table.update_item(
                Key={"trip_id": trip_id}, UpdateExpression="SET #deleting = :yes",
                ExpressionAttributeNames={"#deleting": "_deleting"},
                ExpressionAttributeValues={":yes": True},
                ConditionExpression=Attr("trip_id").exists(),
            )
        except ClientError as error:
            if error.response["Error"]["Code"] == "ConditionalCheckFailedException":
                return
            raise
        for activity in self.list_activities(trip_id):
            self.activities_table.delete_item(Key={"trip_id": trip_id, "activity_id": activity["activity_id"]})
        self.table.delete_item(Key={"trip_id": trip_id}, ConditionExpression=Attr("_deleting").eq(True))

    @staticmethod
    def _raise_conditional(error):
        if error.response["Error"]["Code"] == "ConditionalCheckFailedException":
            raise ConcurrentChange from error
        raise error


def aws_connections():
    settings = Settings.from_env()
    session = boto3.session.Session()
    options = dict(region_name=settings.region, endpoint_url=settings.endpoint_url,
                   config=Config(connect_timeout=3, read_timeout=5,
                                 retries={"mode": "standard", "total_max_attempts": 3}))
    return settings, session.resource("dynamodb", **options), session.client("dynamodb", **options)


def get_repository() -> TripRepository:
    settings, resource, client = aws_connections()
    return TripRepository(resource.Table(settings.table_name), resource.Table(settings.activities_table_name), client)
