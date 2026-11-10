import boto3
import pytest
from fastapi.testclient import TestClient
from moto import mock_aws

from backend.main import app


@pytest.fixture
def client():
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()


@pytest.fixture
def table(monkeypatch):
    # Explicit dummy credentials and Moto prevent tests reaching AWS.
    for key in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN"):
        monkeypatch.setenv(key, "testing")
    monkeypatch.setenv("AWS_REGION", "us-east-2")
    monkeypatch.setenv("DYNAMODB_TABLE_NAME", "SyncTripTrips")
    monkeypatch.setenv("DYNAMODB_TRIPS_TABLE", "SyncTripTrips")
    monkeypatch.setenv("DYNAMODB_ACTIVITIES_TABLE", "SyncTripActivities")
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    monkeypatch.delenv("AWS_DEFAULT_PROFILE", raising=False)
    monkeypatch.delenv("DYNAMODB_ENDPOINT_URL", raising=False)
    with mock_aws():
        resource = boto3.resource("dynamodb", region_name="us-east-2")
        resource.create_table(
            TableName="SyncTripActivities",
            KeySchema=[{"AttributeName": "trip_id", "KeyType": "HASH"}, {"AttributeName": "activity_id", "KeyType": "RANGE"}],
            AttributeDefinitions=[{"AttributeName": "trip_id", "AttributeType": "S"}, {"AttributeName": "activity_id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        yield resource.create_table(
            TableName="SyncTripTrips",
            KeySchema=[{"AttributeName": "trip_id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "trip_id", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )


@pytest.fixture
def activities_table(table):
    return boto3.resource("dynamodb", region_name="us-east-2").Table("SyncTripActivities")
