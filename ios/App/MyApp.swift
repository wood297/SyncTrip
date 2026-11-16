/*
 main function
 creates the shared stores and shows the root view
 */
import SwiftUI

@main struct MyApp: App {
    @State private var store = TripStore()
    @State private var trips = TripListStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(trips)
        }
    }
}
