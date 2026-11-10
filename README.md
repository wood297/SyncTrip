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
The API does not create tables or modify data. `.env.example` documents settings;
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

## Repository

- `ios/`: App, Models, Views, ViewModels, Services, Resources, and Xcode project.
- `backend/`: routes (HTTP), models (contracts), services (logic), database (storage).
- `tests/`: unit, system, integration, sync.
- `doc/`: guidelines, architecture, API documentation, and semester documents.
- `.github/`: CI and pull request template.

Open `ios/SyncTrip.xcodeproj` on a Mac. The target retains its original name and
deployment settings. The UI still uses local sample activities; connecting it to
the HTTP API is a separate task.

## Tests

```powershell
.\.venv\Scripts\python.exe -m pytest -q
npm test
```

Python integration tests use Moto to emulate DynamoDB with dummy credentials;
they do not read or write your AWS account. JavaScript tests require Node 22+ and
have no npm dependencies. CI runs both suites on pushes and pull requests.
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
using their READMEs. The CLI can modify live DynamoDB records; the new endpoint
only reads them. No CRDT implementation has been selected for production.

Follow [team guidelines](doc/GUIDELINES.md) and [development conventions](doc/AGENTS.md).
Create a feature branch, update docs, run tests, and request a teammate review.
Configure required checks and at least one approval in GitHub branch protection;
the workflow file alone does not enforce merge rules.
