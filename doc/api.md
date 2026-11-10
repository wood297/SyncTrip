# SyncTrip database API

## Scope

The initial vertical slice is `GET /api/v1/trips/{trip_id}`: HTTP request -> route
-> trip service -> DynamoDB repository -> typed JSON response. This gives the team
one working database API without changing the existing table or records.

The service binds to loopback by default. Authentication and trip membership
authorization are not implemented. Before exposing it publicly, the team must
choose an identity provider and enforce membership on every trip request.
Knowing a trip ID currently permits reading that trip from a reachable server.

## Request and response

No request body. `trip_id` is a nonempty string without whitespace, at most 2048
characters. URL-encode it as a path component; use simple IDs such as `trip001`
for the prototype (IDs containing `/` cannot be used through this route).

```http
GET /api/v1/trips/trip001
```

```json
{
  "trip_id": "trip001",
  "name": "Scotland Trip",
  "destination": "Edinburgh",
  "start_date": "10-15-2026",
  "status": "planning",
  "activities": {
    "activity001": {
      "title": "Museum",
      "scheduled_at": "2026-10-15 10:00",
      "location": "Old Town"
    }
  }
}
```

Top-level fields are explicit; additional stored top-level fields are omitted.
`activities` preserves the existing map and returns `{}` for trips without one.
Activity values remain flexible because the existing prototypes use different
schemas. The iOS Activity model has type, start/end, details, and notes; it cannot
yet be decoded directly from this legacy response. Agree on a shared model before
implementing writes or sync.

| Status | Meaning | Body |
| --- | --- | --- |
| 200 | Found | Trip object |
| 404 | No matching item | `{"detail":"Trip not found"}` |
| 422 | Invalid path input | FastAPI validation detail array |
| 503 | AWS credentials, permissions, missing table, throttling, or connectivity failure | `{"detail":"Database unavailable"}` |
| 500 | Stored item fails the trip contract | `{"detail":"Invalid stored trip"}` |

AWS error text, account identifiers, and credentials are never returned by the API.
`GET /health` is a process liveness check, not a database readiness check.
`/docs` and `/openapi.json` provide the generated API contract.

## AWS configuration

| Setting | Default | Purpose |
| --- | --- | --- |
| `AWS_REGION` | `us-east-2` | Existing prototype's region |
| `DYNAMODB_TABLE_NAME` | `SyncTripTrips` | Existing prototype's table |
| `DYNAMODB_ENDPOINT_URL` | unset | Optional DynamoDB Local endpoint |
| `AWS_PROFILE` | SDK default | Locally configured AWS identity |

Use the standard boto3 credential provider chain: a local profile for developers,
an attached IAM role when deployed. Never distribute AWS credentials to clients.
Confirm the AWS account, region, table, and key schema in the console. Do not
create a replacement table if the existing table has a different key schema.

Minimum policy for this read-only endpoint (replace ACCOUNT_ID and table/region
if needed; attach to the backend's identity through your team's AWS administrator):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "dynamodb:GetItem",
    "Resource": "arn:aws:dynamodb:us-east-2:ACCOUNT_ID:table/SyncTripTrips"
  }]
}
```

Retrieval uses the full partition key and a strongly consistent GetItem, with
bounded timeouts and retries. It does not scan or write to the table. See
[AWS GetItem documentation](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_GetItem.html).

## Local testing and teammate handoff

1. Follow the root README to create a local environment and start the API.
2. Run tests without AWS: `python -m pytest -q` in the active `.venv`.
3. With an authorized AWS profile, request a known trip and a nonexistent trip.
4. Have the iOS client call the backend over HTTPS once hosting and authentication
   are ready. The iOS simulator's/device's network setup must reach that host.

For an isolated DynamoDB Local instance, set `DYNAMODB_ENDPOINT_URL` to its URL
(for example http://localhost:8001), unset `AWS_PROFILE`, and use dummy credentials.
Provision a separate local table with a string `trip_id` hash key before manual
requests. Automated tests provision their own emulated table with Moto.

Legacy dates and activity times have no timezone. This read-only endpoint returns
them unchanged; it does not guess a timezone. Future writes should accept ISO 8601
dates and timezone-aware timestamps, with an explicit migration plan for legacy
records. Sync conflict resolution, versioning, conditional writes, and DynamoDB's
item size limit must be addressed before using embedded activity maps at scale.

## Remaining prototype decisions

- Live read verification passed for `trip001` using the local default profile in
  `us-east-2`; see validation.md. Teammates still need their own authorized access.
- Decide API hosting, identity, trip ownership/membership, and client configuration.
- Agree on one activity schema and CRDT implementation with the iOS/sync teammates.
- Add writes as separate reviewed changes with validation and conditional updates.
- Build the relocated iOS target on a Mac; Windows cannot run Xcode checks.
