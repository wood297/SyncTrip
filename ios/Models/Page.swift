/*
 Page model for the bottom menu bar
 The pages in bar order, what each item shows, and which ones have a
 screen yet. Kept free of SwiftUI so it can be unit tested with swift test.
 */

import Foundation

enum Page: CaseIterable {
    case trips, plan, map, votes, settings

    // Page shown when the app opens (Figma flow starts at 01 Trips)
    static let start: Page = .trips

    var label: String {
        switch self {
        case .trips: "Trips"
        case .plan: "Plan"
        case .map: "Map"
        case .votes: "Votes"
        case .settings: "Settings"
        }
    }

    // SF Symbol name
    var icon: String {
        switch self {
        case .trips: "suitcase"
        case .plan: "calendar"
        case .map: "map"
        case .votes: "checkmark.square"
        case .settings: "gearshape"
        }
    }

    // Pages without a screen yet stay inactive in the bar
    var isAvailable: Bool {
        switch self {
        case .trips, .plan, .votes: true
        case .map, .settings: false
        }
    }

    // Switch to a page; inactive pages leave the current page unchanged
    mutating func select(_ newPage: Page) {
        guard newPage.isAvailable else { return }
        self = newPage
    }
}
