import Foundation
import Observation

// The selected trip and its activities. The Trips page picks the trip with
// select(_:); the Day plan and activity screens read and edit its activities.
@MainActor
@Observable
class TripStore {
    private(set) var activities: [Activity]
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var legacyActivityCount = 0
    var loadError: String?
    private(set) var tripID: String
    // Name and destination of the selected trip, once known from the trip list
    private(set) var trip: Trip?
    private let api: ActivityAPI?
    private var mutationGeneration = 0
    // Identifies the refresh in flight; select(_:) drops it so the new trip can load
    private var loadCount = 0
    private var activeLoad: Int?

    init(api: ActivityAPI? = nil, tripID: String? = nil) {
        self.api = api ?? .configured()
        self.tripID = tripID ?? ProcessInfo.processInfo.environment["SYNCTRIP_TRIP_ID"] ?? "trip001"
        activities = []
    }

    // Previews explicitly use samples; the app always uses the API.
    init(previewActivities: [Activity], trip: Trip = Trip.samples[0]) {
        api = nil
        tripID = trip.id
        self.trip = trip
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

    // Switch to another trip. Clears the old activities; the Day plan loads the new
    // ones when it appears. Picking the current trip keeps what is loaded.
    func select(_ newTrip: Trip) {
        trip = newTrip
        guard newTrip.id != tripID else { return }
        tripID = newTrip.id
        activities = []
        legacyActivityCount = 0
        hasLoaded = false
        loadError = nil
        isLoading = false
        // Results still in flight for the old trip are ignored
        activeLoad = nil
        mutationGeneration += 1
    }

    // Fill in the current trip's name and destination from a fresh trip list
    func useDetails(from trips: [Trip]) {
        if let match = trips.first(where: { $0.id == tripID }) { trip = match }
    }

    func refresh() async {
        guard let api, activeLoad == nil else { return }
        loadCount += 1
        let load = loadCount
        activeLoad = load
        isLoading = true
        loadError = nil
        defer {
            // After select(_:), a newer refresh may own the loading state
            if activeLoad == load {
                activeLoad = nil
                isLoading = false
            }
        }
        let generation = mutationGeneration
        do {
            let response = try await api.list(tripID: tripID)
            // An older refresh response must not erase a save that just finished,
            // or fill in activities for a trip that is no longer selected.
            guard activeLoad == load, generation == mutationGeneration else { return }
            activities = response.activities
            legacyActivityCount = response.legacyActivityCount
            hasLoaded = true
        } catch {
            guard activeLoad == load else { return }
            loadError = error.localizedDescription
        }
    }

    func save(_ activity: Activity, isNew: Bool) async throws {
        let savedTrip = tripID
        let saved: Activity
        if let api {
            saved = try await api.save(activity, tripID: savedTrip, isNew: isNew)
        } else {
            saved = activity
        }
        // Saved on the server; only show it if that trip is still selected
        guard savedTrip == tripID else { return }
        if let index = activities.firstIndex(where: { $0.id == saved.id }) {
            activities[index] = saved
        } else {
            activities.append(saved)
        }
        mutationGeneration += 1
    }

    func delete(id: UUID) async throws {
        let deletedTrip = tripID
        if let api { try await api.delete(id: id, tripID: deletedTrip) }
        guard deletedTrip == tripID else { return }
        activities.removeAll { $0.id == id }
        mutationGeneration += 1
    }
}
