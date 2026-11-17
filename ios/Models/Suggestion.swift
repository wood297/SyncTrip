/*
 Activity ideas for 04 Suggestions
 Prototype only: a fixed list of general ideas that fit most trips. They are
 not generated from the trip, place, or time, and nothing is sent to a server.
 Using one fills in the new activity's type and name (and notes if empty).
 */

import Foundation

struct Suggestion: Identifiable, Hashable {
    let title: String
    let type: ActivityType
    let minutes: Int
    let blurb: String

    var id: String { title }

    // e.g. "45 min", "1 hour", "1.5 hours", "2 hours"
    var durationText: String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = Double(minutes) / 60
        if minutes == 60 { return "1 hour" }
        return hours == hours.rounded()
            ? "\(Int(hours)) hours"
            : "\(hours.formatted(.number.precision(.fractionLength(1)))) hours"
    }

    // e.g. "Custom · 2 hours"
    var metaText: String { "\(type.label) · \(durationText)" }

    // Fills in the draft; the time slot and place are left as they are
    func apply(to activity: inout Activity) {
        activity.type = type
        activity.title = title
        if activity.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activity.notes = blurb
        }
    }

    // Ideas that fit in the slot come first, then the longer ones, each in list order
    static func ordered(forSlotMinutes slot: Int) -> [Suggestion] {
        let fits = presets.filter { $0.minutes <= slot }
        let longer = presets.filter { $0.minutes > slot }
        return fits + longer
    }

    // One "page" of ideas; "Show different ideas" moves to the next page and
    // wraps back to the start after the last one
    static func page(_ index: Int, forSlotMinutes slot: Int, size: Int = 3) -> [Suggestion] {
        let list = ordered(forSlotMinutes: slot)
        guard !list.isEmpty, size > 0 else { return [] }
        let pageCount = (list.count + size - 1) / size
        let start = (((index % pageCount) + pageCount) % pageCount) * size
        return Array(list[start..<min(start + size, list.count)])
    }

    static let presets: [Suggestion] = [
        Suggestion(title: "Walking tour of the old town", type: .custom, minutes: 120,
                   blurb: "See the main sights on foot. Many cities have free tours."),
        Suggestion(title: "Local museum", type: .custom, minutes: 120,
                   blurb: "Good if it rains. Check for a free or discounted entry day."),
        Suggestion(title: "Coffee and a pastry", type: .food, minutes: 45,
                   blurb: "Find a local café and try something you can’t get at home."),
        Suggestion(title: "City viewpoint", type: .custom, minutes: 60,
                   blurb: "Head somewhere high for a view over the city. Best near sunset."),
        Suggestion(title: "Food market", type: .food, minutes: 90,
                   blurb: "Graze on local snacks. Bring some cash for smaller stalls."),
        Suggestion(title: "Park or garden walk", type: .custom, minutes: 60,
                   blurb: "A slow break between busier plans. Free in most places."),
        Suggestion(title: "Scenic ride across town", type: .transport, minutes: 60,
                   blurb: "Take a tram, bus, or ferry line end to end and hop off anywhere."),
        Suggestion(title: "Rest at the hotel", type: .hotel, minutes: 60,
                   blurb: "Recharge before the evening. Good after an early start."),
        Suggestion(title: "Souvenir shopping", type: .custom, minutes: 60,
                   blurb: "Look for local makers and markets instead of airport shops."),
        Suggestion(title: "Live music or a show", type: .custom, minutes: 120,
                   blurb: "Check tonight’s listings. Smaller venues often sell tickets at the door."),
        Suggestion(title: "Sit-down dinner", type: .food, minutes: 90,
                   blurb: "Book ahead for groups. Ask the hotel for a local favourite."),
        Suggestion(title: "Day-trip lookout drive", type: .transport, minutes: 180,
                   blurb: "Drive or ride out of town for a view. Check the route before you go."),
    ]
}
