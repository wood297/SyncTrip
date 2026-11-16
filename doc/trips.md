# Trips screen

SwiftUI screen built from the Figma "Final Design" page, frame **01 Trips**:
https://www.figma.com/design/eCA9p4xI1Wec0vkmHwO4zK/Candidate-Designs-and-Final-Prototype?node-id=10-1823

| Piece | File |
|---|---|
| Screen | `ios/Views/TripsView.swift` |
| Trip model, sections, "today" summary | `ios/Models/Trip.swift` |
| Trip list loading | `ios/ViewModels/TripListStore.swift` |
| Trip list request (`GET /api/v1/trips`) | `ios/Services/ActivityAPI.swift` (`listTrips()`) |
| Selected trip | `ios/ViewModels/TripStore.swift` (`select(_:)`) |
| Tests | `tests/swift/TripsTests.swift` |

The app opens on Trips. Trips is active in the bottom menu bar.

## What it shows

Every trip from `GET /api/v1/trips`, grouped by the trip's `status` and start date:

| Section | Which trips | Order |
|---|---|---|
| Now | `active`, or any other status whose start date is today or earlier | Earliest start first |
| Upcoming | `planning` (or a status the app doesn't know) starting after today, or with no readable date | Earliest start first |
| Past | `completed`, `cancelled` (marked "Cancelled") | Latest start first |

Trips have no end date yet, so a started trip stays in Now until its status is
set to `completed`. Trips whose start date can't be read are listed last in their
section.

- **Now card** (dark green): trip name, start date and destination. It also loads
  that trip's activities to show:
  - "Day N of M": today's place among the days that have activities (hidden if
    today has none).
  - "Today in {destination}" with "Next: {activity} at {time}", "Now: {activity}
    until {time}" for one in progress, "Nothing else planned today", or "No plans
    today". This part is hidden if the activities can't be loaded.
- **Upcoming / Past rows**: trip name, then start date and destination.
- Start dates accept the current `YYYY-MM-DD` format and the older `MM-DD-YYYY`,
  `M/D/YYYY`, and `M/D/YY` records. Anything else is shown as stored.
- Loading, "Couldn't load trips" with Retry, and "No trips yet" states. Pull down
  to refresh. The list also refreshes each time the Trips page opens.

## Opening a trip

Tapping a trip (Now card or row) selects it and opens the Day plan:

- `TripStore.select(_:)` switches to that trip and clears the old trip's
  activities, so they never show under the new trip. The Day plan then loads the
  new trip's activities.
- If a load for the previous trip is still in flight, its result is ignored.
- Choosing the trip that is already open keeps its loaded activities.
- The Day plan title is the trip's destination and the subtitle its name.

At launch the selected trip is still `SYNCTRIP_TRIP_ID`. Its name and destination
are filled in once the trip list loads. Until then the Day plan shows "Day plan"
and the trip ID.

## Not shown yet

The backend has no data for these, so they are left out rather than faked:

- End dates ("Jun 11 – 16") and traveller counts ("5 travellers")
- Member avatars on the Now card
- The fork line ("Ana & Leo on a fork until 3:00 PM")

The **+** button (new trip) is shown to match Figma but does nothing yet. Votes
still uses sample data and the "Iceland Ring Road" name.

## Differences from Figma

- Icons use SF Symbols; text uses the system font.
- Subtitles show start date and destination instead of date range and travellers.

Each view has an Xcode `#Preview`, including one with no trips.
