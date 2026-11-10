# Architecture

The folder layout follows GUIDELINES.md. The current delivered path is:

`HTTP -> backend/routes/trips.py -> backend/services/trips.py -> backend/database/trips.py -> DynamoDB`

`backend/models/trip.py` defines the response shared by the route and service.
`backend/config.py` reads configuration. AWS resources are created only when a
trip request needs them, so importing the app and checking health work offline.
Each request owns its boto3 resource; no resource is shared across worker threads.

The iOS UI is organized by responsibility, and its Xcode synchronized source
group now points at `ios/`. It still uses the original in-memory TripStore.
`ios/Services/` is reserved for the future backend client.

The Python and JavaScript sync exercises remain independent prototypes under
`backend/services/prototypes/`. Neither is wired into the backend. The existing
database CLI remains in `backend/database/legacy_cli/` to preserve its behavior.
Do not import its app module: it starts an interactive loop and uses live AWS.

Tests follow the required unit/system/integration/sync split. Unit tests cover
lookup and HTTP errors; integration tests exercise the route through the real
boto3 repository against Moto. The unchanged peer-sync test cases were relocated
with their relative module import adjusted. System tests remain future work.

Repository housekeeping does not deploy infrastructure, provision DynamoDB,
enforce GitHub branch protections, or connect the UI and synchronization layers.
