# Activity creation: demo and acceptance checks

## Run the complete backend flow on Windows

From the repository root, using the installed project-local environment:

```powershell
.\.venv\Scripts\python.exe -m backend.demo
```

In a second PowerShell terminal:

```powershell
.\.venv\Scripts\python.exe scripts/verify_activity_flow.py --trip-id demo-trip --allow-writes
```

Expect six PASS lines and a successful cleanup message. This verifies the actual
HTTP creation/read/edit/delete flow against a disposable DynamoDB emulator. It
does not test AWS write permissions. The read-only verifier is still available.

For manual creation, open http://127.0.0.1:8000/docs, select POST activities, and
set trip_id to demo-trip. Paste the sample from api.md, execute, and expect 201.
Then GET activities and locate the saved ID. Repeat POST with the same body to
confirm it does not duplicate the activity. Stop the demo with Ctrl+C; all its
data disappears. Restarting only the app preserves demo data while the server runs.

## Run with live DynamoDB

Stop the demo, set AWS_PROFILE/AWS_REGION/DYNAMODB_TABLE_NAME as in the README,
then start `python -m uvicorn backend.main:app --reload` in the active .venv.
The backend identity now needs both GetItem and UpdateItem on the existing table.

To explicitly perform a live write check:

```powershell
.\.venv\Scripts\python.exe scripts/verify_activity_flow.py --trip-id trip001 --allow-writes
```

This creates a unique temporary activity, edits it, and deletes that same activity.
It preserves the trip and its other activities. If cleanup fails, the command
prints the temporary ID for manual follow-up. Do not confuse this write verifier
with verify_api.py, which only reads. New live writes have not been executed as
part of this implementation; run this with the team's approved AWS identity.

## Mac / iOS teammate acceptance checklist

1. On a Mac, install Python 3.10+, create a local .venv, and install
   requirements-dev.txt. Run `python -m backend.demo` in that environment.
2. From the repository root, run `swift test` with Swift 6+ installed. This checks
   the actual Codable models, HTTP client, and store, using a URLSession stub.
3. Open ios/SyncTrip.xcodeproj. Select an iOS simulator supported by the project's
   existing deployment target (currently iOS 27.0). Older Xcode installations
   need an agreed deployment-target change before building this existing project.
4. In Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables,
   set SYNCTRIP_API_URL=http://localhost:8000 and SYNCTRIP_TRIP_ID=demo-trip.
   Both variables are app configuration, not AWS credentials.
5. Build and run. Confirm the seeded Museum visit loads. Tap + and create an
   activity with a type, title, times, details, and notes. Save should show Saving
   while pending, then close the form and show the activity in the itinerary.
6. Relaunch the app with the same server still running. Confirm the activity
   reloads. Also retrieve it through the API docs so local UI state cannot hide
   a failed database write.
7. Edit it, save, relaunch, and confirm the edit remains. Delete it and confirm
   it disappears from GET activities as well.
8. Test a blank title and end before start: the form should not allow saving.
   Send malformed requests in /docs to confirm the backend also rejects them.
9. Open a draft, stop the backend, then tap Save. Confirm an error appears and
   the form retains the draft. Restart the backend and retry. For this connectivity
   test with the demo, the server reset removes earlier demo data by design.
10. With live AWS, repeat creation/relaunch only after verifying UpdateItem access.
    Confirm legacy records remain in the raw trip GET. The UI reports any old
    activities that lack fields/timezones rather than guessing their values.

The simulator's localhost is its Mac, not a Windows teammate's machine. Physical
devices and remote backends need a reachable hostname/HTTPS and appropriate
network configuration. The included Info.plist permits local hostname networking;
the macOS app target permits outgoing sandbox connections. Public deployment and
trip membership authentication are separate work.

## Scope

Implemented: online activity create/list/edit/delete, validation, stable UUID
retries, database persistence, Swift HTTP wiring, loading/errors, and tests.
Not implemented: trip creation UI, offline queues/CRDT merge, user authentication,
public hosting, or automatic conversion of ambiguous legacy timestamps. The full
Xcode build and simulator acceptance steps remain unverified on this Windows host.
