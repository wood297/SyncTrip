/*
 Activity model
 One itinerary item. Every activity has a name, time and place ("Where");
 each preset type (template) adds a few fields of its own.
 */

import Foundation

enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case flight, food, transport, hotel, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flight: "Flight"
        case .food: "Food"
        case .transport: "Transit"
        case .hotel: "Hotel"
        case .custom: "Custom"
        }
    }

    // SF Symbol name (outline glyphs, as in the Figma type tiles)
    var icon: String {
        switch self {
        case .flight: "airplane"
        case .food: "fork.knife"
        case .transport: "bus"
        case .hotel: "bed.double"
        case .custom: "star"
        }
    }

    // Template fields shown in the form for this type, besides Name and Where
    var fields: [String] {
        switch self {
        case .flight: ["Flight number", "To"]
        case .food: ["Reservation name"]
        case .transport: ["Mode", "Drop-off"]
        case .hotel: ["Confirmation number"]
        case .custom: []
        }
    }
}

struct Activity: Identifiable, Codable {
    var id = UUID()
    var version: Int? = nil
    var type: ActivityType
    var title: String
    var start: Date
    var end: Date
    var details: [String: String] = [:]   // keyed by type.fields and locationKey
    var notes: String = ""

    static let locationKey = "Location"

    // Where the activity happens. Stored in details so the API stays the same.
    var location: String {
        get { details[Self.locationKey, default: ""] }
        set { details[Self.locationKey] = newValue }
    }

    // e.g. "1h 30m"
    var durationText: String {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    // e.g. "9:00 AM – 10:30 AM"
    var timeRange: String {
        "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    // Empty activity starting at the next full hour
    static func blank() -> Activity {
        let start = Calendar.current.nextDate(after: .now,
                                              matching: DateComponents(minute: 0),
                                              matchingPolicy: .nextTime) ?? .now
        return Activity(type: .custom, title: "", start: start, end: start.addingTimeInterval(3600))
    }

    // Sample two-day trip starting today
    static var samples: [Activity] {
        let cal = Calendar.current
        let day1 = cal.startOfDay(for: .now)
        let day2 = cal.date(byAdding: .day, value: 1, to: day1)!
        func at(_ day: Date, _ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }
        return [
            Activity(type: .flight, title: "Flight to Chicago", start: at(day1, 8), end: at(day1, 9, 15),
                     details: ["Flight number": "UA 1234", "Location": "IND", "To": "ORD"]),
            Activity(type: .hotel, title: "Hotel check-in", start: at(day1, 11), end: at(day1, 11, 30),
                     details: ["Location": "Downtown Hotel"]),
            Activity(type: .food, title: "Deep-dish lunch", start: at(day1, 12, 30), end: at(day1, 14)),
            Activity(type: .custom, title: "Architecture boat tour", start: at(day2, 10), end: at(day2, 11, 30),
                     details: ["Location": "Riverwalk"]),
            Activity(type: .transport, title: "Train to airport", start: at(day2, 15), end: at(day2, 16),
                     details: ["Mode": "Train"])
        ]
    }
}
