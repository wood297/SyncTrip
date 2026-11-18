"""Start the real API against a disposable, seeded Moto DynamoDB table.

Run: python -m backend.demo
Requires requirements-dev.txt. All demo data disappears when this process exits.

Seeds one Past, one Now, and one Upcoming trip. Known limitations:
- No end dates: trips store start_date only (backend models and iOS Trip). The
  Chicago trip is meant to run Nov 14-18, 2026; only its activities show that
  span, and status "active" keeps it in Now until it is set to completed.
- Time zones are not handled correctly yet: activity times are stored in UTC and
  the app shows them in the device's time zone, not the trip's. The local times
  in the comments below assume Chicago (UTC-6 in November).
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
        for trip in [
            # Past
            {"trip_id": "scotland-trip", "name": "Scotland Trip", "destination": "Edinburgh",
             "start_date": "2026-10-15", "status": "completed"},
            # Now: intended Nov 14-18, 2026 (no end_date field yet, see docstring)
            {"trip_id": "demo-trip", "name": "Chicago Weekend", "destination": "Chicago",
             "start_date": "2026-11-14", "status": "active"},
            # Upcoming
            {"trip_id": "miami-beach", "name": "Beach", "destination": "Miami",
             "start_date": "2027-05-20", "status": "planning"},
        ]:
            table.put_item(Item=trip)
        activities = boto3.resource("dynamodb", region_name="us-east-2").create_table(
            TableName="SyncTripActivities",
            KeySchema=[{"AttributeName": "trip_id", "KeyType": "HASH"}, {"AttributeName": "activity_id", "KeyType": "RANGE"}],
            AttributeDefinitions=[{"AttributeName": "trip_id", "AttributeType": "S"}, {"AttributeName": "activity_id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        # Times are UTC; Chicago local times in comments (see time zone note above).
        for activity_id, kind, title, start, end, location in [
            ("0c09f97c-04c7-4d16-bf86-8b1a2adf54be", "custom", "Museum visit",  # Nov 14, 10:00-12:00
             "2026-11-14T16:00:00Z", "2026-11-14T18:00:00Z", "Art Institute"),
            ("c6617680-2c1e-4948-bb57-1a1ae3455509", "food", "Deep-dish dinner",  # Nov 14, 18:00-19:30
             "2026-11-15T00:00:00Z", "2026-11-15T01:30:00Z", "River North"),
            ("e02b5708-76ba-4704-9952-ce22caacee5e", "custom", "Architecture boat tour",  # Nov 15, 11:00-12:30
             "2026-11-15T17:00:00Z", "2026-11-15T18:30:00Z", "Chicago River"),
            ("0fbbd0bc-9e2f-4473-8be7-312741385590", "transport", "Train home",  # Nov 18, 16:00-17:30
             "2026-11-18T22:00:00Z", "2026-11-18T23:30:00Z", "Union Station"),
        ]:
            activities.put_item(Item={
                "trip_id": "demo-trip", "activity_id": activity_id, "version": 1,
                "type": kind, "title": title, "start": start, "end": end,
                "details": {"Location": location}, "notes": "",
            })
        print("DEMO MODE: disposable emulated DynamoDB; no live AWS access.", flush=True)
        print(f"Open http://127.0.0.1:{args.port}/docs and retrieve demo-trip", flush=True)
        # No reload/workers: the Moto context must stay in this process.
        uvicorn.run("backend.main:app", host="127.0.0.1", port=args.port)


if __name__ == "__main__":
    main()
