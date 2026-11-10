from typing import Annotated
from fastapi import APIRouter, Depends, Path, Response
from backend.database.trips import TripRepository, get_repository
from backend.models.trip import Error, Trip, TripCreate, TripList, TripPatch, TripWrite
from backend.services.trips import create_trip, retrieve_trip, update_trip

router = APIRouter(prefix="/api/v1/trips", tags=["trips"], responses={
    404: {"model": Error}, 409: {"model": Error}, 503: {"model": Error}, 500: {"model": Error},
})
ID = Annotated[str, Path(min_length=1, max_length=2048, pattern=r"^\S+$")]
Repository = Annotated[TripRepository, Depends(get_repository)]


@router.get("", response_model=TripList)
def get_trips(repository: Repository):
    # Listing returns metadata, not N additional activity-table queries.
    return TripList(trips=sorted([Trip.model_validate(item) for item in repository.list_trips()],
                                 key=lambda trip: trip.trip_id))


@router.post("", response_model=Trip, status_code=201)
def post_trip(payload: TripCreate, repository: Repository):
    return create_trip(payload, repository)


@router.get("/{trip_id}", response_model=Trip)
def get_trip(trip_id: ID, repository: Repository):
    return retrieve_trip(trip_id, repository)


@router.put("/{trip_id}", response_model=Trip)
def put_trip(trip_id: ID, payload: TripWrite, repository: Repository):
    return update_trip(trip_id, payload.model_dump(mode="json"), repository)


@router.patch("/{trip_id}", response_model=Trip)
def patch_trip(trip_id: ID, payload: TripPatch, repository: Repository):
    return update_trip(trip_id, payload.model_dump(mode="json", exclude_unset=True), repository)


@router.delete("/{trip_id}", status_code=204)
def delete_trip(trip_id: ID, repository: Repository):
    repository.delete_trip(trip_id)
    return Response(status_code=204)
