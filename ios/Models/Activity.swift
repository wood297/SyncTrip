/*
 Activity model
 One itinerary item. Each preset type has its own set of detail fields.
 */

import Foundation

enum ActivityType: String, CaseIterable, Identifiable {
    case flight, food, transport, hotel, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flight: "Flight"
        case .food: "Food"
        case .transport: "Transport"
        case .hotel: "Hotel"
        case .custom: "Custom"
        }
    }

    // SF Symbol name
    var icon: String {
        switch self {
        case .flight: "airplane"
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .hotel: "bed.double.fill"
        case .custom: "star.fill"
        }
    }

    // Extra fields shown in the form for this type
    var fields: [String] {
        switch self {
        case .flight: ["Flight number", "From", "To"]
        case .food: ["Restaurant", "Address", "Reservation name"]
        case .transport: ["Mode", "Pickup", "Drop-off"]
        case .hotel: ["Hotel", "Address", "Confirmation number"]
        case .custom: ["Location"]
        }
    }
}

struct Activity: Identifiable {
    var id = UUID()
    var type: ActivityType
    var title: String
    var start: Date
    var end: Date
    var details: [String: String] = [:]   // keyed by type.fields
    var notes: String = ""

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
                     details: ["Flight number": "UA 1234", "From": "IND", "To": "ORD"]),
            Activity(type: .hotel, title: "Hotel check-in", start: at(day1, 11), end: at(day1, 11, 30),
                     details: ["Hotel": "Downtown Hotel"]),
            Activity(type: .food, title: "Deep-dish lunch", start: at(day1, 12, 30), end: at(day1, 14)),
            Activity(type: .custom, title: "Architecture boat tour", start: at(day2, 10), end: at(day2, 11, 30),
                     details: ["Location": "Riverwalk"]),
            Activity(type: .transport, title: "Train to airport", start: at(day2, 15), end: at(day2, 16),
                     details: ["Mode": "Train"])
        ]
    }
}
