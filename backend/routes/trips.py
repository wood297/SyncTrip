from typing import Annotated

from fastapi import APIRouter, Depends, Path

from backend.database.trips import TripRepository, get_repository
from backend.models.trip import Error, Trip
from backend.services.trips import retrieve_trip

router = APIRouter(prefix="/api/v1/trips", tags=["trips"])


@router.get("/{trip_id}", response_model=Trip, responses={
    404: {"model": Error}, 503: {"model": Error}, 500: {"model": Error},
})
def get_trip(
    trip_id: Annotated[str, Path(min_length=1, max_length=2048, pattern=r"^\S+$")],
    repository: Annotated[TripRepository, Depends(get_repository)],
) -> Trip:
    return retrieve_trip(trip_id, repository)
