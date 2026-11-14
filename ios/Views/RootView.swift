/*
 Root view
 Shows the selected page above the bottom menu bar. Each page gets its own
 NavigationStack, so switching pages starts that page at its top screen.
 */

import SwiftUI

struct RootView: View {
    @State private var page: Page = .start

    var body: some View {
        Group {
            switch page {
            case .votes: NavigationStack { VotesView() }
            // Trips, Map, and Settings are disabled in the bar until they have screens
            case .plan, .trips, .map, .settings: NavigationStack { DayPlanView() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MenuBar(page: $page)
        }
    }
}

#Preview {
    RootView()
        .environment(TripStore(previewActivities: Activity.samples))
}
