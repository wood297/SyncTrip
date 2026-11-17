/*
 Create trip tests (Figma 11 Create trip)
 Checks what the form sends to POST /api/v1/trips, when Create trip is enabled,
 and that a created trip is added to the Trips list. The API is stubbed.
 */

import Foundation
import Testing
@testable import SyncTripCore

// Answers POST /api/v1/trips with a canned status and body, and keeps the request
private final class CreateTripStub: URLProtocol {
    nonisolated(unsafe) static var status = 201
    nonisolated(unsafe) static var lastBody: Data?
    nonisolated(unsafe) static var lastMethod: String?
    nonisolated(unsafe) static var lastPath: String?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastMethod = request.httpMethod
        Self.lastPath = request.url?.path
        // URLSession moves the body into a stream before it reaches a URLProtocol
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            stream.close()
            Self.lastBody = data
        } else {
            Self.lastBody = request.httpBody
        }
        let sent = (try? JSONSerialization.jsonObject(with: Self.lastBody ?? Data())) as? [String: Any] ?? [:]
        var reply = sent
        reply["activities"] = [String: Any]()
        let body = Self.status == 201
            ? try! JSONSerialization.data(withJSONObject: reply)
            : try! JSONSerialization.data(withJSONObject: ["detail": "rejected"])
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
@Suite(.serialized)
struct CreateTripTests {
    private func makeAPI() -> ActivityAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CreateTripStub.self]
        return ActivityAPI(baseURL: URL(string: "http://localhost:8000"),
                           session: URLSession(configuration: configuration))
    }

    private func draft(name: String = "Winter trip", destination: String = "Chicago") -> NewTrip {
        var trip = NewTrip(id: "trip-test-1", name: name, destination: destination)
        trip.startDate = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 1))!
        return trip
    }

    @Test func createIsEnabledOnlyWithNameAndDestination() {
        #expect(draft().isValid)
        #expect(!draft(name: "  ").isValid, "Name is required")
        #expect(!draft(destination: "").isValid, "Destination is required by the backend")
        #expect(!draft(name: String(repeating: "a", count: 201)).isValid, "At most 200 characters")
    }

    @Test func sendsTheBackendFields() throws {
        let data = try JSONEncoder().encode(draft(name: "  Winter trip ", destination: "Chicago "))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(json == ["trip_id": "trip-test-1", "name": "Winter trip", "destination": "Chicago",
                         "start_date": "2026-12-01", "status": "planning"])
    }

    @Test func createdTripIsAddedToTheList() async throws {
        CreateTripStub.status = 201
        let list = TripListStore(api: makeAPI())
        let trip = try await list.create(draft())

        #expect(CreateTripStub.lastMethod == "POST")
        #expect(CreateTripStub.lastPath == "/api/v1/trips")
        #expect(trip == Trip(id: "trip-test-1", name: "Winter trip", destination: "Chicago",
                             startDateText: "2026-12-01", status: "planning"))
        #expect(list.trips.map(\.id) == ["trip-test-1"])

        // Retrying the same draft (same ID) doesn't list the trip twice
        _ = try await list.create(draft())
        #expect(list.trips.map(\.id) == ["trip-test-1"])
    }

    @Test func rejectedTripShowsATripMessage() async {
        CreateTripStub.status = 422
        let list = TripListStore(api: makeAPI())
        do {
            _ = try await list.create(draft())
            Issue.record("A 422 response should throw")
        } catch {
            #expect(error.localizedDescription.contains("trip name and destination"))
        }
        #expect(list.trips.isEmpty, "Nothing is added when the backend rejects the trip")
        CreateTripStub.status = 201
    }
}
