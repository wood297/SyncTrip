import Foundation
import Observation

@MainActor
@Observable
class TripStore {
    private(set) var activities: [Activity]
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var legacyActivityCount = 0
    var loadError: String?
    let tripID: String
    private let api: ActivityAPI?

    init(api: ActivityAPI? = nil, tripID: String? = nil) {
        self.api = api ?? .configured()
        self.tripID = tripID ?? ProcessInfo.processInfo.environment["SYNCTRIP_TRIP_ID"] ?? "trip001"
        activities = []
    }

    // Previews explicitly use samples; the app always uses the API.
    init(previewActivities: [Activity]) {
        api = nil
        tripID = "preview"
        activities = previewActivities
        hasLoaded = true
    }

    var days: [Date] {
        Set(activities.map { Calendar.current.startOfDay(for: $0.start) }).sorted()
    }

    func schedule(on day: Date) -> [Activity] {
        activities.filter { Calendar.current.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    func activity(id: UUID) -> Activity? {
        activities.first { $0.id == id }
    }

    func refresh() async {
        guard let api, !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let response = try await api.list(tripID: tripID)
            activities = response.activities
            legacyActivityCount = response.legacyActivityCount
            hasLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
    }

    func save(_ activity: Activity, isNew: Bool) async throws {
        let saved: Activity
        if let api {
            saved = try await api.save(activity, tripID: tripID, isNew: isNew)
        } else {
            saved = activity
        }
        if let index = activities.firstIndex(where: { $0.id == saved.id }) {
            activities[index] = saved
        } else {
            activities.append(saved)
        }
    }

    func delete(id: UUID) async throws {
        if let api { try await api.delete(id: id, tripID: tripID) }
        activities.removeAll { $0.id == id }
    }
}
