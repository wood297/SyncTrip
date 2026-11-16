# Day plan and Votes screens

SwiftUI screens built from the Figma "Final Design" page:
https://www.figma.com/design/eCA9p4xI1Wec0vkmHwO4zK/Candidate-Designs-and-Final-Prototype?node-id=10-1823

| Figma frame | File | Data |
|---|---|---|
| 02 Day plan | `ios/Views/DayPlanView.swift` | Real activities from `TripStore` (API) |
| 23 Votes · open | `ios/Views/VotesView.swift` | Static sample data (`ios/Models/Vote.swift`) |
| 24 Votes · none open | `ios/Views/VotesView.swift` (`openVotes: []`) | Static sample data |

Shared colors, card style, pill buttons, and avatars are in `ios/Views/Theme.swift`
(values from the Figma `--st-*` variables).

## Day plan

- Day picker across the top; defaults to today if the trip has activities today,
  otherwise the first day.
- Activities for the selected day in time order. Tapping one opens
  `ActivityDetailView`; `+` opens `ActivityFormView` for a new activity.
- A gap of 90 minutes or more shows a dashed "Free until ..." slot. Tapping it
  opens the add form at that time.
- On today's date a green line marks the current time.
- "Synced" / "Syncing" / "Not synced" reflects the store's loading and error state.
- Reordering is done by changing an activity's time; there is no drag and drop.

The title is the selected trip's destination and the subtitle its name (see
[trips.md](trips.md) for how a trip is selected).

Static for now: member avatars and chat
button, the Forks tab, "N going", and the fork marker under an activity. The
activity model has no member or fork data yet.

## Votes

- Open votes show the proposal, a result bar with a tick at the pass threshold,
  counts, time left, and Yes/No buttons. With no open votes, an empty state is shown.
- Tapping Yes/No updates the counts on screen only. Nothing is saved or sent to
  the backend yet.

## Menu bar

The hamburger side menu is replaced by the bottom menu bar from the Figma frames
(`ios/Views/MenuBar.swift`): Trips, Plan, Map, Votes, Settings. `RootView` shows
the selected page above the bar and opens on Trips.

- Trips opens `TripsView` ([trips.md](trips.md)); Plan opens `DayPlanView`;
  Votes opens `VotesView`. Tapping a trip opens its Day plan.
- Map and Settings are shown but disabled until they have screens
  (`Page.isAvailable`). Tapping them does not change the page.
- Item order, labels, icons, the starting page, and selection rules are in
  `ios/Models/Page.swift` (no SwiftUI), so `swift test` covers them in
  `tests/swift/MenuBarTests.swift`. The bar's look is checked with its `#Preview`.
- The bar stays visible on screens opened from a page (such as activity
  details). Sheets such as the add/edit form cover it.
- Each page has its own `NavigationStack`, so switching pages returns that page
  to its top screen.
- `ItineraryView` and `TimeView` are kept in the project but are no longer
  reachable from the app.

Each view also has an Xcode `#Preview`.

## Compile check in CI

The `ios-build` job in `.github/workflows/tests.yml` builds the whole app for the
iOS Simulator on a GitHub-hosted Mac (newest Xcode on the runner, no code signing).
Compile errors in any view show up on the PR, so teammates without a Mac can check
their Swift code. It does not run the app or check how screens look; use the Xcode
previews on a Mac for that. If the runner has no Xcode new enough for iOS 27, the
"Use the newest Xcode" step prints the installed versions.

## Differences from Figma

- Icons use SF Symbols instead of the Figma glyph files.
- Text uses the system font instead of Inter.
- The status bar and the bottom tab bar are not drawn; iOS and the app's
  navigation provide those.
