import Foundation
import Observation

// All trips for the Trips page, plus the activities of trips happening now
// (status "active") so their card can show today's next activity.
@MainActor
@Observable
final class TripListStore {
    private(set) var trips: [Trip] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var loadError: String?
    // Activities for each trip in Now, by trip ID. Missing if they couldn't load.
    private(set) var nowActivities: [String: [Activity]] = [:]
    private let api: ActivityAPI?

    init(api: ActivityAPI? = nil) {
        self.api = api ?? .configured()
    }

    // Previews explicitly use samples; the app always uses the API.
    init(previewTrips: [Trip], nowActivities: [String: [Activity]] = [:]) {
        api = nil
        trips = previewTrips
        self.nowActivities = nowActivities
        hasLoaded = true
    }

    var sections: TripSections { TripSections(trips: trips) }

    func refresh() async {
        guard let api, !isLoading else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let list = try await api.listTrips()
            var loaded: [String: [Activity]] = [:]
            for trip in list where trip.section == .now {
                // The trip list still shows if one trip's activities fail to load
                if let response = try? await api.list(tripID: trip.id) {
                    loaded[trip.id] = response.activities
                }
            }
            trips = list
            nowActivities = loaded
            hasLoaded = true
        } catch {
            loadError = error.localizedDescription
        }
    }
}
