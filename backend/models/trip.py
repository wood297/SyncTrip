"""Trip metadata and write contracts. Reads preserve legacy date strings."""
from datetime import date
import re
from typing import Annotated, Any, Literal
from uuid import uuid4
from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator, model_validator

Text = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]
TripID = Annotated[str, StringConstraints(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")]
Status = Literal["planning", "active", "completed", "cancelled"]


class TripMetadata(BaseModel):
    trip_id: str
    name: str
    destination: str
    start_date: str
    status: str


class Trip(TripMetadata):
    activities: dict[str, Any] = Field(default_factory=dict)


class TripWrite(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: Text
    destination: Text
    start_date: date
    status: Status = "planning"

    @field_validator("start_date", mode="before")
    @classmethod
    def iso_date_only(cls, value):
        if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            raise ValueError("Use a YYYY-MM-DD date")
        return value


class TripCreate(TripWrite):
    trip_id: TripID = Field(default_factory=lambda: str(uuid4()))


class TripPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: Text | None = None
    destination: Text | None = None
    start_date: date | None = None
    status: Status | None = None

    @field_validator("start_date", mode="before")
    @classmethod
    def iso_date_only(cls, value):
        return TripWrite.iso_date_only(value)

    @model_validator(mode="after")
    def require_changes(self):
        if not self.model_fields_set or any(getattr(self, key) is None for key in self.model_fields_set):
            raise ValueError("Provide at least one non-null field")
        return self


class TripList(BaseModel):
    trips: list[TripMetadata]


class Error(BaseModel):
    detail: str
