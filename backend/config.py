"""Environment configuration; credentials use the standard AWS provider chain."""
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    region: str
    table_name: str
    endpoint_url: str | None

    @classmethod
    def from_env(cls):
        return cls(
            region=os.getenv("AWS_REGION", "us-east-2"),
            table_name=os.getenv("DYNAMODB_TABLE_NAME", "SyncTripTrips"),
            endpoint_url=os.getenv("DYNAMODB_ENDPOINT_URL") or None,
        )
