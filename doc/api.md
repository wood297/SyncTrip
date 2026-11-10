# SyncTrip API contract

## Storage and configuration

- Trips table: string partition key trip_id; no sort key.
- Activities table: string partition key trip_id, string sort key activity_id.
- One activity per item. No embedded activity-map writes and no table per trip.
- Both tables must be in the same AWS account and region (transactions span them).

| Environment setting | Default |
| --- | --- |
| AWS_REGION | us-east-2 |
| DYNAMODB_TRIPS_TABLE | SyncTripTrips |
| DYNAMODB_ACTIVITIES_TABLE | SyncTripActivities |
| DYNAMODB_ENDPOINT_URL | unset; optional DynamoDB Local endpoint |
| AWS_PROFILE | SDK default credential provider chain |

DYNAMODB_TABLE_NAME remains a fallback for the trips table only; the new explicit
DYNAMODB_TRIPS_TABLE takes precedence. Names can change without source edits, but
the documented key schemas are required. Configuration is read per request.
.env.example is a reference; .env is not loaded automatically. The app never
receives AWS credentials or table names.

Run `python -m backend.setup --check` to validate names, key types, ACTIVE status,
and read permissions. `--create-missing` is a separate explicit provisioning
operation and requires CreateTable permission; normal API requests never create
or alter tables. [iam-policy.json](iam-policy.json) defines the runtime permissions;
replace ACCOUNT_ID and the resource names as needed. Transactions use underlying
PutItem/DeleteItem/ConditionCheckItem permissions, as described in
[AWS's transaction IAM documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis-iam.html).

## Health and API reference

- GET /health: process liveness only, no AWS calls.
- GET /ready: 200 with region/table summaries after schema and read checks;
  503 if unavailable or incorrectly configured. Does not test write permissions.
- /docs: interactive requests. /openapi.json: generated machine-readable contract.

## Trips

| Method | Path | Result |
| --- | --- | --- |
| GET | /api/v1/trips | 200 `{"trips":[metadata...]}` |
| POST | /api/v1/trips | 201 trip |
| GET | /api/v1/trips/{trip_id} | 200 trip with activities map |
| PUT | /api/v1/trips/{trip_id} | 200 trip after metadata replacement |
| PATCH | /api/v1/trips/{trip_id} | 200 trip after partial metadata update |
| DELETE | /api/v1/trips/{trip_id} | 204, trip and activities removed |

Create example:

```json
{
  "trip_id": "my-trip-001",
  "name": "Winter trip",
  "destination": "Chicago",
  "start_date": "2027-01-01",
  "status": "planning"
}
```

New trip IDs use 1-128 letters/digits/underscores/hyphens. Omit trip_id to generate
a UUID; clients that need safe creation retries should generate and retain their
own ID. Same ID and matching metadata returns 201 without replacing the trip;
same ID with different metadata returns 409. Treat trip IDs as permanent identity
and use a fresh ID for a new trip instead of reusing a deleted trip ID.

name/destination are trimmed nonempty strings, at most 200 characters. New writes
use valid YYYY-MM-DD dates and status planning/active/completed/cancelled (default
planning). Existing records' date strings, including 12/25/26, are returned
unchanged. PUT requires name/destination/start_date, defaults status to planning,
and does not accept trip_id or activities. PATCH accepts any nonempty subset of
metadata fields; explicit nulls and unknown fields are rejected. Both update
metadata only, preserving activities. Metadata updates are last-successful-write;
activity edits use versions as specified below.

Trip listing returns metadata without loading activities. A trip GET preserves
the original activities-map response shape, combining legacy embedded records
with new-table records; new-table records take precedence for matching IDs.
Use GET activities for the canonical list consumed by Swift.

## Activities

| Method | Path | Result |
| --- | --- | --- |
| GET | /api/v1/trips/{trip_id}/activities | 200 activities envelope |
| POST | /api/v1/trips/{trip_id}/activities | 201 saved activity |
| GET | /api/v1/trips/{trip_id}/activities/{activity_id} | 200 saved activity |
| PUT | /api/v1/trips/{trip_id}/activities/{activity_id} | 200 replaced activity |
| DELETE | /api/v1/trips/{trip_id}/activities/{activity_id} | 204 |

Create example (trip must exist):

```json
{
  "id": "a7c61442-18e3-496e-8d81-d16b75412813",
  "type": "custom",
  "title": "Museum visit",
  "start": "2027-01-01T10:00:00-06:00",
  "end": "2027-01-01T12:00:00-06:00",
  "details": {"Location": "Chicago"},
  "notes": "Bring tickets"
}
```

The saved response has the same fields plus `"version": 1`. Times normalize to
UTC (16:00Z/18:00Z in this example). The API id becomes activity_id in DynamoDB;
trip_id comes from the URL and cannot be reassigned in the request body.

- id: UUID. Generate once in the Swift draft and reuse when retrying. Omitting it
  generates a server ID, but then a lost-response retry can create a duplicate.
- version: server-assigned positive integer; include the last received version
  on PUT. Never increment it in the client. The server increments successful edits.
- type: flight, food, transport, hotel, custom.
- title: required, trimmed, 1-200 characters.
- start/end: required ISO 8601 with timezone, no numeric epochs or timezone-free
  times. End cannot precede start; equal times are allowed to match the form.
- details: optional string map, default empty; at most 20 entries, keys 1-100
  characters, values at most 2000. Uses Swift's existing field labels.
- notes: optional string, default empty; at most 5000 characters.
- Unknown fields are rejected.

PUT is a full replacement, not a partial patch. Body id must match the path UUID.
A stale version with different content returns 409. A retry whose content already
matches the saved activity returns the current version without another write.
POST of the same ID/content is also idempotent and returns 201; different content
under that ID returns 409. DELETE of an already absent activity returns 204 when
the parent trip still exists. Missing parent trips return 404.

List envelope:

```json
{"activities": [], "legacy_activity_count": 0}
```

Activities are sorted by start instant then ID. Storage Query follows every
LastEvaluatedKey page, so results are not silently cut off at DynamoDB's page
boundary. Trip listing similarly follows every Scan page. These endpoints return
complete lists for the prototype; they do not offer client cursor pagination.
Very large lists need a future paginated API version rather than assuming this
prototype is an unlimited public service.

## Integrity, retries, and legacy data

Each activity transaction checks that the parent trip exists and is not deleting,
then conditionally writes/deletes only that activity. Distinct travelers' additions
cannot replace each other's records. Updates compare the version in the same
transaction. Conditional conflicts retry up to three times or return 409.

Trip deletion first marks the trip as deleting, which blocks transactional
activity saves. It deletes its activity records and finally the trip. A failure
returns 503; retry the same DELETE to resume. Deletion is a recoverable cascade,
not one atomic transaction across an arbitrary number of activities. Trips being
deleted are hidden from the list; direct reads/edits return 409. Deleting a missing
trip returns 204. All application writes should use the API; direct console writes
can bypass these safeguards.

Existing embedded maps remain untouched. GET activities reports embedded IDs
absent from the new table as legacy_activity_count, and the app shows a notice.
It does not invent missing type/end/timezone fields. No automatic data migration
was performed. Malformed new-table activities return 500 rather than disappearing
silently. New API writes always create fully validated independent records.

## Errors and deployment boundary

| Status | Meaning |
| --- | --- |
| 404 | Trip/activity not found |
| 409 | Conflicting ID, stale activity version, concurrent change, or deletion in progress |
| 422 | Invalid input, missing edit version, or mismatched activity ID |
| 503 | AWS identity/permissions, configuration, missing table, throttling, connectivity, or interrupted deletion |
| 500 | Invalid stored record |

Domain errors use `{"detail":"message"}`; FastAPI input validation normally uses
a structured detail array. Raw AWS errors/credentials are not returned; backend
logs record the AWS error code for diagnosis. After ambiguous create/edit failures,
retry the same ID/payload; after an interrupted trip DELETE, retry DELETE.

This is the online database API. Authentication, trip membership checks, public
hosting, and offline CRDT synchronization are not implemented. Keep the prototype
private; add identity and membership authorization before public exposure. A native
URLSession client does not need CORS. Hosting/authentication and offline sync do
not require changing the agreed storage contract, but require their own work.
