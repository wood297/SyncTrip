def test_existing_trip_and_activities(client, table):
    trip = {
        "trip_id": "trip001", "name": "Scotland Trip", "destination": "Edinburgh",
        "start_date": "10-15-2026", "status": "planning",
        "activities": {"a1": {"title": "Museum", "scheduled_at": "2026-10-15 10:00", "location": "Old Town"}},
    }
    table.put_item(Item=trip)
    response = client.get("/api/v1/trips/trip001")
    assert response.status_code == 200
    assert response.json() == trip
    assert table.get_item(Key={"trip_id": "trip001"})["Item"] == trip


def test_old_trip_without_activities(client, table):
    trip = {"trip_id": "old", "name": "Beach", "destination": "Miami",
            "start_date": "2027-05-20", "status": "planning"}
    table.put_item(Item=trip)
    assert client.get("/api/v1/trips/old").json() == {**trip, "activities": {}}


def test_missing_trip_returns_404(client, table):
    response = client.get("/api/v1/trips/missing")
    assert response.status_code == 404
    assert response.json() == {"detail": "Trip not found"}


def test_missing_table_is_not_reported_as_missing_trip(client, table):
    table.delete()
    assert client.get("/api/v1/trips/trip001").status_code == 503


def test_malformed_record_returns_sanitized_error(client, table):
    table.put_item(Item={"trip_id": "broken", "private": "secret"})
    response = client.get("/api/v1/trips/broken")
    assert response.status_code == 500
    assert response.json() == {"detail": "Invalid stored record"}


def test_openapi_documents_contract(client):
    schema = client.get("/openapi.json").json()
    responses = schema["paths"]["/api/v1/trips/{trip_id}"]["get"]["responses"]
    assert {"200", "404", "422", "500", "503"} <= responses.keys()
