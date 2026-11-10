"""Database access without HTTP or presentation logic."""
import boto3
from boto3.dynamodb.conditions import Attr
from botocore.config import Config
from botocore.exceptions import ClientError

from backend.config import Settings


class ConcurrentChange(Exception):
    pass


class TripRepository:
    def __init__(self, table):
        self.table = table

    def get_trip(self, trip_id: str) -> dict | None:
        response = self.table.get_item(Key={"trip_id": trip_id}, ConsistentRead=True)
        return response.get("Item")

    def save_activities(self, trip_id: str, activities: dict, previous: dict):
        condition = Attr("activities").eq(previous)
        if not previous:
            condition = condition | Attr("activities").not_exists()
        try:
            self.table.update_item(
                Key={"trip_id": trip_id},
                UpdateExpression="SET activities = :activities",
                ExpressionAttributeValues={":activities": activities},
                ConditionExpression=Attr("trip_id").exists() & condition,
            )
        except ClientError as error:
            if error.response["Error"]["Code"] == "ConditionalCheckFailedException":
                raise ConcurrentChange from error
            raise


def get_repository() -> TripRepository:
    # Construct per request: no AWS calls at import, no shared boto3 resource
    # across FastAPI worker threads. SDK retries and timeouts are bounded.
    settings = Settings.from_env()
    resource = boto3.resource(
        "dynamodb",
        region_name=settings.region,
        endpoint_url=settings.endpoint_url,
        config=Config(connect_timeout=3, read_timeout=5,
                      retries={"mode": "standard", "total_max_attempts": 3}),
    )
    return TripRepository(resource.Table(settings.table_name))
