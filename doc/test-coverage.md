# Test coverage

Which test cases from the Verification and Validation plan have automated tests so far. Run the Swift tests with `swift test` from the repo root; CI runs them on every PR.

| V&V test case | Automated test | Covers |
| --- | --- | --- |
| 1. Itinerary accuracy (SYS-01) | `tests/swift/ActivityFlowTests.swift` | Partly: a created activity's fields match the API contract and reload unchanged. Not the screens. |
| 2. Activity order (SYS-01) | `tests/swift/ActivityOrderTests.swift` | A day's activities stay in start-time order after add, move and delete; each day lists only its own activities; the day strip stays in date order. Unit level, through `TripStore`, which feeds the Day plan. |

Other test cases are not automated yet.

New app tests use Swift Testing, as the V&V plan says; the older `ActivityFlowTests` use XCTest. `swift test` runs both.
