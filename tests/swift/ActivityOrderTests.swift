/*
 Activity order tests (V&V test case 2, SYS-01)
 The Day plan lists a day's activities from TripStore.schedule(on:) and its
 day strip from TripStore.days. These check both stay in time order after
 activities are added, moved and deleted. No backend: the store runs locally.
 */

import Foundation
import Testing
@testable import SyncTripCore

@MainActor
struct ActivityOrderTests {
    // Fixed June dates so results don't depend on today or daylight saving
    private func at(day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: day,
                                                   hour: hour, minute: minute))!
    }

    private func activity(_ title: String, day: Int = 13, _ hour: Int, _ minute: Int = 0) -> Activity {
        let start = at(day: day, hour, minute)
        return Activity(type: .custom, title: title, start: start,
                        end: start.addingTimeInterval(3600))
    }

    // Titles in the order the Day plan shows them
    private func titles(_ store: TripStore, day: Int = 13) -> [String] {
        store.schedule(on: at(day: day, 0)).map(\.title)
    }

    @Test func addedOutOfOrderListsByStartTime() async throws {
        let store = TripStore(previewActivities: [])
        for item in [activity("Dinner", 19), activity("Breakfast", 8), activity("Lunch", 12, 30)] {
            try await store.save(item, isNew: true)
        }
        #expect(titles(store) == ["Breakfast", "Lunch", "Dinner"])
    }

    @Test func movingAnActivityEarlierReordersIt() async throws {
        var lunch = activity("Lunch", 12)
        let store = TripStore(previewActivities: [activity("Breakfast", 8), lunch])
        lunch.start = at(day: 13, 7)
        lunch.end = at(day: 13, 7, 45)
        try await store.save(lunch, isNew: false)
        #expect(titles(store) == ["Lunch", "Breakfast"])
    }

    @Test func deletingKeepsTheRestInOrder() async throws {
        let lunch = activity("Lunch", 12)
        let store = TripStore(previewActivities: [activity("Dinner", 19), lunch, activity("Breakfast", 8)])
        try await store.delete(id: lunch.id)
        #expect(titles(store) == ["Breakfast", "Dinner"])
    }

    @Test func eachDayListsOnlyItsOwnActivities() {
        let store = TripStore(previewActivities: [
            activity("Flight home", day: 15, 9), activity("Dinner", day: 13, 19),
            activity("Museum", day: 14, 11), activity("Hike", day: 13, 10)
        ])
        #expect(titles(store, day: 13) == ["Hike", "Dinner"])
        #expect(titles(store, day: 14) == ["Museum"])
        #expect(titles(store, day: 15) == ["Flight home"])
    }

    @Test func dayStripStaysSortedAfterAddingAMiddleDay() async throws {
        let store = TripStore(previewActivities: [activity("Flight home", day: 15, 9),
                                                  activity("Hike", day: 13, 10)])
        try await store.save(activity("Museum", day: 14, 11), isNew: true)
        #expect(store.days == [at(day: 13, 0), at(day: 14, 0), at(day: 15, 0)])
    }
}
