# SyncTrip

Group travel planning prototype by Cora Wood, Kira Sun, Sathvik Valluri, and Mihit Mahanta.

The API supports trip and activity create/read/update/delete. It uses two DynamoDB
tables: trip metadata in **SyncTripTrips**, individual activities in
**SyncTripActivities**. Table names and the backend URL are configuration, not
source edits. The Swift forms use the API; only previews use sample data.

## Start the real AWS backend (PowerShell)

Run from the SyncTrip repository root with Python 3.10+:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
$env:AWS_PROFILE = "default"
$env:AWS_REGION = "us-east-2"
$env:DYNAMODB_TRIPS_TABLE = "SyncTripTrips"
$env:DYNAMODB_ACTIVITIES_TABLE = "SyncTripActivities"
.\.venv\Scripts\python.exe -m backend.setup --check
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --reload
```

If .venv already exists, reuse it. The setup check must report ready for both tables.
The final command keeps running: leave that terminal open while using the API.

- [Interactive API explorer](http://127.0.0.1:8000/docs)
- [Database readiness](http://127.0.0.1:8000/ready) (schema and read permissions)
- [Trip list](http://127.0.0.1:8000/api/v1/trips)
- [Example trip](http://127.0.0.1:8000/api/v1/trips/trip001)
- [Example activities](http://127.0.0.1:8000/api/v1/trips/trip001/activities)

Readiness does not prove write permissions; the full verifier below does. AWS
credentials belong only in the backend's profile/role, never in source or the app.
See [required IAM permissions](doc/iam-policy.json); replace ACCOUNT_ID and adjust
region/table names if yours differ. Both tables must be in the same account/region.

## Verify the complete API

In a second terminal, from this repo root:

```powershell
.\.venv\Scripts\python.exe scripts/verify_backend.py --allow-writes
```

Expected: **All 12 backend checks passed; disposable records cleaned up.**
This creates uniquely named api-check trips and activities, verifies persistence,
updates, stale edits, validation, isolation, and deletion, then removes its records.
It does not edit existing trips. If cleanup fails it prints the IDs to retry DELETE.
Add `--base-url https://your-backend.example` to verify another backend.

For read-only verification of an existing trip:

```powershell
.\.venv\Scripts\python.exe scripts/verify_api.py --trip-id trip001
```

## Disposable demo without AWS

Stop the live server first if using the same port. Then run:

```powershell
.\.venv\Scripts\python.exe -m backend.demo
```

This uses two emulated DynamoDB tables, seeds demo-trip and one activity, and never
contacts live AWS. Open /docs or run the full verifier in the other terminal.
Stopping the demo erases its data; restarting just the app does not. For the older
activity-only checker: `python scripts/verify_activity_flow.py --trip-id demo-trip --allow-writes`.

## API contract for teammates

| Operation | Endpoint |
| --- | --- |
| List/create trips | GET / POST `/api/v1/trips` |
| Read/replace/update/delete a trip | GET / PUT / PATCH / DELETE `/api/v1/trips/{trip_id}` |
| List/create activities | GET / POST `/api/v1/trips/{trip_id}/activities` |
| Read/replace/delete an activity | GET / PUT / DELETE `/api/v1/trips/{trip_id}/activities/{activity_id}` |

Activity fields match Swift: **id, version, type, title, start, end, details, notes**.
The backend maps id to activity_id in DynamoDB. For creation, generate a UUID once
and keep it when retrying. For edits, send the version returned by the server;
a stale edit returns 409 instead of overwriting someone else's change. Dates/times
must include a timezone; the server returns UTC. Swift displays device-local time.

Detailed JSON examples, status codes, retry rules, pagination handling, and storage
behavior are in [doc/api.md](doc/api.md). Trip deletion also deletes its activities;
it is retryable if interrupted. No new tables are created when adding a trip.

## iOS teammate: configure and build on a Mac

Backend implementation is ready to call; teammates do not need to modify it.
On a Mac, create the Python environment as above (use `.venv/bin/python`), install
dependencies, and run either the demo or AWS backend. Open ios/SyncTrip.xcodeproj.
In **Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables**:

| Variable | Demo on the same Mac | Live backend |
| --- | --- | --- |
| SYNCTRIP_API_URL | http://localhost:8000 | Your reachable backend base URL |
| SYNCTRIP_TRIP_ID | demo-trip | trip001, trip002, trip003, trip4, or a trip created through POST |

Run `swift test` from the repo root (Swift 6+), then build/run an iOS simulator.
Confirm create, relaunch/reload, edit, and delete all persist. Stop the backend
while a draft is open to check that failure retains the draft. The full
[Mac acceptance checklist](doc/activity-prototype.md) lists expected behavior.

localhost is only a development default: on a simulator it points at its Mac,
not a Windows computer. To use another computer's backend, run uvicorn with
`--host 0.0.0.0` on a trusted private network and configure a reachable hostname
and OS firewall; use HTTPS for hosted/device access. The app's local-network
permission must be granted. Do not expose this prototype on the public internet
without adding authentication and trip membership authorization.

**Not yet executed here:** Swift tests and the Xcode/simulator checks, because this
workspace is Windows without Swift/Xcode. CI includes a macOS Swift test job, but
its presence does not mean it has passed. Existing Xcode deployment targets were
preserved (iOS 27.0); the Mac needs a compatible Xcode/simulator.

## Repository and original code locations

| Original work | Current location |
| --- | --- |
| Kira Exercise 3 | ios/App, Models, Views, ViewModels, Services, Resources; ios/SyncTrip.xcodeproj |
| Cora Exercise 3 | backend/database/legacy_cli/ |
| Sathvik Exercise 3 | backend/services/prototypes/python_sync/ |
| Mihit Exercise 3 | backend/services/prototypes/peer_sync/ |
| Mihit's sync tests | tests/sync/peer_sync.test.js |
| docs/Semester_1 | doc/Semester_1/ |

Backend responsibilities: routes = HTTP, models = contracts, services = rules,
database = DynamoDB access. Tests are grouped into unit/integration/system/sync;
Swift client tests are in tests/swift. doc/ follows the supplied guideline name.
The legacy CLI and sync prototypes are reference work, not imported by the API.
The CLI uses the old embedded schema; use the API for new activity data.

## Checks and limitations

```powershell
.\.venv\Scripts\python.exe -m pytest -q
npm test
```

Python tests use Moto and dummy credentials, never live AWS. Node 22+ is needed
for the dependency-free sync tests. `swift test` runs the shared client/store/model
suite on macOS. CI runs these suites on pushes and PRs. Results and the latest
live verification are recorded in [doc/validation.md](doc/validation.md).

This is an online prototype: no authentication, offline queue, or CRDT merge is
implemented. Existing embedded legacy activities are preserved, not silently
converted; the activities response reports a legacy count. Normal new records
always go to SyncTripActivities. Malformed new-table records return a visible
server error rather than being silently omitted.

Follow [team guidelines](doc/GUIDELINES.md) and [development conventions](doc/AGENTS.md).
Use a feature branch and PR with at least one teammate review before main. GitHub
branch protection must be configured separately to enforce the review/check rules.
