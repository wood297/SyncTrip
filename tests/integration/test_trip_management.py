import pytest
from botocore.exceptions import EndpointConnectionError

from backend.database.trips import TripRepository, get_repository
from backend.main import app

TRIP = {"trip_id": "new-trip", "name": "Prototype", "destination": "Chicago", "start_date": "2027-01-01"}
ACTIVITY = {"type": "custom", "title": "Museum", "start": "2027-01-01T10:00:00Z", "end": "2027-01-01T11:00:00Z"}


def test_trip_crud_and_activity_cascade(client, table, activities_table):
    result = client.post("/api/v1/trips", json=TRIP)
    assert result.status_code == 201
    assert result.json()["status"] == "planning"
    assert client.post("/api/v1/trips", json=TRIP).status_code == 201
    assert len(client.get("/api/v1/trips").json()["trips"]) == 1
    assert client.post("/api/v1/trips", json={**TRIP, "destination": "Boston"}).status_code == 409
    activity = client.post("/api/v1/trips/new-trip/activities", json=ACTIVITY).json()
    result = client.patch("/api/v1/trips/new-trip", json={"destination": "Boston"})
    assert result.status_code == 200
    assert result.json()["destination"] == "Boston"
    assert result.json()["activities"][activity["id"]] == activity
    assert client.put("/api/v1/trips/new-trip", json={k: v for k, v in TRIP.items() if k != "trip_id"}).status_code == 200
    assert client.delete("/api/v1/trips/new-trip").status_code == 204
    assert client.delete("/api/v1/trips/new-trip").status_code == 204
    assert client.get("/api/v1/trips/new-trip").status_code == 404
    assert "Item" not in table.get_item(Key={"trip_id": "new-trip"})
    assert "Item" not in activities_table.get_item(Key={"trip_id": "new-trip", "activity_id": activity["id"]})


@pytest.mark.parametrize("body", [{}, {"destination": None}, {"status": "invalid"}, {"start_date": "02/31/26"}, {"name": " "}, {"unexpected": "field"}])
def test_invalid_trip_patch(client, table, body):
    client.post("/api/v1/trips", json=TRIP)
    before = table.get_item(Key={"trip_id": "new-trip"})["Item"]
    assert client.patch("/api/v1/trips/new-trip", json=body).status_code == 422
    assert table.get_item(Key={"trip_id": "new-trip"})["Item"] == before


def test_new_trip_validation_and_missing_trip_update(client, table):
    assert client.post("/api/v1/trips", json={**TRIP, "trip_id": "bad/id"}).status_code == 422
    assert client.post("/api/v1/trips", json={**TRIP, "start_date": "2027-02-30"}).status_code == 422
    assert client.post("/api/v1/trips", json={**TRIP, "start_date": 1798761600}).status_code == 422
    assert client.patch("/api/v1/trips/missing", json={"name": "New"}).status_code == 404
    assert table.scan()["Items"] == []


def test_trip_list_pagination(client, table):
    for index in range(3):
        client.post("/api/v1/trips", json={**TRIP, "trip_id": f"trip-{index}"})
    repository = get_repository()
    original = repository.table.scan
    pages = []
    def paginated(**options):
        pages.append(options)
        return original(**options, Limit=1)
    repository.table.scan = paginated
    app.dependency_overrides[get_repository] = lambda: repository
    assert len(client.get("/api/v1/trips").json()["trips"]) == 3
    assert "ExclusiveStartKey" in pages[1]


def test_interrupted_delete_is_resumable_and_blocks_saves(client, table, monkeypatch):
    client.post("/api/v1/trips", json=TRIP)
    client.post("/api/v1/trips/new-trip/activities", json=ACTIVITY)
    original = TripRepository.list_activities
    def unavailable(*args):
        raise EndpointConnectionError(endpoint_url="https://example.invalid")
    monkeypatch.setattr(TripRepository, "list_activities", unavailable)
    assert client.delete("/api/v1/trips/new-trip").status_code == 503
    assert table.get_item(Key={"trip_id": "new-trip"})["Item"]["_deleting"] is True
    assert client.post("/api/v1/trips/new-trip/activities", json=ACTIVITY).status_code == 409
    assert client.get("/api/v1/trips").json()["trips"] == []
    monkeypatch.setattr(TripRepository, "list_activities", original)
    assert client.delete("/api/v1/trips/new-trip").status_code == 204


def test_database_readiness(client, table):
    result = client.get("/ready")
    assert result.status_code == 200
    assert result.json()["status"] == "ready"
    table.delete()
    assert client.get("/ready").status_code == 503


def test_readiness_rejects_wrong_activity_key_schema(client, table, activities_table):
    import boto3
    activities_table.delete()
    boto3.resource("dynamodb", region_name="us-east-2").create_table(
        TableName="SyncTripActivities", KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "id", "AttributeType": "S"}], BillingMode="PAY_PER_REQUEST",
    )
    response = client.get("/ready")
    assert response.status_code == 503
    assert response.json() == {"detail": "Database configuration is not ready"}


def test_custom_table_names_use_same_api(client, table, monkeypatch):
    import boto3
    resource = boto3.resource("dynamodb", region_name="us-east-2")
    resource.create_table(TableName="TeamTrips", KeySchema=[{"AttributeName": "trip_id", "KeyType": "HASH"}],
                          AttributeDefinitions=[{"AttributeName": "trip_id", "AttributeType": "S"}], BillingMode="PAY_PER_REQUEST")
    resource.create_table(TableName="TeamActivities", KeySchema=[{"AttributeName": "trip_id", "KeyType": "HASH"}, {"AttributeName": "activity_id", "KeyType": "RANGE"}],
                          AttributeDefinitions=[{"AttributeName": "trip_id", "AttributeType": "S"}, {"AttributeName": "activity_id", "AttributeType": "S"}], BillingMode="PAY_PER_REQUEST")
    monkeypatch.setenv("DYNAMODB_TRIPS_TABLE", "TeamTrips")
    monkeypatch.setenv("DYNAMODB_ACTIVITIES_TABLE", "TeamActivities")
    assert client.post("/api/v1/trips", json=TRIP).status_code == 201
    assert client.post("/api/v1/trips/new-trip/activities", json=ACTIVITY).status_code == 201
    assert table.scan()["Items"] == []
    assert len(resource.Table("TeamActivities").scan()["Items"]) == 1
