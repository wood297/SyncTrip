/*
 Root view
 Shows the selected page above the bottom menu bar. Each page gets its own
 NavigationStack, so switching pages starts that page at its top screen.
 Tapping a trip on the Trips page selects it and opens its Day plan.
 The Day plan's "Waiting for Leaders' approval" alert opens Votes, and the
 Votes item shows how many activities are waiting (Figma 09).

 The bar is attached to each page's top screen, inside its NavigationStack.
 That way the page leaves room for it (its own bottom alerts sit above the
 bar), and screens opened from the page, such as activity details, cover it,
 as in Figma 06.
 */

import SwiftUI

struct RootView: View {
    @Environment(TripStore.self) private var store
    @Environment(TripListStore.self) private var trips
    @State private var page: Page = .start

    var body: some View {
        Group {
            switch page {
            case .trips:
                NavigationStack {
                    TripsView { trip in
                        store.select(trip)
                        page.select(.plan)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) { menuBar }
                }
            case .votes:
                NavigationStack {
                    VotesView()
                        .safeAreaInset(edge: .bottom, spacing: 0) { menuBar }
                }
            // Map and Settings are disabled in the bar until they have screens
            case .plan, .map, .settings:
                NavigationStack {
                    DayPlanView { page.select(.votes) }   // approval alert's View
                        .safeAreaInset(edge: .bottom, spacing: 0) { menuBar }
                }
            }
        }
        // Name and destination for the selected trip (set at launch by SYNCTRIP_TRIP_ID)
        .task { if !trips.hasLoaded { await trips.refresh() } }
        .onChange(of: trips.trips, initial: true) { _, list in
            store.useDetails(from: list)
        }
    }

    private var menuBar: some View {
        MenuBar(page: $page, votesBadge: store.pendingCount)
    }
}

#Preview {
    RootView()
        .environment(TripStore(previewActivities: Activity.samples))
        .environment(TripListStore(previewTrips: Trip.samples,
                                   nowActivities: ["iceland": Activity.samples]))
}
