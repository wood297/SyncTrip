"""Trip retrieval rules independent of HTTP."""
from backend.database.trips import TripRepository
from backend.models.trip import Trip


class TripNotFound(Exception):
    pass


def retrieve_trip(trip_id: str, repository: TripRepository) -> Trip:
    item = repository.get_trip(trip_id)
    if item is None:
        raise TripNotFound(trip_id)
    return Trip.model_validate(item)
