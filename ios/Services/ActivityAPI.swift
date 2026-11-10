import Foundation

struct ActivityListResponse: Decodable {
    let activities: [Activity]
    let legacyActivityCount: Int

    enum CodingKeys: String, CodingKey {
        case activities
        case legacyActivityCount = "legacy_activity_count"
    }
}

struct ActivityAPIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class ActivityAPI {
    private let baseURL: URL?
    private let session: URLSession

    init(baseURL: URL?, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func configured() -> ActivityAPI {
        let address = ProcessInfo.processInfo.environment["SYNCTRIP_API_URL"] ?? "http://localhost:8000"
        return ActivityAPI(baseURL: URL(string: address))
    }

    func list(tripID: String) async throws -> ActivityListResponse {
        let data = try await request(tripID: tripID, method: "GET", expected: 200)
        return try decoder().decode(ActivityListResponse.self, from: data)
    }

    func save(_ activity: Activity, tripID: String, isNew: Bool) async throws -> Activity {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try await request(
            tripID: tripID, activityID: isNew ? nil : activity.id,
            method: isNew ? "POST" : "PUT", body: try encoder.encode(activity),
            expected: isNew ? 201 : 200
        )
        return try decoder().decode(Activity.self, from: data)
    }

    func delete(id: UUID, tripID: String) async throws {
        _ = try await request(tripID: tripID, activityID: id, method: "DELETE", expected: 204)
    }

    private func request(tripID: String, activityID: UUID? = nil, method: String,
                         body: Data? = nil, expected: Int) async throws -> Data {
        guard let baseURL,
              ["http", "https"].contains(baseURL.scheme?.lowercased() ?? ""), baseURL.host != nil else {
            throw ActivityAPIError(message: "Check the API URL in the Xcode scheme settings.")
        }
        var url = baseURL.appendingPathComponent("api/v1/trips")
            .appendingPathComponent(tripID).appendingPathComponent("activities")
        if let activityID { url.appendPathComponent(activityID.uuidString.lowercased()) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 30
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ActivityAPIError(message: "The server returned an invalid response.")
        }
        guard http.statusCode == expected else {
            let message: String
            switch http.statusCode {
            case 404: message = "The trip or activity was not found. Check the trip ID and refresh."
            case 409: message = "The trip changed or this activity ID is already in use. Refresh and try again."
            case 422: message = "Check the activity fields, title length, and start/end times."
            case 503: message = "The database is unavailable. Your activity has not been confirmed saved. Try again."
            default: message = "The request failed (HTTP \(http.statusCode)). Try again."
            }
            throw ActivityAPIError(message: message)
        }
        return data
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 date")
        }
        return decoder
    }
}
