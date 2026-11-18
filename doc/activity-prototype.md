# Team handoff: activity flow

## Backend readiness (already verified against live AWS)

The API uses SyncTripTrips plus SyncTripActivities with the exact keys documented
in api.md. The live schema check and full read/write verification passed on
November 10, 2026; disposable records were removed. Existing trips were not edited.
Table names are environment settings. New trips only add records, not tables.

Use the root README to start the backend. On Windows use .venv/Scripts/python.exe;
on macOS use .venv/bin/python. Runtime IAM permissions are in iam-policy.json.
Normal use does not require backend code changes. Run:

```text
python -m backend.setup --check
python -m uvicorn backend.main:app --reload
```

Or run `python -m backend.demo` for disposable data without AWS. Do not run both on
the same port. The demo creates both emulated tables and seeds three trips
(scotland-trip, demo-trip, miami-beach) plus four demo-trip activities. Trips have no
end_date yet, so demo-trip's Nov 14–18 span shows only through its activities, and
time zones are not handled correctly yet (times are stored in UTC and shown in the
device's time zone). Keep the backend terminal running while testing the app.

## Repeatable HTTP verification

In a second terminal with the same active local environment:

```text
python scripts/verify_backend.py --allow-writes
```

It verifies readiness, trip CRUD, activity CRUD, individual reads, list persistence,
retry protection, trip isolation, versions/stale edits, input rejection, and trip
cascade deletion. It uses unique api-check IDs, preserves existing trips, and cleans
up its records. A cleanup failure prints the exact IDs for retrying DELETE.
Use --base-url to select another backend. This command intentionally writes data;
verify_api.py --trip-id trip001 is the read-only alternative.

## Mac-only build and acceptance

1. Use the PR/feature branch containing the two-table implementation. Set up the
   local Python environment from README, or use a reachable running backend.
2. With Swift 6+, run `swift test` from the repo root. The tests compile the actual
   Swift model, URLSession client, observable stores, trip model, and menu bar page model
   without a simulator.
3. Open ios/SyncTrip.xcodeproj in a compatible Xcode. Existing deployment targets
   are preserved (iOS 27.0); select an appropriate iOS simulator.
4. Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables:
   - SYNCTRIP_API_URL: http://localhost:8000 for a backend on the same Mac, or a
     reachable backend base URL (HTTPS for hosted/device access).
   - SYNCTRIP_TRIP_ID: demo-trip for the demo; trip001/trip002/trip003/trip4 for
     existing AWS trips; or an ID created through POST /api/v1/trips.
   These are configuration values, not AWS credentials or source edits.
5. Build and launch. The app opens on Trips. In demo mode "SyncTrip verification
   demo" starts 11-14-2026, so it is listed under Now once that date has passed
   (Upcoming before it); with live AWS every trip is listed by status and start date.
   Tap the trip to open its Day plan. Verify loading and the seeded activity in
   demo mode (pick its day in the day strip if needed). With live AWS, an empty
   activities list is valid for a trip with no saved activities. Go back to
   Trips, open a different trip, and confirm the Day plan shows only that trip's
   activities. In the bottom menu bar, Trips, Plan, and Votes should switch
   pages; Map and Settings should do nothing.
6. On the Day plan, tap +. The full-screen New activity form (Figma 03) opens with
   the next hour as its time. Tap Get suggestions (Figma 04): a sheet titled "Ideas
   for" the form's time slot shows three ideas; Show different ideas shows the next
   three and wraps around; Use fills the type, Name and (if empty) Notes and closes
   the sheet, keeping the time and Where. Nothing is saved until Review (details in
   suggestions.md). Pick or adjust a type tile, enter a Name, optionally Where/Notes,
   then Review. Review & save (Figma 05) shows the row as it will look, a "Needs
   approval" note and the vote rules; Back returns to the form unchanged.
   - Save and send: the form closes and the Day plan shows the activity as a dashed
     amber card (Figma 09), a "Waiting for Leaders' approval · View" alert (View
     opens Votes) and a badge on Votes. GET activities shows `"Approval": "pending"`
     in its details.
   - Or tap "On your fork, or as a Leader, this saves right away.": the Day plan
     outlines it in green with an "Added to Saturday · Synced · Undo" toast
     (Figma 08). Undo within 6 seconds deletes it.
   The app has no roles yet, so like the Figma prototype Save and send always takes
   the Traveller path.
7. Relaunch the app without restarting the backend. The activity should reload.
   Confirm it also exists through GET activities in /docs.
8. Open it. Activity details (Figma 06) shows its type, name, time, a map of
   Where (the map needs internet), template fields and notes, with no menu bar;
   Open in Maps opens Apple Maps. Tap Edit activity (Figma 07), change the time,
   and check the new times show in amber with a "Moved … (was …)" note. Review
   opens 05 again; saving closes the details and the Day plan shows 08 ("Saved ·
   Synced", Undo puts back the old version) or 09. A pending activity's details
   show "Needs approval"; saving it right away clears that. Relaunch and confirm
   the edit. Then ••• → Delete activity → Delete (or Edit →
   Delete activity); it disappears from the UI and from GET activities, and only
   the selected activity is removed.
9. Open a draft and stop the server before Review. An error should keep the form
   and draft open. Restart and retry. Creation uses a stable UUID, so a successful
   request followed by a lost response does not create duplicates on retry.
10. For a stale-edit check, edit one activity through /docs after opening it in the
    app. Saving the old form should fail with a conflict. Close it, refresh the
    Day plan (pull down, or ••• > Refresh), and reopen the latest activity before reapplying edits.

The simulator's localhost refers to its Mac, not the Windows host. For a backend
on another machine, bind uvicorn to 0.0.0.0 on a trusted private network, configure
OS firewall access, and use a reachable hostname/HTTPS. The Info.plist permits
local hostname networking; grant the local-network permission when prompted.
A private hosted URL also works through SYNCTRIP_API_URL. No source change is needed.

These Mac steps have not been executed in this Windows workspace. They are the
remaining platform-specific validation, not a claim that the iOS build passed.

## Scope boundaries

The online database API and form wiring are implemented. Authentication,
membership authorization, public hosting, and offline CRDT merge are separate
features. Do not expose the unauthenticated prototype publicly. Old embedded
activity records are preserved and reported for conversion, not guessed into the
new schema. Existing dates in trip metadata remain readable unchanged.
