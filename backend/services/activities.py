"""Online activity operations. This is not an offline merge protocol."""
from pydantic import ValidationError

from backend.database.trips import ConcurrentChange, TripRepository
from backend.models.activity import Activity, ActivityList
from backend.services.trips import TripNotFound


class ActivityError(Exception):
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail


def activity_map(trip_id: str, repository: TripRepository) -> dict:
    trip = repository.get_trip(trip_id)
    if trip is None:
        raise TripNotFound(trip_id)
    activities = trip.get("activities", {})
    if not isinstance(activities, dict):
        raise ActivityError(409, "Trip activities need migration before use")
    return activities


def list_activities(trip_id: str, repository: TripRepository) -> ActivityList:
    activities, legacy_count = [], 0
    for key, value in activity_map(trip_id, repository).items():
        try:
            activity = Activity.model_validate(value)
            if str(activity.id) != key:
                raise ValueError("Stored ID differs from map key")
            activities.append(activity)
        except (ValidationError, ValueError):
            # Never invent end times, types, or timezones for old records.
            legacy_count += 1
    return ActivityList(activities=sorted(activities, key=lambda a: (a.start, str(a.id))),
                        legacy_activity_count=legacy_count)


def mutate_activity(trip_id: str, activity_id: str, repository: TripRepository,
                    activity: Activity | None, operation: str):
    for _ in range(3):
        previous = activity_map(trip_id, repository)
        existing = previous.get(activity_id)
        if operation == "create" and existing is not None:
            try:
                if Activity.model_validate(existing) == activity:
                    return activity  # Retry of a successful create, not a duplicate.
            except ValidationError:
                pass
            raise ActivityError(409, "Activity ID already exists with different data")
        if operation != "create" and existing is None:
            raise ActivityError(404, "Activity not found")
        updated = dict(previous)
        if operation == "delete":
            del updated[activity_id]
        else:
            updated[activity_id] = activity.model_dump(mode="json")
        try:
            repository.save_activities(trip_id, updated, previous)
            return activity
        except ConcurrentChange:
            continue
    raise ActivityError(409, "Trip changed while saving. Refresh and try again")
