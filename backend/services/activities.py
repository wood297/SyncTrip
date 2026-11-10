"""Online activities stored independently in SyncTripActivities."""
from backend.database.trips import ConcurrentChange, TripRepository
from backend.models.activity import Activity, ActivityList
from backend.services.trips import TripNotFound


class ActivityError(Exception):
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail


def require_trip(trip_id, repository):
    trip = repository.get_trip(trip_id)
    if trip is None:
        raise TripNotFound(trip_id)
    if trip.get("_deleting"):
        raise ActivityError(409, "Trip deletion is in progress. Retry deletion or choose another trip")
    return trip


def decode_activity(item):
    value = {key: val for key, val in item.items() if key not in ("trip_id", "activity_id")}
    value["id"] = item.get("activity_id")
    activity = Activity.model_validate(value)
    if activity.version is None:
        raise ActivityError(500, "Invalid stored record")
    return activity


def get_activity(trip_id, activity_id, repository):
    require_trip(trip_id, repository)
    item = repository.get_activity(trip_id, activity_id)
    if item is None:
        raise ActivityError(404, "Activity not found")
    return decode_activity(item)


def list_activities(trip_id: str, repository: TripRepository) -> ActivityList:
    trip = require_trip(trip_id, repository)
    records = repository.list_activities(trip_id)
    activities = [decode_activity(item) for item in records]
    known = {str(item.id) for item in activities}
    legacy = trip.get("activities", {})
    count = len(set(legacy) - known) if isinstance(legacy, dict) else 1
    return ActivityList(activities=sorted(activities, key=lambda a: (a.start, str(a.id))),
                        legacy_activity_count=count)


def content(activity):
    return activity.model_dump(mode="json", exclude={"version"})


def mutate_activity(trip_id: str, activity_id: str, repository: TripRepository,
                    activity: Activity | None, operation: str):
    for _ in range(3):
        require_trip(trip_id, repository)
        previous = repository.get_activity(trip_id, activity_id)
        existing = decode_activity(previous) if previous else None
        if operation == "create" and existing:
            if content(existing) == content(activity):
                return existing
            raise ActivityError(409, "Activity ID already exists with different data")
        if operation == "delete" and not existing:
            return None  # Idempotent after a lost success response.
        if operation == "update":
            if not existing:
                raise ActivityError(404, "Activity not found")
            if activity.version is None:
                raise ActivityError(422, "Include the version returned by GET when editing")
            if activity.version != existing.version:
                if content(activity) == content(existing):
                    return existing  # Safe retry of an edit that already succeeded.
                raise ActivityError(409, "Activity changed. Reload it before editing")
        expected = existing.version if existing else None
        saved = None
        item = None
        if activity is not None:
            saved = activity.model_copy(update={"version": 1 if operation == "create" else expected + 1})
            item = saved.model_dump(mode="json", exclude={"id"})
            item.update(trip_id=trip_id, activity_id=activity_id)
        try:
            repository.write_activity(trip_id, activity_id, item, expected, operation == "delete")
            return saved
        except ConcurrentChange:
            continue
    raise ActivityError(409, "Concurrent change. Refresh and retry")
