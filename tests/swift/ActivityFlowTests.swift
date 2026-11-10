import Foundation
import XCTest
@testable import SyncTripCore

private final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                           httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

@MainActor
final class ActivityFlowTests: XCTestCase {
    private func makeAPI() -> ActivityAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return ActivityAPI(baseURL: URL(string: "http://localhost:8000"),
                           session: URLSession(configuration: configuration))
    }

    private func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    func testCreateMatchesContractAndReloads() async throws {
        let api = makeAPI()
        let store = TripStore(api: api, tripID: "demo-trip")
        let activity = Activity(type: .custom, title: "Museum", start: Date(timeIntervalSince1970: 1794672000),
                                end: Date(timeIntervalSince1970: 1794675600),
                                details: ["Location": "Chicago"], notes: "Tickets")
        let payload: [String: Any] = [
            "id": activity.id.uuidString.lowercased(), "type": "custom", "title": "Museum",
            "start": "2026-11-14T16:00:00.000000Z", "end": "2026-11-14T17:00:00Z",
            "details": ["Location": "Chicago"], "notes": "Tickets"
        ]
        let response = try json(payload)
        StubProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/trips/demo-trip/activities")
            // URLSession may supply an HTTP body stream to custom URLProtocol.
            var body = request.httpBody
            if body == nil, let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var bytes = [UInt8](repeating: 0, count: 4096)
                var result = Data()
                while stream.hasBytesAvailable {
                    let count = stream.read(&bytes, maxLength: bytes.count)
                    if count <= 0 { break }
                    result.append(contentsOf: bytes.prefix(count))
                }
                body = result
            }
            let sent = try JSONSerialization.jsonObject(with: XCTUnwrap(body)) as! [String: Any]
            XCTAssertEqual(sent["id"] as? String, activity.id.uuidString)
            XCTAssertNotNil(sent["start"] as? String)
            XCTAssertNil(sent["scheduled_at"])
            return (201, response)
        }
        try await store.save(activity, isNew: true)
        XCTAssertEqual(store.activities.count, 1)
        XCTAssertEqual(store.activities[0].id, activity.id)
        let listing = try json(["activities": [payload], "legacy_activity_count": 0])
        StubProtocol.handler = { _ in (200, listing) }
        let reloaded = TripStore(api: api, tripID: "demo-trip")
        await reloaded.refresh()
        XCTAssertTrue(reloaded.hasLoaded)
        XCTAssertNil(reloaded.loadError)
        XCTAssertEqual(reloaded.activities[0].id, activity.id)
        XCTAssertEqual(reloaded.activities[0].details, ["Location": "Chicago"])
    }

    func testFailedSaveAndDeleteKeepLocalState() async throws {
        let store = TripStore(api: makeAPI(), tripID: "demo-trip")
        let draft = Activity.blank()
        StubProtocol.handler = { _ in (503, Data()) }
        do {
            try await store.save(draft, isNew: true)
            XCTFail("Expected failure")
        } catch {}
        XCTAssertTrue(store.activities.isEmpty)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let saved = try encoder.encode(draft)
        StubProtocol.handler = { _ in (201, saved) }
        try await store.save(draft, isNew: true)
        StubProtocol.handler = { _ in (503, Data()) }
        do {
            try await store.delete(id: draft.id)
            XCTFail("Expected failure")
        } catch {}
        XCTAssertEqual(store.activities.count, 1)
    }

    func testLoadFailureAndLegacyWarning() async throws {
        let store = TripStore(api: makeAPI(), tripID: "demo-trip")
        StubProtocol.handler = { _ in (404, Data()) }
        await store.refresh()
        XCTAssertFalse(store.hasLoaded)
        XCTAssertNotNil(store.loadError)
        let listing = try json(["activities": [], "legacy_activity_count": 2])
        StubProtocol.handler = { _ in (200, listing) }
        await store.refresh()
        XCTAssertTrue(store.hasLoaded)
        XCTAssertEqual(store.legacyActivityCount, 2)
        XCTAssertNil(store.loadError)
    }
}
