import XCTest
@testable import SyncTripCore
#if canImport(AppKit)
import AppKit
#endif

// Checks the bottom menu bar against the Figma tab bar: item order and labels,
// which items are active, the starting page, and how selection behaves.
final class MenuBarTests: XCTestCase {
    func testItemsMatchFigmaOrderAndLabels() {
        XCTAssertEqual(Page.allCases, [.trips, .plan, .map, .votes, .settings])
        XCTAssertEqual(Page.allCases.map(\.label), ["Trips", "Plan", "Map", "Votes", "Settings"])
    }

    func testOnlyTripsPlanAndVotesAreActive() {
        XCTAssertEqual(Page.allCases.filter(\.isAvailable), [.trips, .plan, .votes])
    }

    func testAppOpensOnTrips() {
        XCTAssertEqual(Page.start, .trips)
        XCTAssertTrue(Page.start.isAvailable, "The app must not open on an inactive page")
    }

    func testSelectingActivePagesSwitches() {
        var page = Page.start
        page.select(.plan)
        XCTAssertEqual(page, .plan)
        page.select(.votes)
        XCTAssertEqual(page, .votes)
        page.select(.trips)
        XCTAssertEqual(page, .trips)
    }

    func testSelectingCurrentPageKeepsIt() {
        var page = Page.votes
        page.select(.votes)
        XCTAssertEqual(page, .votes)
    }

    func testSelectingInactivePagesDoesNothing() {
        for current in [Page.trips, .plan, .votes] {
            for inactive in [Page.map, .settings] {
                var page = current
                page.select(inactive)
                XCTAssertEqual(page, current, "Tapping \(inactive.label) on \(current.label) should not switch pages")
            }
        }
    }

    func testIconsAreDistinctSFSymbols() throws {
        let icons = Page.allCases.map(\.icon)
        XCTAssertEqual(Set(icons).count, icons.count, "Each item needs its own icon")
        #if canImport(AppKit)
        for page in Page.allCases {
            XCTAssertNotNil(NSImage(systemSymbolName: page.icon, accessibilityDescription: nil),
                            "\(page.icon) is not an SF Symbol (\(page.label))")
        }
        #else
        throw XCTSkip("SF Symbol lookup needs AppKit")
        #endif
    }
}
