/*
 New trip (Figma: 11 Create trip)
 What the Create trip form sends to POST /api/v1/trips. The backend needs a
 name, destination and start date; it has no end date yet, so the form has no
 Ends row. The trip ID is made here and kept, so retrying after a lost
 response can't create the trip twice.
 */

import Foundation

struct NewTrip: Encodable, Equatable {
    var id = UUID().uuidString.lowercased()
    var name = ""
    var destination = ""
    var startDate: Date = Calendar.current.startOfDay(for: .now)

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedDestination: String { destination.trimmingCharacters(in: .whitespacesAndNewlines) }

    // Same limits as the backend: both required, at most 200 characters
    var isValid: Bool {
        !trimmedName.isEmpty && !trimmedDestination.isEmpty
            && trimmedName.count <= 200 && trimmedDestination.count <= 200
    }

    // e.g. "2026-12-01", the format the backend accepts for new trips
    var startDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startDate)
    }

    // The trip as the Trips page will show it, for previews and the trip-created screen
    var asTrip: Trip {
        Trip(id: id, name: trimmedName, destination: trimmedDestination,
             startDateText: startDateText, status: "planning")
    }

    enum CodingKeys: String, CodingKey {
        case id = "trip_id"
        case name, destination
        case startDate = "start_date"
        case status
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(trimmedName, forKey: .name)
        try container.encode(trimmedDestination, forKey: .destination)
        try container.encode(startDateText, forKey: .startDate)
        try container.encode("planning", forKey: .status)
    }
}
