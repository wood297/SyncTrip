import Foundation
import XCTest
@testable import SyncTripCore

// Serves canned responses by path. A handler may block (on its own thread) to
// hold a response back while the test does something else.
private final class TripsStubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        // Off the session's loading thread, so one held-back response doesn't block others
        let handler = Self.handler!
        DispatchQueue.global().async { [self] in
            do {
                let (status, data) = try handler(request)
                let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                               httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }
    override func stopLoading() {}
}

// Checks the Trips page data: reading trips from the API, grouping them into
// Now / Upcoming / Past, the Now card's "today" summary, and opening a trip.
@MainActor
final class TripsTests: XCTestCase {
    override func tearDown() {
        TripsStubProtocol.handler = nil
        super.tearDown()
    }

    private func makeAPI() -> ActivityAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TripsStubProtocol.self]
        return ActivityAPI(baseURL: URL(string: "http://localhost:8000"),
                           session: URLSession(configuration: configuration))
    }

    private func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    private func trip(_ id: String, status: String, start: String = "2026-11-14",
                      name: String? = nil) -> Trip {
        Trip(id: id, name: name ?? id, destination: "Chicago", startDateText: start, status: status)
    }

    private func activityJSON(id: UUID = UUID(), title: String, start: String, end: String) -> [String: Any] {
        ["id": id.uuidString.lowercased(), "version": 1, "type": "custom", "title": title,
         "start": start, "end": end, "details": [:], "notes": ""]
    }

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text)!
    }

    // MARK: - Trip model

    func testDecodesBackendTripMetadata() throws {
        let data = try json(["trips": [["trip_id": "trip001", "name": "Winter trip", "destination": "Chicago",
                                        "start_date": "12/25/26", "status": "planning"]]])
        let trips = try JSONDecoder().decode(TripListResponse.self, from: data).trips
        XCTAssertEqual(trips, [Trip(id: "trip001", name: "Winter trip", destination: "Chicago",
                                    startDateText: "12/25/26", status: "planning")])
    }

    func testReadsCurrentAndLegacyDateFormats() {
        let calendar = Calendar.current
        for text in ["2026-11-14", "11-14-2026", "11/14/2026", "11/14/26"] {
            let parsed = Trip.parseDate(text)
            XCTAssertNotNil(parsed, text)
            if let parsed {
                XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: parsed),
                               DateComponents(year: 2026, month: 11, day: 14), text)
            }
        }
        for text in ["", "soon", "2026-02-30", "02/31/26", "14/11/2026"] {
            XCTAssertNil(Trip.parseDate(text), "\(text) should not be read as a date")
        }
    }

    func testUnreadableDateIsShownAsStored() {
        XCTAssertEqual(trip("t", status: "planning", start: "Spring break").startText(), "Spring break")
    }

    // Fixed "today" so the date-based tests don't change as time passes
    private let today = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12))!

    func testStatusPicksSection() {
        // Start date 2026-12-01 is after today, so only the status decides
        func section(_ status: String) -> TripSection {
            trip("t", status: status, start: "2026-12-01").section(now: today)
        }
        XCTAssertEqual(section("active"), .now)
        XCTAssertEqual(section("planning"), .upcoming)
        XCTAssertEqual(section("completed"), .past)
        XCTAssertEqual(section("cancelled"), .past)
        XCTAssertEqual(section("Active"), .now)
        XCTAssertEqual(section("something-new"), .upcoming, "Unknown statuses should still be listed")
    }

    func testStartedPlanningTripIsNow() {
        XCTAssertEqual(trip("started", status: "planning", start: "11-14-2026").section(now: today), .now,
                       "A planning trip whose start date has passed is happening now")
        XCTAssertEqual(trip("today", status: "planning", start: "2026-11-16").section(now: today), .now,
                       "A trip starting today is happening now")
        XCTAssertEqual(trip("tomorrow", status: "planning", start: "2026-11-17").section(now: today), .upcoming)
        XCTAssertEqual(trip("undated", status: "planning", start: "TBD").section(now: today), .upcoming,
                       "Without a readable date the trip stays Upcoming")
        XCTAssertEqual(trip("done", status: "completed", start: "2026-12-01").section(now: today), .past,
                       "Completed trips are Past whatever the date")
        XCTAssertEqual(trip("early", status: "active", start: "2026-12-01").section(now: today), .now,
                       "Active trips are Now whatever the date")
    }

    func testSectionsAreOrderedByDate() {
        let sections = TripSections(trips: [
            trip("late", status: "planning", start: "2027-03-01"),
            trip("undated", status: "planning", start: "TBD"),
            trip("soon", status: "planning", start: "11/20/26"),
            trip("old", status: "completed", start: "2025-01-01"),
            trip("recent", status: "cancelled", start: "2026-10-01"),
            trip("now", status: "active"),
        ], now: today)
        XCTAssertEqual(sections.now.map(\.id), ["now"])
        XCTAssertEqual(sections.upcoming.map(\.id), ["soon", "late", "undated"],
                       "Soonest first; unreadable dates last")
        XCTAssertEqual(sections.past.map(\.id), ["recent", "old"], "Most recent first")
        XCTAssertFalse(sections.isEmpty)
        XCTAssertTrue(TripSections(trips: [], now: today).isEmpty)
    }

    // MARK: - Now card

    func testTodaySummaryFindsDayAndNextActivity() throws {
        let calendar = Calendar.current
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 11, hour: 9))!
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        func at(_ day: Date, _ hour: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        }
        let activities = [
            Activity(type: .custom, title: "Bakery", start: at(day2, 8), end: at(day2, 9)),
            Activity(type: .custom, title: "Church", start: at(day2, 10), end: at(day2, 12)),
            Activity(type: .custom, title: "Arrive", start: at(day1, 9), end: at(day1, 10)),
        ]

        let morning = TripToday(activities: activities, now: at(day2, 9).addingTimeInterval(30 * 60))
        XCTAssertEqual(morning.dayNumber, 2)
        XCTAssertEqual(morning.dayCount, 2)
        XCTAssertEqual(morning.next?.title, "Church")
        XCTAssertFalse(morning.nextHasStarted)

        let during = TripToday(activities: activities, now: at(day2, 11))
        XCTAssertEqual(during.next?.title, "Church")
        XCTAssertTrue(during.nextHasStarted, "An activity in progress is shown as happening now")

        let evening = TripToday(activities: activities, now: at(day2, 20))
        XCTAssertNil(evening.next)
        XCTAssertTrue(evening.hasPlansToday)

        let dayOff = TripToday(activities: activities, now: calendar.date(byAdding: .day, value: 5, to: day1)!)
        XCTAssertNil(dayOff.dayNumber)
        XCTAssertFalse(dayOff.hasPlansToday)
    }

    // MARK: - API and stores

    func testTripListLoadsTripsAndNowActivities() async throws {
        var paths: [String] = []
        TripsStubProtocol.handler = { request in
            paths.append(request.url!.path)
            switch request.url!.path {
            case "/api/v1/trips":
                return (200, try self.json(["trips": [
                    ["trip_id": "now-trip", "name": "Now", "destination": "Reykjavík",
                     "start_date": "2026-11-14", "status": "active"],
                    ["trip_id": "later", "name": "Later", "destination": "Austin",
                     "start_date": "2099-01-01", "status": "planning"],
                ]]))
            case "/api/v1/trips/now-trip/activities":
                return (200, try self.json(["activities": [
                    self.activityJSON(title: "Museum", start: "2026-11-14T15:00:00Z", end: "2026-11-14T16:00:00Z"),
                ], "legacy_activity_count": 0]))
            default:
                return (404, try self.json(["detail": "not found"]))
            }
        }
        let list = TripListStore(api: makeAPI())
        await list.refresh()

        XCTAssertTrue(list.hasLoaded)
        XCTAssertNil(list.loadError)
        XCTAssertEqual(list.sections.now.map(\.id), ["now-trip"])
        XCTAssertEqual(list.sections.upcoming.map(\.id), ["later"])
        XCTAssertEqual(list.nowActivities["now-trip"]?.map(\.title), ["Museum"])
        XCTAssertNil(list.nowActivities["later"], "Only trips happening now load their activities")
        XCTAssertEqual(paths, ["/api/v1/trips", "/api/v1/trips/now-trip/activities"])
    }

    func testTripListStillShowsWhenNowActivitiesFail() async throws {
        TripsStubProtocol.handler = { request in
            if request.url!.path == "/api/v1/trips" {
                return (200, try self.json(["trips": [["trip_id": "now-trip", "name": "Now", "destination": "X",
                                                       "start_date": "2026-11-14", "status": "active"]]]))
            }
            return (503, try self.json(["detail": "unavailable"]))
        }
        let list = TripListStore(api: makeAPI())
        await list.refresh()
        XCTAssertEqual(list.trips.map(\.id), ["now-trip"])
        XCTAssertNil(list.loadError)
        XCTAssertNil(list.nowActivities["now-trip"])
    }

    func testTripListLoadFailureShowsError() async throws {
        TripsStubProtocol.handler = { _ in (503, try self.json(["detail": "unavailable"])) }
        let list = TripListStore(api: makeAPI())
        await list.refresh()
        XCTAssertFalse(list.hasLoaded)
        XCTAssertNotNil(list.loadError)
        XCTAssertTrue(list.trips.isEmpty)
    }

    func testOpeningATripLoadsItsActivities() async throws {
        TripsStubProtocol.handler = { request in
            let title = request.url!.path.contains("/trip-b/") ? "B activity" : "A activity"
            return (200, try self.json(["activities": [
                self.activityJSON(title: title, start: "2026-11-14T15:00:00Z", end: "2026-11-14T16:00:00Z"),
            ], "legacy_activity_count": 0]))
        }
        let store = TripStore(api: makeAPI(), tripID: "trip-a")
        await store.refresh()
        XCTAssertEqual(store.activities.map(\.title), ["A activity"])

        let tripB = trip("trip-b", status: "planning", name: "Trip B")
        store.select(tripB)
        XCTAssertEqual(store.tripID, "trip-b")
        XCTAssertEqual(store.trip, tripB)
        XCTAssertTrue(store.activities.isEmpty, "The old trip's activities must not show under the new trip")
        XCTAssertFalse(store.hasLoaded)

        await store.refresh()
        XCTAssertEqual(store.activities.map(\.title), ["B activity"])
        XCTAssertTrue(store.hasLoaded)
    }

    func testReopeningTheSameTripKeepsItsActivities() async throws {
        TripsStubProtocol.handler = { _ in
            (200, try self.json(["activities": [
                self.activityJSON(title: "Kept", start: "2026-11-14T15:00:00Z", end: "2026-11-14T16:00:00Z"),
            ], "legacy_activity_count": 0]))
        }
        let store = TripStore(api: makeAPI(), tripID: "trip-a")
        await store.refresh()
        store.select(trip("trip-a", status: "active", name: "Trip A"))
        XCTAssertTrue(store.hasLoaded)
        XCTAssertEqual(store.activities.map(\.title), ["Kept"])
        XCTAssertEqual(store.trip?.name, "Trip A")
    }

    func testLateResponseForPreviousTripIsIgnored() async throws {
        let oldTripRequested = expectation(description: "old trip request started")
        let releaseOldTrip = DispatchSemaphore(value: 0)
        TripsStubProtocol.handler = { request in
            if request.url!.path.contains("/trip-a/") {
                oldTripRequested.fulfill()
                releaseOldTrip.wait()
                return (200, try self.json(["activities": [
                    self.activityJSON(title: "Old trip", start: "2026-11-14T15:00:00Z", end: "2026-11-14T16:00:00Z"),
                ], "legacy_activity_count": 0]))
            }
            return (200, try self.json(["activities": [
                self.activityJSON(title: "New trip", start: "2026-11-14T15:00:00Z", end: "2026-11-14T16:00:00Z"),
            ], "legacy_activity_count": 0]))
        }
        let store = TripStore(api: makeAPI(), tripID: "trip-a")
        let oldLoad = Task { await store.refresh() }
        await fulfillment(of: [oldTripRequested], timeout: 5)

        // Switch trips while trip A is still loading; trip B must load right away
        store.select(trip("trip-b", status: "planning"))
        await store.refresh()
        XCTAssertEqual(store.activities.map(\.title), ["New trip"])

        releaseOldTrip.signal()
        await oldLoad.value
        XCTAssertEqual(store.activities.map(\.title), ["New trip"], "Trip A's late response must be ignored")
        XCTAssertEqual(store.tripID, "trip-b")
        XCTAssertFalse(store.isLoading)
    }

    func testTripDetailsComeFromTheTripList() {
        let store = TripStore(api: makeAPI(), tripID: "trip001")
        XCTAssertNil(store.trip)
        store.useDetails(from: [trip("other", status: "active")])
        XCTAssertNil(store.trip, "Details from a different trip must not be used")
        let match = trip("trip001", status: "active", name: "Winter trip")
        store.useDetails(from: [trip("other", status: "active"), match])
        XCTAssertEqual(store.trip, match)
    }
}
