# Verification record

Date: November 10, 2026. Host: Windows, Python 3.12 in the project-local .venv.

## Final two-table implementation

- Live AWS schema/access check: PASS. SyncTripTrips has string hash key trip_id;
  SyncTripActivities has string hash key trip_id and string range key activity_id.
  Both tables ACTIVE in us-east-2. The default configured AWS profile was used.
- Full actual-HTTP demo verification: 12 checks passed, temporary records removed.
- Full actual-HTTP live AWS verification: 12 checks passed, temporary records
  removed. Covered trip creation/listing/updates, activity creation/individual
  read/listing, persistence, duplicate retry, trip isolation, versioned update,
  stale-edit rejection, invalid input, activity deletion/retry, and trip cascade.
- Final Python suite: **56 passed**, zero failures, one existing Starlette/httpx
  test-client deprecation warning. Command: `python -m pytest -q -o faulthandler_timeout=20`.
- Existing peer-sync suite: **5 passed**, zero failures.
- Swift tests and Xcode/simulator acceptance: NOT RUN. Swift/Xcode is unavailable
  on this Windows host. Added model/client/store tests and a macOS CI job; those
  are not evidence of a successful build until a Mac actually runs them.

Integration tests
use two Moto tables and dummy AWS credentials, not the live account. They cover
pagination, custom table names, invalid schemas, version conflicts, missing
parents, and interrupted deletion recovery in addition to the HTTP CRUD paths.

Live write checks used two uniquely named api-check trips, not any of the four
existing trips. No existing trip metadata or legacy activity maps were changed.
No AWS tables, IAM policies, or infrastructure settings were modified. A low-level
cleanup read check independently verifies that the live verification IDs are absent.

## Earlier prototype work

The previous embedded-map version and read-only endpoint were verified in earlier
runs, but are superseded by this two-table implementation. Earlier test counts
are not the current result. The original four trip records remain readable,
including mixed legacy start_date formats. New date writes use YYYY-MM-DD.

## Limits of this verification

Live success proves the tested identity can perform these database operations;
other teammates/deployment identities need the same documented permissions.
The complete backend runs locally; public deployment, authentication, trip
membership authorization, offline queues, and CRDT integration are not implemented.
Metadata updates are last-successful-write. Activity updates use version checks.
List endpoints consume all DynamoDB pages internally and return full prototype
lists, not an unbounded production pagination contract.
