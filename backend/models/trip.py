"""Response contract matching the existing DynamoDB trip format."""
from typing import Any

from pydantic import BaseModel, Field


class Trip(BaseModel):
    trip_id: str
    name: str
    destination: str
    # Existing CLI records use MM-DD-YYYY; preserve them without migration.
    start_date: str
    status: str
    activities: dict[str, Any] = Field(default_factory=dict)


class Error(BaseModel):
    detail: str
