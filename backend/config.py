"""Environment configuration. Credentials use the AWS provider chain."""
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    region: str
    table_name: str
    activities_table_name: str
    endpoint_url: str | None

    @classmethod
    def from_env(cls):
        return cls(
            region=os.getenv("AWS_REGION", "us-east-2"),
            table_name=os.getenv("DYNAMODB_TRIPS_TABLE") or os.getenv("DYNAMODB_TABLE_NAME", "SyncTripTrips"),
            activities_table_name=os.getenv("DYNAMODB_ACTIVITIES_TABLE", "SyncTripActivities"),
            endpoint_url=os.getenv("DYNAMODB_ENDPOINT_URL") or None,
        )
