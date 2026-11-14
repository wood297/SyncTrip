"""Start the real API against a disposable, seeded Moto DynamoDB table.

Run: python -m backend.demo
Requires requirements-dev.txt. All demo data disappears when this process exits.
"""
import argparse
import os

import boto3
import uvicorn
from moto import mock_aws


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    # These changes affect only this demo process, never the user's AWS config.
    for key in ("AWS_PROFILE", "AWS_DEFAULT_PROFILE", "DYNAMODB_ENDPOINT_URL"):
        os.environ.pop(key, None)
    os.environ.update(
        AWS_ACCESS_KEY_ID="testing",
        AWS_SECRET_ACCESS_KEY="testing",
        AWS_SESSION_TOKEN="testing",
        AWS_REGION="us-east-2",
        DYNAMODB_TABLE_NAME="SyncTripTrips",
        DYNAMODB_TRIPS_TABLE="SyncTripTrips",
        DYNAMODB_ACTIVITIES_TABLE="SyncTripActivities",
    )
    with mock_aws():
        table = boto3.resource("dynamodb", region_name="us-east-2").create_table(
            TableName="SyncTripTrips",
            KeySchema=[{"AttributeName": "trip_id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "trip_id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        table.put_item(Item={
            "trip_id": "demo-trip", "name": "SyncTrip verification demo",
            "destination": "Chicago", "start_date": "11-14-2026",
            "status": "planning",
        })
        activities = boto3.resource("dynamodb", region_name="us-east-2").create_table(
            TableName="SyncTripActivities",
            KeySchema=[{"AttributeName": "trip_id", "KeyType": "HASH"}, {"AttributeName": "activity_id", "KeyType": "RANGE"}],
            AttributeDefinitions=[{"AttributeName": "trip_id", "AttributeType": "S"}, {"AttributeName": "activity_id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        activities.put_item(Item={
            "trip_id": "demo-trip", "activity_id": "0c09f97c-04c7-4d16-bf86-8b1a2adf54be",
            "version": 1, "type": "custom", "title": "Museum visit",
            "start": "2026-11-14T16:00:00Z", "end": "2026-11-14T18:00:00Z",
            "details": {"Location": "Chicago"}, "notes": "",
        })
        print("DEMO MODE: disposable emulated DynamoDB; no live AWS access.", flush=True)
        print(f"Open http://127.0.0.1:{args.port}/docs and retrieve demo-trip", flush=True)
        # No reload/workers: the Moto context must stay in this process.
        uvicorn.run("backend.main:app", host="127.0.0.1", port=args.port)


if __name__ == "__main__":
    main()
