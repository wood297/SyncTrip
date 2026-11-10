"""Trip metadata operations, with no HTTP dependencies."""
from backend.database.trips import ConcurrentChange, TripRepository
from backend.models.trip import Trip


class TripNotFound(Exception):
    pass


def retrieve_trip(trip_id: str, repository: TripRepository) -> Trip:
    from backend.services.activities import decode_activity, require_trip
    item = require_trip(trip_id, repository)
    result = Trip.model_validate(item)
    # Preserve the original trip response shape; new-table records are authoritative.
    activities = dict(result.activities)
    for record in repository.list_activities(trip_id):
        activity = decode_activity(record)
        activities[str(activity.id)] = activity.model_dump(mode="json")
    return result.model_copy(update={"activities": activities})


def create_trip(payload, repository):
    from backend.services.activities import ActivityError
    item = payload.model_dump(mode="json")
    try:
        repository.create_trip(item)
    except ConcurrentChange:
        existing = repository.get_trip(payload.trip_id)
        if existing and not existing.get("_deleting") and all(existing.get(k) == v for k, v in item.items()):
            return retrieve_trip(payload.trip_id, repository)
        raise ActivityError(409, "Trip ID already exists with different data") from None
    return Trip.model_validate(item)


def update_trip(trip_id, changes, repository):
    from backend.services.activities import ActivityError, require_trip
    require_trip(trip_id, repository)
    try:
        repository.update_trip(trip_id, changes)
    except ConcurrentChange:
        require_trip(trip_id, repository)
        raise ActivityError(409, "Trip changed. Refresh and retry") from None
    return retrieve_trip(trip_id, repository)
