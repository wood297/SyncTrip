/*
 main function
 creates the shared store and shows the root view
 */
import SwiftUI

@main struct MyApp: App {
    @State private var store = TripStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
