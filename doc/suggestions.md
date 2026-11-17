# Suggestions screen

Figma frame "04 Suggestions" (Final Design page), built in `ios/Views/SuggestionsView.swift`.
The ideas and their logic are in `ios/Models/Suggestion.swift`.

## How it works

- On the New activity form (Figma 03), tapping **Get suggestions** opens a sheet
  titled "Ideas for" the form's time slot, e.g. "Ideas for 2:00 – 4:00 PM".
- The sheet shows three ideas at a time. Each card has a name, its type and length
  (e.g. "Custom · 2 hours"), a short description, and a **Use** button.
- **Show different ideas** shows the next three. After the last ideas it starts over.
- **Use** fills in the form's type and Name, and its Notes if they are empty, then
  closes the sheet. The time slot and Where are left as they are. Nothing is saved
  until the user taps Review.
- Ideas short enough for the time slot are listed first.

To try it: Day plan → + → Get suggestions → Show different ideas → Use, then check
the form's type, Name and Notes.

## Prototype limits

- The ideas are a fixed list of 12 general activities (walking tour, museum,
  café, viewpoint, and so on) that fit most trips. They are not generated from the
  trip, place, or time, and nothing is sent to the backend.
- So the note under the title says "General ideas that fit most trips" instead of
  Figma's "Suggested by AI from your trip, time and location", and the cards show
  only type and length, not travel time ("15 min drive").

## Tests

`tests/swift/SuggestionTests.swift` checks paging (three per page, wraps around,
every idea reachable), that ideas fitting the slot come first, and what Use fills in.
