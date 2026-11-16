/*
 Root view
 Shows the selected page above the bottom menu bar. Each page gets its own
 NavigationStack, so switching pages starts that page at its top screen.
 Tapping a trip on the Trips page selects it and opens its Day plan.
 */

import SwiftUI

struct RootView: View {
    @Environment(TripStore.self) private var store
    @Environment(TripListStore.self) private var trips
    @State private var page: Page = .start
    @State private var menuBarHidden = false   // set by detail pages, see hidesMenuBar()

    var body: some View {
        Group {
            switch page {
            case .trips:
                NavigationStack {
                    TripsView { trip in
                        store.select(trip)
                        page.select(.plan)
                    }
                }
            case .votes: NavigationStack { VotesView() }
            // Map and Settings are disabled in the bar until they have screens
            case .plan, .map, .settings: NavigationStack { DayPlanView() }
            }
        }
        .environment(\.menuBarHidden, $menuBarHidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !menuBarHidden {
                MenuBar(page: $page)
            }
        }
        // Name and destination for the selected trip (set at launch by SYNCTRIP_TRIP_ID)
        .task { if !trips.hasLoaded { await trips.refresh() } }
        .onChange(of: trips.trips, initial: true) { _, list in
            store.useDetails(from: list)
        }
    }
}

#Preview {
    RootView()
        .environment(TripStore(previewActivities: Activity.samples))
        .environment(TripListStore(previewTrips: Trip.samples,
                                   nowActivities: ["iceland": Activity.samples]))
}
