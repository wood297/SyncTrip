# SyncTrip API

## Scope and configuration

The online activity prototype uses the same fields as `ios/Models/Activity.swift`.
AWS resources are configured with `AWS_REGION` (default `us-east-2`),
`DYNAMODB_TABLE_NAME` (default `SyncTripTrips`), and the standard AWS credential
provider chain (`AWS_PROFILE` for local development). Optional
`DYNAMODB_ENDPOINT_URL` selects DynamoDB Local. `.env` is not loaded automatically.
The existing table has a string partition key `trip_id` and no sort key.

The backend identity needs `dynamodb:GetItem` and `dynamodb:UpdateItem`:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["dynamodb:GetItem", "dynamodb:UpdateItem"],
    "Resource": "arn:aws:dynamodb:us-east-2:ACCOUNT_ID:table/SyncTripTrips"
  }]
}
```

Replace ACCOUNT_ID; adjust the region/table if needed. Credentials stay on the
backend, never in the app. The legacy CLI also supports trip management but is
not imported by the HTTP server. Creating trips is outside this activity flow;
select an existing trip (`demo-trip` is seeded by `python -m backend.demo`).

## Endpoints

| Method | Path | Success |
| --- | --- | --- |
| GET | `/health` | 200 process liveness, no database check |
| GET | `/api/v1/trips/{trip_id}` | 200 existing trip, with raw activities map |
| GET | `/api/v1/trips/{trip_id}/activities` | 200 canonical activities list and legacy count |
| POST | `/api/v1/trips/{trip_id}/activities` | 201 saved activity |
| PUT | `/api/v1/trips/{trip_id}/activities/{activity_id}` | 200 fully replaced activity |
| DELETE | `/api/v1/trips/{trip_id}/activities/{activity_id}` | 204 empty response |

Interactive explorer: `/docs`. Machine-readable contract: `/openapi.json`.
Trip IDs must be nonempty, without whitespace, and at most 2048 characters.
Use simple path-safe IDs; slash-containing trip IDs are unsupported by this route.

## Activity contract (POST, PUT, and responses)

```json
{
  "id": "a7c61442-18e3-496e-8d81-d16b75412813",
  "type": "custom",
  "title": "Museum visit",
  "start": "2026-11-14T10:00:00-06:00",
  "end": "2026-11-14T12:00:00-06:00",
  "details": {"Location": "Chicago"},
  "notes": "Bring tickets"
}
```

- `id`: UUID. The Swift draft generates it once; reuse the same ID and payload
  when retrying a failed create. If omitted, the API generates an ID, but a client
  cannot safely retry that request without risking a duplicate. PUT requires the
  body ID to match the path ID.
- `type`: flight, food, transport, hotel, or custom.
- `title`: required, trimmed, 1-200 characters.
- `start`, `end`: required ISO 8601 timestamps including timezone. Numeric epochs
  and timezone-free times are rejected. End may equal start, but may not precede
  it. The server normalizes timestamps to UTC. Swift renders them in device time.
- `details`: optional string-to-string map (default `{}`), at most 20 entries;
  keys 1-100 characters, values at most 2000 characters. The Swift form uses its
  existing field labels, e.g. Location, Flight number, From, To, Hotel.
- `notes`: optional string (default empty), at most 5000 characters.
- Unknown fields are rejected to catch schema mismatches.

POST returns the saved activity, including its ID and normalized timestamps.
Repeating POST with the same ID and semantically equivalent normalized content
returns 201 and the same activity without adding a second item. The same ID with
different content returns 409; use PUT to edit. DELETE returns 404 if the activity
is already absent; refresh the itinerary after an ambiguous delete failure.

GET activities returns:

```json
{
  "activities": [],
  "legacy_activity_count": 0
}
```

Canonical records are sorted by start instant and ID. The trip GET retains its
original response and raw activities map so existing consumers do not break.

## Persistence and concurrent requests

Activities remain embedded under `trip.activities[uuid]`; no table migration or
new index is needed for new writes. An UpdateItem writes only the activities
attribute, preserving the rest of the trip. A condition checks that the trip still
exists and the activity map still matches the read snapshot. Conflicts retry up
to three times against a fresh read; exhausted conflicts return 409. This preserves
another traveler's concurrent addition and prevents resurrecting deleted trips.
See [AWS conditional-update guidance](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/BestPractices_ImplementingVersionControl.html).

This is online CRUD, not CRDT synchronization. Concurrent edits to the same
activity can still resolve to the last successful update; field-level merges and
activity versions are future sync work. Embedded maps remain subject to DynamoDB's
400 KB item limit; this prototype is not an unbounded itinerary storage design.
A storage-size failure currently returns the generic database error (503).

## Legacy records

Old CLI records have scheduled_at/location but no type, end, or timezone. They
remain untouched by new writes. GET activities omits records that cannot validate
against the new contract and reports their number as `legacy_activity_count`;
the UI displays a conversion notice. The original trip GET still exposes them.
No timezone, duration, or type is guessed. Team-approved conversion can be added
later, or use a fresh prototype trip. A non-map activities attribute returns 409
instead of overwriting data. Avoid using the legacy CLI to edit new-schema records.

## Errors

| Status | Meaning |
| --- | --- |
| 404 | Trip or activity not found |
| 409 | Duplicate ID with different content, concurrent save, or legacy map requiring migration |
| 422 | Invalid request fields/IDs/timestamps |
| 503 | AWS identity/permissions, missing table, connectivity, throttling, or storage failure |
| 500 | Existing trip does not match the trip response schema |

Domain errors use `{"detail":"message"}`; normal request validation uses FastAPI's
structured detail array. Raw AWS messages and credentials are not returned.
The app preserves the draft and existing local list on failed save/delete.

## Deployment boundary

Run on loopback for local development. Authentication, membership authorization,
and public hosting are not implemented; use a private prototype setup. Any client
that can reach this server can operate on a known trip. Choose identity and enforce
trip membership before exposing it publicly. CORS is not needed for a native
URLSession client. The separate sync prototypes remain unchanged.
