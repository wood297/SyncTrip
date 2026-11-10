# SyncTrip

Group travel planning prototype by Cora Wood, Kira Sun, Sathvik Valluri,
and Mihit Mahanta.

## Verify locally without AWS (PowerShell, Python 3.10+)

From this repository's root, start an isolated demo with a seeded trip:

```powershell
.\.venv\Scripts\python.exe -m backend.demo
```

If this is a fresh checkout, create `.venv` and install `requirements-dev.txt`
first, using the commands below. The demo prints `DEMO MODE` and uses emulated
DynamoDB, not your AWS account. Keep this terminal open. In a second terminal:

```powershell
.\.venv\Scripts\python.exe scripts/verify_api.py
```

Expected result: `All 5 HTTP checks passed. No records were written.`
Open http://127.0.0.1:8000/docs, expand `GET /api/v1/trips/{trip_id}`, click
**Try it out**, enter `demo-trip`, and click **Execute**. Expect HTTP 200 with
destination `Chicago`. Enter `missing-trip` to see HTTP 404. Ctrl+C stops the
demo and discards its data.

## Connect to your team's live AWS table

Run from this repository's root:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-dev.txt
$env:AWS_REGION = "us-east-2"
$env:DYNAMODB_TABLE_NAME = "SyncTripTrips"
# Optional: select an existing AWS CLI profile authorized to read this table.
$env:AWS_PROFILE = "your-profile"
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --reload
```

Use your team's AWS sign-in/profile; never put access keys in source or the iOS app.
The table must already exist with string partition key `trip_id` and no sort key.
The API does not create tables; activity endpoints modify activities on existing
trips. `.env.example` documents settings;
`.env` is not loaded automatically. Shell variables work without extra packages.

- API explorer: http://127.0.0.1:8000/docs
- Liveness: http://127.0.0.1:8000/health
- Example: `Invoke-RestMethod http://127.0.0.1:8000/api/v1/trips/trip001`

The trip ID must exist in the table; otherwise the endpoint returns 404.
Stop the demo before starting the live API on the same port. In a second terminal
run `.\.venv\Scripts\python.exe scripts/verify_api.py --trip-id YOUR_EXISTING_TRIP_ID`
to repeat the five HTTP checks against the real database. A 503 is a failed live
verification; check your AWS sign-in, selected region/table, and GetItem permission.
See [API setup and contract](doc/api.md) for DynamoDB and client integration details.

The API now supports creating, listing, editing, and deleting activities. The
backend identity needs `dynamodb:GetItem` and `dynamodb:UpdateItem` on the trip
table. It still never creates or deletes trips or tables.

## Activity creation prototype

Start the demo above, then in a second terminal run:

```powershell
.\.venv\Scripts\python.exe scripts/verify_activity_flow.py --trip-id demo-trip --allow-writes
```

Expected: `All 6 activity-flow checks passed; temporary activity cleaned up.`
This creates, reloads, retries, edits, validates, and deletes one temporary
activity. Unlike the read-only verifier, this command writes to the selected
trip. Use the demo for a disposable test; supplying a live trip ID tests AWS
writes and requires UpdateItem permission.

To create one manually, open `/docs`, expand
`POST /api/v1/trips/{trip_id}/activities`, enter `demo-trip`, and use the sample
JSON in [doc/api.md](doc/api.md). Expect 201; then use GET activities to verify
the saved record independently.

On a Mac, start the backend on that Mac and open `ios/SyncTrip.xcodeproj`.
In **Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables**:

- `SYNCTRIP_API_URL` = `http://localhost:8000`
- `SYNCTRIP_TRIP_ID` = `demo-trip` (or an existing live trip when using AWS)

Run in an iOS simulator. The app loads the trip's activities, and + opens the
existing form. Save waits for the backend and only closes on success. Failures
keep the draft open for retry. Relaunch the app to confirm the activity reloads;
Edit and Delete also persist through the API. Only SwiftUI previews use samples.
Demo data lasts until the demo server stops; live DynamoDB data survives backend
and app restarts.

`localhost` in a simulator points at its Mac, not a teammate's Windows machine.
For a backend on another computer or a physical phone, configure a reachable
host and appropriate networking/HTTPS instead. Never embed AWS credentials in
the client. See [the Mac acceptance checklist](doc/activity-prototype.md).

## Repository

- `ios/`: App, Models, Views, ViewModels, Services, Resources, and Xcode project.
- `backend/`: routes (HTTP), models (contracts), services (logic), database (storage).
- `tests/`: unit, system, integration, sync.
- `doc/`: guidelines, architecture, API documentation, and semester documents.
- `.github/`: CI and pull request template.

Open `ios/SyncTrip.xcodeproj` on a Mac. The target retains its original name and
deployment settings. The runtime UI now loads and saves activities through the API.

## Tests

```powershell
.\.venv\Scripts\python.exe -m pytest -q
npm test
```

Python integration tests use Moto to emulate DynamoDB with dummy credentials;
they do not read or write your AWS account. JavaScript tests require Node 22+ and
have no npm dependencies. On a Mac with Swift 6+, also run `swift test` to test
the actual Swift model, API client, and store. CI runs all three suites on pushes
and pull requests. Swift tests do not replace an Xcode build/UI acceptance check.
There are no system tests yet; that directory is reserved for deployed tests.

## Existing prototypes

The original work remains available under these paths:

| Original | Current |
| --- | --- |
| Kira Exercise 3 | `ios/` |
| Cora Exercise 3 | `backend/database/legacy_cli/` |
| Sathvik Exercise 3 | `backend/services/prototypes/python_sync/` |
| Mihit Exercise 3 | `backend/services/prototypes/peer_sync/` |
| Mihit's sync tests | `tests/sync/peer_sync.test.js` |
| docs/Semester_1 | `doc/Semester_1/` |

The CLI and two competing synchronization prototypes are preserved for reference;
the HTTP API does not import them. Run legacy tools from their own directories
using their READMEs. The CLI uses the old activity schema; prefer the API for new
activity records. No CRDT implementation has been selected for production.

Follow [team guidelines](doc/GUIDELINES.md) and [development conventions](doc/AGENTS.md).
Create a feature branch, update docs, run tests, and request a teammate review.
Configure required checks and at least one approval in GitHub branch protection;
the workflow file alone does not enforce merge rules.
