# Validation

## Activity flow implementation

- Full Python suite: **40 passed**, one existing Starlette/httpx adapter
  deprecation warning, zero failures.
- Existing peer-sync suite: **5 passed**, zero failures.
- Running demo HTTP flow: **6 passed** (create, reload persisted record, retry
  without duplicate, edit, invalid input rejection, delete/cleanup).
- No live AWS records were written during activity-flow implementation. The
  earlier live trip001 read check below remains read-only evidence; it does not
  establish UpdateItem permission.
- Added Swift client/store tests and a macOS CI job. They have **not been run**
  here because Swift/Xcode is unavailable on this Windows host. The full UI build
  and simulator checklist in activity-prototype.md remain to be executed on a Mac.

## Initial read-only endpoint verification

Validated locally on November 10, 2026, with Python 3.12 on Windows:

- `python -m pytest -q -o faulthandler_timeout=20`: **14 passed**, one dependency
  warning. Starlette warns that its httpx TestClient adapter is deprecated in
  favor of httpx2. No test failed.
- `node --test tests/sync/peer_sync.test.js`: **5 passed**, zero failures.
- `git diff --check`: passed for tracked changes.
- Original tracked-file inventory: every file accounted for after relocation.
  Application logic in the original prototypes and Swift files was preserved;
  Xcode source root, test imports, npm script paths, and documentation were updated.

Sandboxed Python HTTP test runs stalled; the successful full run used the same
project-local virtual environment outside the sandbox.

## Running-server verification

Repeated the Python suite after adding the demo: **14 passed**, same dependency
warning. Started two temporary Uvicorn servers and used `scripts/verify_api.py`
to send actual HTTP requests:

- Isolated demo (`python -m backend.demo --port 8766`): **5 HTTP checks passed**.
- Live AWS (`python -m uvicorn backend.main:app --host 127.0.0.1 --port 8767`),
  with `AWS_PROFILE=default`, `AWS_REGION=us-east-2`, and
  `DYNAMODB_TABLE_NAME=SyncTripTrips`: **5 HTTP checks passed**, using the
  user-provided existing `trip001`.

The checks cover liveness, OpenAPI, successful trip retrieval, missing-trip 404,
and invalid-ID 422. Both temporary servers were stopped afterward. No live
records were written, and no AWS resources were created or changed.

Automated DynamoDB tests and the demo use Moto and dummy credentials. The live
check establishes successful GetItem access and response serialization for
`trip001`; it does not validate every existing record, write permissions, or
other accounts. Deployment, GitHub-hosted CI, branch protection, and iOS builds
remain unverified.
