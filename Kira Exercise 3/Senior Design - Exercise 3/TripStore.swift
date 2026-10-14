/*
 Shared store for the trip's activities
 Passed to all views through the environment
 */

import Foundation
import Observation

@Observable
class TripStore {
    var activities: [Activity] = Activity.samples

    // Distinct days that have activities, earliest first
    var days: [Date] {
        Set(activities.map { Calendar.current.startOfDay(for: $0.start) }).sorted()
    }

    // Activities on one day, sorted by start time
    func schedule(on day: Date) -> [Activity] {
        activities
            .filter { Calendar.current.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    func activity(id: UUID) -> Activity? {
        activities.first { $0.id == id }
    }

    // Adds a new activity or replaces an existing one with the same id
    func save(_ activity: Activity) {
        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[index] = activity
        } else {
            activities.append(activity)
        }
    }

    func delete(id: UUID) {
        activities.removeAll { $0.id == id }
    }
}
