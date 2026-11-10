/*
 Root view
 One NavigationStack for the whole app. The side menu switches which page
 is shown instead of pushing a new screen, so screens no longer pile up.
 */

import SwiftUI

enum Page {
    case itinerary, time
}

struct RootView: View {
    @State private var page: Page = .itinerary
    @State private var showMenu = false

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    switch page {
                    case .itinerary: ItineraryView()
                    case .time: TimeView()
                    }
                }
                .toolbar {
                    // Hamburger button
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showMenu = true
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                        .accessibilityLabel("Menu")
                    }
                }
            }

            SideMenu(isShowing: $showMenu, page: $page)
        }
    }
}

#Preview {
    RootView()
        .environment(TripStore())
}
