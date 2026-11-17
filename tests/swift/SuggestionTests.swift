/*
 Suggestion tests (Figma 04 Suggestions)
 The ideas are a fixed list. These check the paging behind "Show different
 ideas", that ideas fitting the time slot come first, and what "Use" fills in.
 */

import Foundation
import Testing
@testable import SyncTripCore

struct SuggestionTests {
    @Test func pagesShowThreeIdeasAndWrapAround() {
        let all = Suggestion.ordered(forSlotMinutes: 120)
        let first = Suggestion.page(0, forSlotMinutes: 120)
        #expect(first.count == 3)
        #expect(first == Array(all.prefix(3)))
        #expect(Suggestion.page(1, forSlotMinutes: 120) == Array(all[3..<6]))

        // After the last page it starts over
        let pageCount = (all.count + 2) / 3
        #expect(Suggestion.page(pageCount, forSlotMinutes: 120) == first)

        // Every idea is reachable by tapping "Show different ideas"
        let seen = (0..<pageCount).flatMap { Suggestion.page($0, forSlotMinutes: 120) }
        #expect(Set(seen) == Set(Suggestion.presets))
    }

    @Test func ideasThatFitTheSlotComeFirst() {
        let ordered = Suggestion.ordered(forSlotMinutes: 60)
        let firstLonger = ordered.firstIndex { $0.minutes > 60 } ?? ordered.count
        #expect(ordered[..<firstLonger].allSatisfy { $0.minutes <= 60 })
        #expect(ordered[firstLonger...].allSatisfy { $0.minutes > 60 })
        #expect(ordered.count == Suggestion.presets.count)
    }

    @Test func useFillsTypeNameAndEmptyNotesOnly() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let idea = Suggestion.presets.first { $0.type == .food }!
        var draft = Activity(type: .custom, title: "", start: start, end: start.addingTimeInterval(7200))
        draft.location = "Harbour"

        idea.apply(to: &draft)
        #expect(draft.type == .food)
        #expect(draft.title == idea.title)
        #expect(draft.notes == idea.blurb)
        #expect(draft.start == start && draft.end == start.addingTimeInterval(7200), "The time slot is kept")
        #expect(draft.location == "Harbour", "The place is kept")

        var withNotes = draft
        withNotes.notes = "Booking ABC"
        idea.apply(to: &withNotes)
        #expect(withNotes.notes == "Booking ABC", "Notes the user typed are not replaced")
    }

    @Test func durationText() {
        func text(_ minutes: Int) -> String {
            Suggestion(title: "x", type: .custom, minutes: minutes, blurb: "").durationText
        }
        #expect(text(45) == "45 min")
        #expect(text(60) == "1 hour")
        #expect(text(90) == "1.5 hours")
        #expect(text(120) == "2 hours")
        #expect(Suggestion(title: "x", type: .food, minutes: 90, blurb: "").metaText == "Food · 1.5 hours")
    }
}
