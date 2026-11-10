from copy import deepcopy
from uuid import uuid4

import pytest

from backend.database.trips import ConcurrentChange, TripRepository, get_repository
from backend.main import app

BASE = "/api/v1/trips/trip001/activities"


@pytest.fixture
def trip(table):
    item = {"trip_id": "trip001", "name": "Prototype", "destination": "Chicago",
            "start_date": "2026-11-14", "status": "planning"}
    table.put_item(Item=item)
    return table


@pytest.fixture
def payload():
    # Matches JSONEncoder's UUID and ISO 8601 output from the Swift form.
    return {"id": str(uuid4()).upper(), "type": "custom", "title": "Museum visit",
            "start": "2026-11-14T10:00:00-06:00", "end": "2026-11-14T12:00:00-06:00",
            "details": {"Location": "Chicago"}, "notes": "Bring tickets"}


def test_create_reload_edit_delete_persists(client, trip, activities_table, payload):
    created = client.post(BASE, json=payload)
    assert created.status_code == 201
    activity = created.json()
    assert activity["id"] == payload["id"].lower()
    assert activity["start"] == "2026-11-14T16:00:00Z"
    assert activity["end"] == "2026-11-14T18:00:00Z"
    assert activity["details"] == payload["details"]
    stored = trip.get_item(Key={"trip_id": "trip001"}, ConsistentRead=True)["Item"]
    assert "activities" not in stored
    record = activities_table.get_item(Key={"trip_id": "trip001", "activity_id": activity["id"]}, ConsistentRead=True)["Item"]
    assert record["title"] == activity["title"]
    assert record["version"] == 1
    assert "id" not in record
    assert stored["destination"] == "Chicago"
    assert client.get(BASE).json() == {"activities": [activity], "legacy_activity_count": 0}
    assert client.get("/api/v1/trips/trip001").json()["activities"][activity["id"]] == activity

    activity["title"] = "Updated museum visit"
    url = BASE + "/" + activity["id"]
    edited = client.put(url, json=activity)
    assert edited.status_code == 200
    activity["version"] = 2
    assert edited.json() == activity
    assert client.get(BASE).json()["activities"] == [activity]
    assert client.delete(url).status_code == 204
    assert client.get(BASE).json()["activities"] == []
    assert "activities" not in trip.get_item(Key={"trip_id": "trip001"})["Item"]
    assert "Item" not in activities_table.get_item(Key={"trip_id": "trip001", "activity_id": activity["id"]})


@pytest.mark.parametrize("kind", ["flight", "food", "transport", "hotel", "custom"])
def test_all_swift_types(client, trip, payload, kind):
    payload["type"] = kind
    assert client.post(BASE, json=payload).status_code == 201


def test_retry_same_id_is_not_a_duplicate(client, trip, payload):
    first = client.post(BASE, json=payload)
    again = client.post(BASE, json=payload)
    assert first.status_code == again.status_code == 201
    assert first.json() == again.json()
    assert len(client.get(BASE).json()["activities"]) == 1
    payload["title"] = "Different data"
    assert client.post(BASE, json=payload).status_code == 409
    assert client.get(BASE).json()["activities"][0]["title"] == "Museum visit"


def test_server_assigns_id_if_omitted(client, trip, payload):
    del payload["id"]
    response = client.post(BASE, json=payload)
    assert response.status_code == 201
    assert response.json()["id"]


@pytest.mark.parametrize("changes", [
    {"title": " \n "}, {"title": "x" * 201}, {"type": "other"},
    {"start": "2026-11-14T10:00:00"}, {"end": "not a date"},
    {"end": "2026-11-14T09:59:00-06:00"}, {"start": 123456789},
    {"id": "not-a-uuid"}, {"details": {"Location": 123}},
    {"notes": "x" * 5001}, {"unknown": "reject me"},
])
def test_invalid_activity_does_not_write(client, trip, payload, changes):
    before = trip.get_item(Key={"trip_id": "trip001"})["Item"]
    payload.update(changes)
    assert client.post(BASE, json=payload).status_code == 422
    assert trip.get_item(Key={"trip_id": "trip001"})["Item"] == before


def test_missing_trip_never_creates_phantom_trip(client, table, payload):
    assert client.post(BASE, json=payload).status_code == 404
    assert client.get(BASE).status_code == 404
    assert "Item" not in table.get_item(Key={"trip_id": "trip001"})


def test_missing_activity_and_mismatched_ids(client, trip, payload):
    url = BASE + "/" + payload["id"]
    assert client.put(url, json=payload).status_code == 404
    assert client.delete(url).status_code == 204
    assert client.put(BASE + "/" + str(uuid4()), json=payload).status_code == 422


def test_legacy_records_preserved_and_reported(client, trip, payload):
    legacy = {"old-id": {"title": "Old activity", "scheduled_at": "2026-11-14 10:00", "location": "Chicago"}}
    trip.update_item(Key={"trip_id": "trip001"}, UpdateExpression="SET activities = :a",
                     ExpressionAttributeValues={":a": legacy})
    assert client.post(BASE, json=payload).status_code == 201
    result = client.get(BASE).json()
    assert len(result["activities"]) == 1
    assert result["legacy_activity_count"] == 1
    assert trip.get_item(Key={"trip_id": "trip001"})["Item"]["activities"]["old-id"] == legacy["old-id"]


def test_independent_adds_are_preserved(client, trip, payload):
    other = deepcopy(payload)
    other["id"] = str(uuid4())
    other["title"] = "Other traveler"
    assert client.post(BASE, json=other).status_code == 201
    assert client.post(BASE, json=payload).status_code == 201
    assert {a["title"] for a in client.get(BASE).json()["activities"]} == {"Museum visit", "Other traveler"}


def test_deleted_trip_is_not_recreated_by_inflight_write(client, trip, payload, monkeypatch):
    original = TripRepository.write_activity
    def deleting_save(self, trip_id, *args):
        trip.delete_item(Key={"trip_id": trip_id})
        return original(self, trip_id, *args)
    monkeypatch.setattr(TripRepository, "write_activity", deleting_save)
    assert client.post(BASE, json=payload).status_code == 404
    assert "Item" not in trip.get_item(Key={"trip_id": "trip001"})


def test_repeated_concurrent_writes_return_conflict(client, trip, payload, monkeypatch):
    def conflict(*args):
        raise ConcurrentChange
    monkeypatch.setattr(TripRepository, "write_activity", conflict)
    assert client.post(BASE, json=payload).status_code == 409
    assert client.get(BASE).json()["activities"] == []


def test_write_access_error_is_sanitized(client, trip, payload, monkeypatch):
    from botocore.exceptions import ClientError
    def denied(*args):
        raise ClientError({"Error": {"Code": "AccessDeniedException", "Message": "private"}}, "TransactWriteItems")
    monkeypatch.setattr(TripRepository, "write_activity", denied)
    response = client.post(BASE, json=payload)
    assert response.status_code == 503
    assert response.json() == {"detail": "Database unavailable"}


def test_stale_edit_rejected_and_success_retry_is_idempotent(client, trip, payload):
    first = client.post(BASE, json=payload).json()
    url = BASE + "/" + first["id"]
    edited = {**first, "title": "Winner"}
    assert client.put(url, json=edited).json()["version"] == 2
    assert client.put(url, json=edited).json()["version"] == 2
    stale = {**first, "title": "Stale edit"}
    assert client.put(url, json=stale).status_code == 409
    assert client.get(url).json()["title"] == "Winner"
    del edited["version"]
    assert client.put(url, json=edited).status_code == 422


def test_same_activity_id_is_isolated_between_trips(client, trip, payload):
    trip.put_item(Item={"trip_id": "other", "name": "Other", "destination": "Boston", "start_date": "2026-11-14", "status": "planning"})
    first = client.post(BASE, json=payload).json()
    assert client.get("/api/v1/trips/other/activities/" + first["id"]).status_code == 404
    assert client.get("/api/v1/trips/other/activities").json()["activities"] == []
    assert client.post("/api/v1/trips/other/activities", json=payload).status_code == 201
    client.delete(BASE + "/" + first["id"])
    assert len(client.get("/api/v1/trips/other/activities").json()["activities"]) == 1


def test_activity_query_follows_all_pages(client, trip, payload):
    repository = get_repository()
    original = repository.activities_table.query
    pages = []
    def paginated(**options):
        pages.append(options)
        return original(**options, Limit=1)
    repository.activities_table.query = paginated
    app.dependency_overrides[get_repository] = lambda: repository
    for title in ["First", "Second", "Third"]:
        value = {**payload, "id": str(uuid4()), "title": title}
        assert client.post(BASE, json=value).status_code == 201
    assert len(client.get(BASE).json()["activities"]) == 3
    assert len(pages) >= 3
    assert "ExclusiveStartKey" in pages[1]
