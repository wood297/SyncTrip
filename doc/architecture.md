# Architecture and ownership

`Swift form -> TripStore -> ActivityAPI -> routes -> services -> repository -> DynamoDB`

SyncTripTrips holds trip metadata (trip_id string hash key). SyncTripActivities
holds one item per activity (trip_id hash key, activity_id string range key).
Table names come from configuration; there is no table-per-trip provisioning.
The API translates Swift id to stored activity_id and returns normalized UTC
ISO timestamps and activity versions. Trip metadata reads preserve legacy dates.

Routes own HTTP contracts, models own validation, services own domain behavior,
and backend/database/trips.py owns DynamoDB access for both tables. Low-level
transactions check parent existence/deletion state and activity versions atomically.
The client serializes id/version; stale edits fail instead of overwriting another
traveler's edit. Safe retries compare stable identity and normalized content.

Trip deletion uses a resumable deleting marker, removes child items, then removes
the parent. Failed deletion stays blocked until a retry completes. List operations
follow all DynamoDB pages internally. The API is a private online prototype, not
an offline merge system or an authenticated public service.

The form waits for confirmed persistence before dismissing. Failed saves preserve
the draft; deletes change the visible list only after success. The app opens on
Trips; a bottom menu bar (RootView + MenuBar, rules in Models/Page.swift)
switches between Trips, Plan, and Votes, with Map/Settings inactive. Trips reads
GET /api/v1/trips through TripListStore; tapping a trip calls TripStore.select,
which switches the Day plan to that trip and ignores late results for the old
one. SYNCTRIP_TRIP_ID is only the trip selected at launch. Day plan refresh
has progress, a sync status, pull to refresh, a Refresh menu item, retry, and a
legacy-data notice. ItineraryView and TimeView remain in the project but are not
reachable from the menu bar. An old refresh
response cannot erase a successful local save. The default app uses the backend;
SwiftUI previews explicitly use samples. Environment variables configure the
backend URL and selected trip without editing client/backend source.

Original work remains under ios/ and backend/{database/legacy_cli,services/prototypes}.
The legacy CLI uses embedded activity maps and is not part of the current API.
The two sync implementations are reference prototypes, not silently selected or
wired into online CRUD. Original location mappings are in the root README.

Python tests use two Moto tables and the actual repository, including transactions,
versions, isolation, pagination, custom names, and deletion recovery. HTTP verifiers
exercise real server requests; live AWS checks use disposable records. Swift tests
compile the actual Codable models, API client, stores, and menu bar page model on
macOS via Package.swift. SwiftUI views are not in the package; CI compiles them
with an iOS Simulator build. Manual UI acceptance remains a Mac-only check.

Xcode includes ios/ as a synchronized source group. App/Info.plist is a template,
excluded from source membership; it permits local networking. macOS builds permit
outgoing sandbox connections. Codable models are nonisolated; the observable store
and client explicitly use MainActor. No AWS credentials belong in the app.
