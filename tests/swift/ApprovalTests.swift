/*
 Approval state tests (Figma 05 Review & save → 08 Saved / 09 Pending approval)
 "Save and send" marks an activity as waiting for approval. The flag lives in
 details["Approval"], so it must survive the API's JSON and an edit, and the
 store's pending count drives the Day plan alert and the Votes badge.
 No backend: the store runs locally.
 */

import Foundation
import Testing
@testable import SyncTripCore

@MainActor
struct ApprovalTests {
    private func activity(_ title: String, hour: Int) -> Activity {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 13, hour: hour))!
        return Activity(type: .custom, title: title, start: start, end: start.addingTimeInterval(3600),
                        details: [Activity.locationKey: "Reykjavík"])
    }

    @Test func pendingFlagIsStoredInDetails() {
        var item = activity("Sky Lagoon", hour: 14)
        #expect(!item.isPending)

        item.isPending = true
        #expect(item.isPending)
        #expect(item.details[Activity.approvalKey] == "pending")
        #expect(item.location == "Reykjavík", "Other details are kept")

        item.isPending = false
        #expect(item.details[Activity.approvalKey] == nil, "Approved removes the key")
    }

    @Test func pendingFlagSurvivesJSON() throws {
        var item = activity("Sky Lagoon", hour: 14)
        item.isPending = true
        let decoded = try JSONDecoder().decode(Activity.self, from: JSONEncoder().encode(item))
        #expect(decoded.isPending)
    }

    @Test func pendingCountFollowsSaves() async throws {
        let store = TripStore(previewActivities: [activity("Bakery", hour: 8)])
        #expect(store.pendingCount == 0)

        var sent = activity("Sky Lagoon", hour: 14)
        sent.isPending = true
        try await store.save(sent, isNew: true)
        #expect(store.pendingCount == 1)

        // Saving it again as approved (the "saves right away" path) clears it
        sent.isPending = false
        try await store.save(sent, isNew: false)
        #expect(store.pendingCount == 0)
    }

    @Test func deletingAPendingActivityClearsTheCount() async throws {
        var sent = activity("Sky Lagoon", hour: 14)
        sent.isPending = true
        let store = TripStore(previewActivities: [sent])
        #expect(store.pendingCount == 1)
        try await store.delete(id: sent.id)
        #expect(store.pendingCount == 0)
    }
}
