from unittest.mock import Mock

import pytest
from botocore.exceptions import ClientError, NoCredentialsError, EndpointConnectionError

from backend.database.trips import TripRepository, get_repository
from backend.main import app
from backend.services.trips import TripNotFound, retrieve_trip


def test_repository_reads_by_key_without_scan():
    table = Mock()
    table.get_item.return_value = {"Item": {"trip_id": "trip001"}}
    assert TripRepository(table).get_trip("trip001") == {"trip_id": "trip001"}
    table.get_item.assert_called_once_with(Key={"trip_id": "trip001"}, ConsistentRead=True)
    table.scan.assert_not_called()


def test_missing_trip():
    repository = Mock()
    repository.get_trip.return_value = None
    with pytest.raises(TripNotFound):
        retrieve_trip("missing", repository)


@pytest.mark.parametrize("error", [
    NoCredentialsError(),
    EndpointConnectionError(endpoint_url="https://example.invalid"),
    ClientError({"Error": {"Code": "AccessDeniedException", "Message": "secret account info"}}, "GetItem"),
    ClientError({"Error": {"Code": "ProvisionedThroughputExceededException", "Message": "internal"}}, "GetItem"),
])
def test_database_errors_are_sanitized(client, error):
    def unavailable():
        raise error
    # Includes failures while creating the AWS resource dependency.
    app.dependency_overrides[get_repository] = unavailable
    response = client.get("/api/v1/trips/trip001")
    assert response.status_code == 503
    assert response.json() == {"detail": "Database unavailable"}


def test_invalid_id_never_calls_database(client):
    repository = Mock()
    app.dependency_overrides[get_repository] = lambda: repository
    assert client.get("/api/v1/trips/%20").status_code == 422
    repository.get_trip.assert_not_called()


def test_health_does_not_need_aws(client):
    def unavailable():
        raise AssertionError("Health must not connect to AWS")
    app.dependency_overrides[get_repository] = unavailable
    assert client.get("/health").json() == {"status": "ok"}
