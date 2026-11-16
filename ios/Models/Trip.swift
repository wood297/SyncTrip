/*
 Trip model
 Trip metadata from GET /api/v1/trips: id, name, destination, start date, and
 status. The backend has no end date, travellers, or forks yet, so the Trips
 page groups trips by status and start date and shows only what is stored.
 */

import Foundation

struct Trip: Identifiable, Hashable, Decodable {
    let id: String
    var name: String
    var destination: String
    // Kept as sent: older records use formats like 12/25/26 or 11-14-2026
    var startDateText: String
    var status: String

    enum CodingKeys: String, CodingKey {
        case id = "trip_id"
        case name, destination
        case startDateText = "start_date"
        case status
    }

    var startDate: Date? { Trip.parseDate(startDateText) }

    // active -> Now; completed or cancelled -> Past. Any other status goes by start
    // date: starts after today -> Upcoming, already started -> Now. With no readable
    // date it stays Upcoming. There is no end date yet, so a started trip stays in
    // Now until its status is set to completed.
    func section(now: Date = .now) -> TripSection {
        switch status.lowercased() {
        case "active": return .now
        case "completed", "cancelled": return .past
        default:
            guard let startDate else { return .upcoming }
            return startDate > Calendar.current.startOfDay(for: now) ? .upcoming : .now
        }
    }

    var isCancelled: Bool { status.lowercased() == "cancelled" }

    // "Nov 14" this year, "Jan 1, 2027" otherwise; the stored text if it can't be read
    func startText(now: Date = .now) -> String {
        guard let startDate else { return startDateText }
        let calendar = Calendar.current
        if calendar.component(.year, from: startDate) == calendar.component(.year, from: now) {
            return startDate.formatted(.dateTime.month(.abbreviated).day())
        }
        return startDate.formatted(.dateTime.month(.abbreviated).day().year())
    }

    // Supported: 2026-11-14, 11-14-2026, 11/14/2026, 11/14/26
    static func parseDate(_ text: String) -> Date? {
        let value = text.trimmingCharacters(in: .whitespaces)
        let patterns: [(String, String)] = [
            (#"^\d{4}-\d{2}-\d{2}$"#, "yyyy-MM-dd"),
            (#"^\d{2}-\d{2}-\d{4}$"#, "MM-dd-yyyy"),
            (#"^\d{1,2}/\d{1,2}/\d{4}$"#, "M/d/yyyy"),
            (#"^\d{1,2}/\d{1,2}/\d{2}$"#, "M/d/yy"),
        ]
        guard let format = patterns.first(where: { value.range(of: $0.0, options: .regularExpression) != nil })?.1
        else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.isLenient = false
        formatter.dateFormat = format
        return formatter.date(from: value)
    }
}

enum TripSection: CaseIterable {
    case now, upcoming, past

    var title: String {
        switch self {
        case .now: "Now"
        case .upcoming: "Upcoming"
        case .past: "Past"
        }
    }
}

// Trips grouped for the Trips page. Now and Upcoming are soonest first, Past is
// most recent first; trips with unreadable dates go last, then by name.
struct TripSections {
    let now: [Trip]
    let upcoming: [Trip]
    let past: [Trip]

    init(trips: [Trip], now: Date = .now) {
        func ordered(_ section: TripSection, newestFirst: Bool) -> [Trip] {
            trips.filter { $0.section(now: now) == section }.sorted { a, b in
                switch (a.startDate, b.startDate) {
                case let (x?, y?) where x != y: return newestFirst ? x > y : x < y
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
            }
        }
        now = ordered(.now, newestFirst: false)
        upcoming = ordered(.upcoming, newestFirst: false)
        past = ordered(.past, newestFirst: true)
    }

    var isEmpty: Bool { now.isEmpty && upcoming.isEmpty && past.isEmpty }
}

// What the Now card says about today, worked out from the trip's activities
struct TripToday {
    // "Day 3 of 6": today's place among the days that have activities
    let dayNumber: Int?
    let dayCount: Int
    // The activity happening now, or else the next one today
    let next: Activity?
    let nextHasStarted: Bool
    let hasPlansToday: Bool

    init(activities: [Activity], now: Date = .now) {
        let calendar = Calendar.current
        let days = Set(activities.map { calendar.startOfDay(for: $0.start) }).sorted()
        let today = calendar.startOfDay(for: now)
        dayNumber = days.firstIndex(of: today).map { $0 + 1 }
        dayCount = days.count

        let todays = activities.filter { calendar.isDate($0.start, inSameDayAs: now) }
            .sorted { $0.start < $1.start }
        hasPlansToday = !todays.isEmpty
        next = todays.first { $0.end > now }
        nextHasStarted = next.map { $0.start <= now } ?? false
    }
}

extension Trip {
    // Sample trips matching the Figma Trips frame, for previews only
    static let samples: [Trip] = [
        Trip(id: "iceland", name: "Iceland Ring Road", destination: "Reykjavík",
             startDateText: "2026-06-11", status: "active"),
        Trip(id: "montreal", name: "Montréal Jazz Weekend", destination: "Montréal",
             startDateText: "2026-07-02", status: "planning"),
        Trip(id: "big-sur", name: "Big Sur Camping", destination: "Big Sur",
             startDateText: "2026-08-14", status: "planning"),
        Trip(id: "austin", name: "Austin Food Crawl", destination: "Austin",
             startDateText: "2026-03-06", status: "completed"),
    ]
}
