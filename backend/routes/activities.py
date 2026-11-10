from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Path, Response

from backend.database.trips import TripRepository, get_repository
from backend.models.activity import Activity, ActivityList
from backend.models.trip import Error
from backend.services.activities import ActivityError, list_activities, mutate_activity

router = APIRouter(prefix="/api/v1/trips", tags=["activities"], responses={
    404: {"model": Error}, 409: {"model": Error}, 503: {"model": Error},
})
TripID = Annotated[str, Path(min_length=1, max_length=2048, pattern=r"^\S+$")]
Repository = Annotated[TripRepository, Depends(get_repository)]


@router.get("/{trip_id}/activities", response_model=ActivityList)
def get_activities(trip_id: TripID, repository: Repository):
    return list_activities(trip_id, repository)


@router.post("/{trip_id}/activities", response_model=Activity, status_code=201)
def create_activity(trip_id: TripID, activity: Activity, repository: Repository):
    return mutate_activity(trip_id, str(activity.id), repository, activity, "create")


@router.put("/{trip_id}/activities/{activity_id}", response_model=Activity)
def update_activity(trip_id: TripID, activity_id: UUID, activity: Activity, repository: Repository):
    if activity_id != activity.id:
        raise ActivityError(422, "Path and body activity IDs must match")
    return mutate_activity(trip_id, str(activity_id), repository, activity, "update")


@router.delete("/{trip_id}/activities/{activity_id}", status_code=204)
def delete_activity(trip_id: TripID, activity_id: UUID, repository: Repository):
    mutate_activity(trip_id, str(activity_id), repository, None, "delete")
    return Response(status_code=204)
