/*
 Day plan (Figma: 02 Day plan)
 One day of the trip as a timeline: pick a day at the top, see that day's
 activities in time order. Gaps of 90+ minutes show a "Free until ..." slot
 that opens the add form at that time. On today's date a line marks the
 current time. Tapping an activity opens its detail page; + adds one.

 Uses the selected trip from TripStore: its destination as the title, its
 name in the subtitle, and its real activities. Static for the prototype:
 - member avatars / chat button in the top-left pill
 - the Forks tab (forks are a later feature)
 - "N going" and the fork marker under an activity are not shown,
   because the model has no member or fork data yet
 */

import SwiftUI

struct DayPlanView: View {
    @Environment(TripStore.self) private var store

    // Selected trip's destination and name; the trip ID until the trip list loads
    private var place: String { store.trip?.destination ?? "Day plan" }
    private var tripName: String { store.trip?.name ?? store.tripID }

    @State private var selectedDay: Date?
    @State private var plan: PlanTab = .main
    @State private var draft: Activity?

    enum PlanTab { case main, forks }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navRow
                    .padding(.bottom, 12)
                titleRow
                    .padding(.bottom, 10)
                if !store.days.isEmpty {
                    dayStrip
                        .padding(.bottom, 14)
                }
                planSwitch
                    .padding(.bottom, 16)
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if store.legacyActivityCount > 0 {
                Text("\(store.legacyActivityCount) older activities need conversion before they can appear here.")
                    .font(.footnote)
                    .padding()
                    .background(.regularMaterial)
            }
        }
        .task { if !store.hasLoaded { await store.refresh() } }
        .refreshable { await store.refresh() }
        .alert("Couldn’t refresh itinerary", isPresented: Binding(
            get: { store.loadError != nil && store.hasLoaded },
            set: { if !$0 { store.loadError = nil } }
        )) {
            Button("OK", role: .cancel) { store.loadError = nil }
        } message: { Text(store.loadError ?? "") }
        .navigationDestination(for: UUID.self) { id in
            ActivityDetailView(activityID: id)
        }
        .sheet(item: $draft) { activity in
            ActivityFormView(activity: activity, isNew: true) {
                try await store.save($0, isNew: true)
            }
        }
    }

    // MARK: - Selected day

    // The chosen day, or today if the trip has activities today, or the first day
    private var day: Date? {
        let days = store.days
        if let selectedDay, days.contains(selectedDay) { return selectedDay }
        return days.first { Calendar.current.isDateInToday($0) } ?? days.first
    }

    private var subtitle: String {
        let days = store.days
        guard let day, let index = days.firstIndex(of: day) else { return tripName }
        return "\(tripName) · Day \(index + 1) of \(days.count)"
    }

    // MARK: - Header

    private var navRow: some View {
        HStack {
            membersPill

            Spacer()

            HStack(spacing: 10) {
                Menu {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await store.refresh() }
                    }
                    .disabled(store.isLoading)
                    Button("Trip settings", systemImage: "gearshape") {}
                        .disabled(true)   // later feature
                } label: {
                    CircleIcon(systemName: "ellipsis")
                }
                .accessibilityLabel("Trip options")

                Button {
                    draft = newActivity()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.forest, in: Circle())
                }
                .accessibilityLabel("Add activity")
                .disabled(!store.hasLoaded || store.isLoading)
            }
        }
        .buttonStyle(.plain)
    }

    // Static members + chat shortcut (trip chat is a later feature)
    private var membersPill: some View {
        HStack(spacing: 8) {
            HStack(spacing: -6) {
                AvatarView(initial: "A", color: Theme.avatarPink)
                AvatarView(initial: "L", color: Theme.avatarBlue)
                AvatarView(initial: "M", color: Theme.avatarGreen)
                AvatarView(initial: "S", color: Theme.avatarSand)
            }
            Image(systemName: "bubble.left")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Circle()
                .fill(Theme.unread)
                .frame(width: 8, height: 8)
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .frame(height: 44)
        .background(Theme.surface, in: Capsule())
        .shadow(color: Theme.shadow, radius: 7, x: 0, y: 4)
        .shadow(color: Theme.shadow, radius: 1, x: 0, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("4 trip members. Unread chat messages.")
    }

    private var titleRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            syncStatus
                .padding(.bottom, 2)
        }
    }

    // Shows whether the itinerary matches the server
    private var syncStatus: some View {
        let (icon, label): (String, String) =
            store.isLoading ? ("arrow.triangle.2.circlepath", "Syncing")
            : store.loadError != nil ? ("exclamationmark.icloud", "Not synced")
            : ("checkmark", "Synced")
        return HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.system(size: 13))
        }
        .foregroundStyle(Theme.muted)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Day picker and plan switch

    private var dayStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(store.days, id: \.self) { date in
                    Button { selectedDay = date } label: {
                        DayChip(date: date, selected: date == day)
                    }
                    .buttonStyle(.plain)
                }
            }
            // Room for the card shadows inside the scroll view
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
        .padding(.vertical, -8)
    }

    private var planSwitch: some View {
        HStack(spacing: 2) {
            planSegment("Main plan", icon: "calendar", tab: .main)
            planSegment("Forks", icon: "arrow.triangle.branch", tab: .forks)
        }
        .padding(3)
        .frame(height: 50)
        .background(Theme.segment, in: Capsule())
    }

    private func planSegment(_ title: String, icon: String, tab: PlanTab) -> some View {
        let selected = plan == tab
        return Button { plan = tab } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? Theme.ink : Theme.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selected ? Theme.surface : Color.clear, in: Capsule())
            .shadow(color: selected ? Theme.shadow : .clear, radius: 7, x: 0, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Timeline

    @ViewBuilder
    private var content: some View {
        if store.isLoading && !store.hasLoaded {
            ProgressView("Loading itinerary…")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let error = store.loadError, !store.hasLoaded {
            ContentUnavailableView {
                Label("Couldn’t load itinerary", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { Task { await store.refresh() } }
            }
        } else if plan == .forks {
            forksPlaceholder
        } else if let day, !store.activities.isEmpty {
            timeline(for: day)
        } else {
            ContentUnavailableView("No activities yet",
                                   systemImage: "calendar.badge.plus",
                                   description: Text("Tap + to add one."))
        }
    }

    private func timeline(for day: Date) -> some View {
        let items = TimelineItem.build(from: store.schedule(on: day), on: day, now: .now)
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                switch item {
                case .activity(let activity):
                    NavigationLink(value: activity.id) {
                        TimelineActivityRow(activity: activity)
                    }
                    .buttonStyle(.plain)
                case .free(let start, let end):
                    Button {
                        draft = newActivity(start: start, end: min(start.addingTimeInterval(3600), end))
                    } label: {
                        FreeSlotRow(start: start, end: end)
                    }
                    .buttonStyle(.plain)
                case .now(let date):
                    NowLine(date: date)
                }
            }
        }
    }

    private var forksPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 24))
                .foregroundStyle(Theme.forkViolet)
                .accessibilityHidden(true)
            Text("No forks on this day")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("A fork lets part of the group follow its own plan for a while, then meet back up.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .stCard(radius: 20)
    }

    // MARK: - Helpers

    // New blank activity: at the given time, else next hour today, else 9 AM on the selected day
    private func newActivity(start: Date? = nil, end: Date? = nil) -> Activity {
        var activity = Activity.blank()
        if let start {
            activity.start = start
            activity.end = end ?? start.addingTimeInterval(3600)
        } else if let day, !Calendar.current.isDateInToday(day),
                  let nine = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) {
            activity.start = nine
            activity.end = nine.addingTimeInterval(3600)
        }
        return activity
    }
}

// MARK: - Timeline items

private enum TimelineItem: Identifiable {
    case activity(Activity)
    case free(start: Date, end: Date)
    case now(Date)

    var id: String {
        switch self {
        case .activity(let activity): activity.id.uuidString
        case .free(let start, _): "free-\(start.timeIntervalSince1970)"
        case .now: "now"
        }
    }

    var date: Date {
        switch self {
        case .activity(let activity): activity.start
        case .free(let start, _): start
        case .now(let date): date
        }
    }

    static let minimumFreeGap: TimeInterval = 90 * 60

    // Activities (sorted by start) plus free slots between them and a "now" line on today
    static func build(from activities: [Activity], on day: Date, now: Date) -> [TimelineItem] {
        var items: [TimelineItem] = []
        var lastEnd: Date?
        for activity in activities {
            if let lastEnd, activity.start.timeIntervalSince(lastEnd) >= minimumFreeGap {
                items.append(.free(start: lastEnd, end: activity.start))
            }
            items.append(.activity(activity))
            lastEnd = max(lastEnd ?? activity.end, activity.end)
        }
        if Calendar.current.isDate(now, inSameDayAs: day) {
            let index = items.firstIndex { $0.date > now } ?? items.endIndex
            items.insert(.now(now), at: index)
        }
        return items
    }
}

// MARK: - Row views

private enum TimeText {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
    static let clock = formatter("h:mm")   // "8:30"
    static let period = formatter("a")     // "AM"
}

// "8:30" over "AM" in the left column
private struct TimeLabel: View {
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(TimeText.clock.string(from: date))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(TimeText.period.string(from: date))
                .font(.system(size: 11, weight: .medium))
                .tracking(0.22)
                .foregroundStyle(Theme.muted)
        }
        .padding(.top, 12)
        .frame(width: 52, alignment: .leading)
    }
}

private struct TimelineActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TimeLabel(date: activity.start)

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.08)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: activity.type.icon)
                        .font(.system(size: 11))
                        .frame(width: 14, height: 14)
                    Text("Until \(activity.end.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 13))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, 12)
            .stCard(radius: 14)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens activity details")
    }
}

// Dashed "Free until 5:00 PM · Tap to add" slot
private struct FreeSlotRow: View {
    let start: Date
    let end: Date

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TimeLabel(date: start)

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Free until \(end.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("Tap to add")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.forest)
            .padding(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.sage, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Adds an activity in this free time")
    }
}

// Green "9:41 ————" current-time marker
private struct NowLine: View {
    let date: Date

    var body: some View {
        HStack(spacing: 0) {
            Text(TimeText.clock.string(from: date))
                .font(.system(size: 11, weight: .medium))
                .tracking(0.22)
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Theme.forest, in: Capsule())
            Rectangle()
                .fill(Theme.forest)
                .frame(height: 1.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now, \(date.formatted(date: .omitted, time: .shortened))")
    }
}

// One day in the picker: "Sat" over "13"
private struct DayChip: View {
    let date: Date
    let selected: Bool

    var body: some View {
        VStack(spacing: 1) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 13))
                .foregroundStyle(selected ? Color.white : Theme.muted)
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 19, weight: .semibold))
                .tracking(-0.095)
                .foregroundStyle(selected ? Color.white : Theme.ink)
        }
        .frame(width: 64, height: 58)
        .background(selected ? Theme.forest : Theme.surface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: selected ? .clear : Theme.shadow, radius: 7, x: 0, y: 4)
        .shadow(color: selected ? .clear : Theme.shadow, radius: 1, x: 0, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    NavigationStack {
        DayPlanView()
    }
    .environment(TripStore(previewActivities: Activity.samples))
}
