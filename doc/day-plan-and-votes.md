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

Static for now: the title ("Reykjavík") and trip name, member avatars and chat
button, the Forks tab, "N going", and the fork marker under an activity. The
activity model has no member or fork data yet.

## Votes

- Open votes show the proposal, a result bar with a tick at the pass threshold,
  counts, time left, and Yes/No buttons. With no open votes, an empty state is shown.
- Tapping Yes/No updates the counts on screen only. Nothing is saved or sent to
  the backend yet.

## Navigation

- The app opens on the Day plan: the `itinerary` page in `RootView.swift` now
  shows `DayPlanView` instead of `ItineraryView`. `ItineraryView.swift` is kept
  (unused) until the team decides to remove it.
- Votes is a new `votes` page with a "Votes" row in `SideMenu.swift`.
- Both screens hide the navigation bar to match the Figma header, which also
  hides `RootView`'s ☰ toolbar button. They take an `onMenu` closure instead and
  show their own ☰ button; `RootView` passes `{ showMenu = true }`. With no
  closure (previews), the button is hidden.

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
