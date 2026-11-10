"""Database access without HTTP or presentation logic."""
import boto3
from botocore.config import Config

from backend.config import Settings


class TripRepository:
    def __init__(self, table):
        self.table = table

    def get_trip(self, trip_id: str) -> dict | None:
        response = self.table.get_item(Key={"trip_id": trip_id}, ConsistentRead=True)
        return response.get("Item")


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
