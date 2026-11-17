/*
 Trips (Figma: 01 Trips)
 Every trip from the backend, grouped into Now, Upcoming, and Past. Tapping a
 trip opens its Day plan.

 Uses real trip data from TripListStore. Sections come from the trip's status
 (active / planning / completed or cancelled), because trips have no end date
 yet. The Now card shows today's next activity from that trip's activities.
 Not shown, because the backend has no data for them yet: end dates,
 traveller counts and avatars, and the fork line. The + button opens
 Create trip (Figma 11-12, CreateTripView).
 */

import SwiftUI

struct TripsView: View {
    @Environment(TripListStore.self) private var list
    // Called with the trip the user tapped
    var onOpen: (Trip) -> Void = { _ in }

    @State private var creatingTrip = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, 22)
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await list.refresh() }
        .refreshable { await list.refresh() }
        .alert("Couldn’t refresh trips", isPresented: Binding(
            get: { list.loadError != nil && list.hasLoaded },
            set: { if !$0 { list.loadError = nil } }
        )) {
            Button("OK", role: .cancel) { list.loadError = nil }
        } message: { Text(list.loadError ?? "") }
    }

    private var header: some View {
        HStack {
            Text("Trips")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.68)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            // Opens 11 Create trip
            Button { creatingTrip = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.forest, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New trip")
        }
        .fullScreenCover(isPresented: $creatingTrip) {
            CreateTripView(onOpen: onOpen)
        }
    }

    @ViewBuilder
    private var content: some View {
        let sections = list.sections
        if list.isLoading && !list.hasLoaded {
            ProgressView("Loading trips…")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let error = list.loadError, !list.hasLoaded {
            ContentUnavailableView {
                Label("Couldn’t load trips", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { Task { await list.refresh() } }
            }
        } else if sections.isEmpty {
            ContentUnavailableView("No trips yet",
                                   systemImage: "suitcase",
                                   description: Text("Trips you create will show up here."))
        } else {
            VStack(alignment: .leading, spacing: 24) {
                if !sections.now.isEmpty {
                    section(.now) {
                        VStack(spacing: 12) {
                            ForEach(sections.now) { trip in
                                Button { onOpen(trip) } label: {
                                    NowTripCard(trip: trip, activities: list.nowActivities[trip.id])
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if !sections.upcoming.isEmpty {
                    section(.upcoming) { tripList(sections.upcoming) }
                }
                if !sections.past.isEmpty {
                    section(.past) { tripList(sections.past) }
                }
            }
        }
    }

    private func section<Content: View>(_ section: TripSection,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CapsLabel(text: section.title)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    // White card of rows, divided by hairlines
    private func tripList(_ trips: [Trip]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
                if index > 0 { HairlineDivider() }
                Button { onOpen(trip) } label: {
                    TripRow(trip: trip)
                }
                .buttonStyle(.plain)
            }
        }
        .stCard()
    }
}

// Dark green card for a trip happening now
private struct NowTripCard: View {
    let trip: Trip
    // nil when the trip's activities couldn't be loaded
    let activities: [Activity]?
    var now: Date = .now

    var body: some View {
        let today = activities.map { TripToday(activities: $0, now: now) }
        VStack(alignment: .leading, spacing: 0) {
            if let today, let day = today.dayNumber {
                Text("Day \(day) of \(today.dayCount)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.14), in: Capsule())
                    .padding(.bottom, 14)
            }

            Text(trip.name)
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.52)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Text("\(trip.startText(now: now)) · \(trip.destination)")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 4)

            if let today {
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 1)
                    .padding(.vertical, 14)
                CapsLabel(text: "Today in \(trip.destination)", color: .white.opacity(0.6))
                Text(todayLine(today))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.forest, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the day plan")
    }

    private func todayLine(_ today: TripToday) -> String {
        guard let next = today.next else {
            return today.hasPlansToday ? "Nothing else planned today" : "No plans today"
        }
        let time = { (date: Date) in date.formatted(date: .omitted, time: .shortened) }
        return today.nextHasStarted
            ? "Now: \(next.title) until \(time(next.end))"
            : "Next: \(next.title) at \(time(next.start))"
    }
}

// Row in the Upcoming / Past lists
private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.name)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.085)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the day plan")
    }

    private var subtitle: String {
        let base = "\(trip.startText()) · \(trip.destination)"
        return trip.isCancelled ? "Cancelled · \(base)" : base
    }
}

#Preview("01 Trips") {
    NavigationStack { TripsView() }
        .environment(TripListStore(previewTrips: Trip.samples,
                                   nowActivities: ["iceland": Activity.samples]))
}

#Preview("No trips") {
    NavigationStack { TripsView() }
        .environment(TripListStore(previewTrips: []))
}
