/*
 Itinerary timeline
 Activities grouped by day and sorted by time. Tap one to open its detail page.
 The + button opens the form for a new activity.
 */

import SwiftUI

struct ItineraryView: View {
    @Environment(TripStore.self) private var store
    @State private var showAdd = false

    var body: some View {
        Group {
            if store.isLoading && !store.hasLoaded {
                ProgressView("Loading itinerary…")
            } else if let error = store.loadError, !store.hasLoaded {
                ContentUnavailableView {
                    Label("Couldn’t load itinerary", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await store.refresh() } }
                }
            } else if store.activities.isEmpty {
                ContentUnavailableView("No activities yet",
                                       systemImage: "calendar.badge.plus",
                                       description: Text("Tap + to add one."))
            } else {
                List {
                    ForEach(store.days, id: \.self) { day in
                        Section(day.formatted(.dateTime.weekday(.wide).month().day())) {
                            ForEach(store.schedule(on: day)) { activity in
                                NavigationLink(value: activity.id) {
                                    ActivityRow(activity: activity)
                                }
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if store.legacyActivityCount > 0 {
                Text("\(store.legacyActivityCount) older activities need conversion before they can appear here.")
                    .font(.footnote).padding().background(.regularMaterial)
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
        .navigationTitle("Itinerary")
        .navigationDestination(for: UUID.self) { id in
            ActivityDetailView(activityID: id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh itinerary")
                .disabled(store.isLoading)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add activity")
                .disabled(!store.hasLoaded || store.isLoading)
            }
        }
        .sheet(isPresented: $showAdd) {
            ActivityFormView(activity: .blank(), isNew: true) {
                try await store.save($0, isNew: true)
            }
        }
    }
}

// One row on the timeline: start time, duration bar, title
struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(activity.start.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.monospacedDigit())
                Text(activity.durationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 70, alignment: .trailing)

            // Bar height grows with duration
            RoundedRectangle(cornerRadius: 3)
                .fill(activity.type.color)
                .frame(width: 6, height: barHeight)

            VStack(alignment: .leading, spacing: 4) {
                Label(activity.title, systemImage: activity.type.icon)
                    .font(.headline)
                Text(activity.timeRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    // 0.5 pt per minute, kept between 36 and 140 pt
    private var barHeight: CGFloat {
        let minutes = activity.end.timeIntervalSince(activity.start) / 60
        return min(max(minutes * 0.5, 36), 140)
    }
}

extension ActivityType {
    var color: Color {
        switch self {
        case .flight: .blue
        case .food: .orange
        case .transport: .green
        case .hotel: .purple
        case .custom: .gray
        }
    }
}

#Preview {
    NavigationStack {
        ItineraryView()
    }
    .environment(TripStore(previewActivities: Activity.samples))
}
