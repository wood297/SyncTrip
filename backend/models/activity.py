"""Activity contract shared with ios/Models/Activity.swift."""
from datetime import datetime, timezone
from typing import Annotated, Literal
from uuid import UUID, uuid4

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, StringConstraints, field_validator, model_validator

Title = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
DetailKey = Annotated[str, StringConstraints(min_length=1, max_length=100)]
DetailValue = Annotated[str, StringConstraints(max_length=2000)]


class Activity(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: UUID = Field(default_factory=uuid4)
    type: Literal["flight", "food", "transport", "hotel", "custom"]
    title: Title
    start: AwareDatetime
    end: AwareDatetime
    details: dict[DetailKey, DetailValue] = Field(default_factory=dict, max_length=20)
    notes: str = Field(default="", max_length=5000)

    @field_validator("start", "end", mode="before")
    @classmethod
    def require_timestamp(cls, value):
        # Reject numeric epoch values; clients must send ISO 8601 timestamps.
        if not isinstance(value, (str, datetime)):
            raise ValueError("Use an ISO 8601 timestamp with a timezone")
        return value

    @field_validator("start", "end")
    @classmethod
    def normalize_timezone(cls, value):
        return value.astimezone(timezone.utc)

    @model_validator(mode="after")
    def validate_time_range(self):
        if self.end < self.start:
            raise ValueError("End must not be before start")
        return self


class ActivityList(BaseModel):
    activities: list[Activity]
    legacy_activity_count: int = 0
