# Architecture

The folder layout follows GUIDELINES.md. Online activity flow:

`ActivityFormView -> TripStore -> ActivityAPI (URLSession) -> backend/routes/activities.py -> backend/services/activities.py -> TripRepository -> DynamoDB`

The Swift form and backend Activity model share id, type, title, start, end,
details, and notes. The API uses ISO 8601 timezone-aware timestamps normalized to
UTC; the app displays them in device-local time. UUID identity stays stable during
retry. The existing trip GET retains its raw response contract.

The form waits for HTTP success before dismissal. Failed saves retain the draft;
failed deletes retain the visible activity. Itinerary loading has progress,
error/retry, pull-to-refresh, and a notice for preserved legacy records. The live
app uses the API; SwiftUI previews explicitly use in-memory sample activities.

Each repository request owns its boto3 resource. Conditional activity-map updates
prevent losing unrelated concurrent additions and prevent recreating deleted
trips. This is not a CRDT integration or a field-level conflict merge.

Python and JavaScript sync exercises remain under backend/services/prototypes/;
the original interactive database CLI is under backend/database/legacy_cli/.
They are reference implementations and are not imported by the HTTP application.

Python integration tests exercise HTTP and the actual boto3 repository with Moto.
The HTTP verifier exercises a real Uvicorn server. Package.swift compiles the real
Swift model/client/store into a testable module on macOS; SwiftUI views still need
an Xcode simulator build and manual acceptance checks. CI includes a macOS Swift
client job. Run `swift test` from the repo root on a Mac with Swift 6+.

The Xcode synchronized source group includes ios/. App/Info.plist is excluded
from source membership and used as the Info.plist template. It permits local
networking for development; macOS builds permit outgoing sandbox networking.
Codable models use the target's nonisolated default; the API client and store
explicitly run on MainActor, as do SwiftUI view interactions.
No AWS credentials belong in the app. Public hosting/authentication and branch
protection setup are outside the local prototype implementation.
