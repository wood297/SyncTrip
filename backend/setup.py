"""Check both configured tables, or explicitly create missing tables once."""
import argparse
import json

from botocore.exceptions import BotoCoreError, ClientError

from backend.database.trips import aws_connections


class ConfigurationError(Exception):
    pass


def table_definitions(settings):
    return [
        (settings.table_name, [{"AttributeName": "trip_id", "KeyType": "HASH"}]),
        (settings.activities_table_name, [{"AttributeName": "trip_id", "KeyType": "HASH"},
                                          {"AttributeName": "activity_id", "KeyType": "RANGE"}]),
    ]


def check_tables(settings, client):
    if settings.table_name == settings.activities_table_name:
        raise ConfigurationError("Trips and activities must use different tables")
    summaries = []
    for name, keys in table_definitions(settings):
        table = client.describe_table(TableName=name)["Table"]
        types = {item["AttributeName"]: item["AttributeType"] for item in table["AttributeDefinitions"]}
        expected = {key["KeyType"]: key["AttributeName"] for key in keys}
        actual = {key["KeyType"]: key["AttributeName"] for key in table["KeySchema"]}
        if actual != expected or any(
            types.get(key["AttributeName"]) != "S" for key in keys
        ):
            raise ConfigurationError(f"{name} has an incompatible key schema")
        if table["TableStatus"] != "ACTIVE":
            raise ConfigurationError(f"{name} is not ACTIVE")
        summaries.append({"name": name, "status": "ACTIVE", "keys": keys})
    # Verify read permissions without returning any real trip data.
    client.get_item(TableName=settings.table_name, Key={"trip_id": {"S": "_synctrip_readiness_"}}, ConsistentRead=True)
    client.query(TableName=settings.activities_table_name,
                 KeyConditionExpression="trip_id = :trip", ExpressionAttributeValues={":trip": {"S": "_synctrip_readiness_"}},
                 ConsistentRead=True, Limit=1)
    return {"status": "ready", "region": settings.region, "tables": summaries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--create-missing", action="store_true")
    parser.add_argument("--check", action="store_true", help="Read-only schema/access check (default)")
    args = parser.parse_args()
    try:
        settings, _, client = aws_connections()
        if args.create_missing:
            for name, keys in table_definitions(settings):
                try:
                    client.describe_table(TableName=name)
                except client.exceptions.ResourceNotFoundException:
                    client.create_table(TableName=name, KeySchema=keys,
                                        AttributeDefinitions=[{"AttributeName": key["AttributeName"], "AttributeType": "S"} for key in keys],
                                        BillingMode="PAY_PER_REQUEST")
                    client.get_waiter("table_exists").wait(TableName=name, WaiterConfig={"Delay": 1, "MaxAttempts": 30})
        print(json.dumps(check_tables(settings, client), indent=2))
        return 0
    except ConfigurationError as error:
        print(f"SETUP FAILED: {error}")
    except (BotoCoreError, ClientError) as error:
        code = error.response["Error"]["Code"] if isinstance(error, ClientError) else type(error).__name__
        print(f"SETUP FAILED: {code}. Check AWS identity, region, table names, and IAM permissions.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
