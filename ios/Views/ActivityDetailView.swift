/*
 Activity details (Figma: 06 Activity details)
 One activity: type, name and time, its place on a map with Open in Maps,
 template fields and notes. Edit activity opens the edit form (Figma 07)
 full screen; ••• has Delete. The map finds the typed place with MapKit
 search; until it does, or if nothing matches, a plain tinted panel shows.
 The bottom menu bar is hidden here, as in Figma.

 Static for the prototype, like the Day plan:
 - the "Main plan" chip (every activity is on the main plan until forks exist)
 - "Skip it · start a fork" is shown but disabled (forks are a later feature)
 - the "N going" chip and Who's going card are not shown,
   because the model has no member data yet
 */

import MapKit
import SwiftUI

struct ActivityDetailView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let activityID: UUID

    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        Group {
            page
        }
        .hidesMenuBar()
    }

    @ViewBuilder
    private var page: some View {
        // Look up by id so edits show here right away
        if let activity = store.activity(id: activityID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    navRow
                    heading(activity)
                    if !activity.location.isEmpty {
                        placeCard(activity.location)
                    }
                    templateFields(activity)
                    if !activity.notes.isEmpty {
                        notesCard(activity.notes)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.ground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationTitle(activity.title)
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
            .fullScreenCover(isPresented: $showEdit) {
                ActivityFormView(activity: activity, isNew: false) {
                    try await store.save($0, isNew: false)
                } onDelete: {
                    try await store.delete(id: activityID)
                }
            }
            .alert("Couldn’t delete activity", isPresented: Binding(
                get: { deleteError != nil }, set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: { Text(deleteError ?? "") }
            .confirmationDialog("Delete this activity?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
            } message: {
                Text("This can’t be undone.")
            }
        } else {
            // Shown briefly after the activity is deleted from the edit form
            ContentUnavailableView("Activity not found", systemImage: "questionmark.circle")
                .onAppear { dismiss() }
        }
    }

    // MARK: - Header

    private var navRow: some View {
        HStack {
            Button { dismiss() } label: {
                CircleIcon(systemName: "chevron.left")
            }
            .accessibilityLabel("Back")

            Spacer()

            Menu {
                Button("Delete activity", systemImage: "trash", role: .destructive) {
                    confirmDelete = true
                }
            } label: {
                CircleIcon(systemName: "ellipsis")
            }
            .accessibilityLabel("Activity options")
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
    }

    // Type, name, time and plan chip
    private func heading(_ activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: activity.type.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 14, height: 14)
                CapsLabel(text: activity.type.label)
            }
            .accessibilityElement(children: .combine)

            Text(activity.title)
                .font(.titleLarge)
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(Activity.slotText(from: activity.start, to: activity.end))
                .font(.bodyRegular)
                .foregroundStyle(Theme.muted)

            Text("Main plan")
                .font(.meta)
                .foregroundStyle(Theme.forest)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.tint, in: Capsule())
        }
    }

    // MARK: - Cards

    // Map preview, then the place with Open in Maps
    private func placeCard(_ location: String) -> some View {
        VStack(spacing: 0) {
            PlaceMap(query: searchText(for: location))
                .frame(height: 120)

            HairlineDivider()

            Button { openInMaps(location) } label: {
                HStack(spacing: 10) {
                    Text(location)
                        .font(.bodyRegular)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Open in Maps")
                        .font(.bodyRegular)
                        .foregroundStyle(Theme.ink)
                        .fixedSize()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                }
                .padding(.leading, 16)
                .padding(.trailing, 14)
                .padding(.vertical, 14)
            }
            .buttonStyle(RowButtonStyle())
            .accessibilityLabel("\(location). Open in Maps")
        }
        .stCard()
    }

    // Filled template fields, e.g. Flight number; not in the Figma example
    @ViewBuilder
    private func templateFields(_ activity: Activity) -> some View {
        let filled = activity.type.fields.filter { !(activity.details[$0] ?? "").isEmpty }
        if !filled.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CapsLabel(text: "Details")
                RowGroup {
                    ForEach(filled, id: \.self) { field in
                        DetailRow(field, value: activity.details[field] ?? "")
                    }
                }
            }
        }
    }

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: "Notes")
            Text(notes)
                .font(.bodyRegular)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .stCard()
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button("Edit activity") { showEdit = true }
                .buttonStyle(PillButtonStyle(filled: true))

            Button("Skip it · start a fork") {}
                .buttonStyle(PillButtonStyle(filled: false))
                .disabled(true)   // forks are a later feature
                .opacity(0.5)
                .accessibilityHint("Forks are not available yet")
        }
        .disabled(isDeleting)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Theme.ground)
    }

    private func delete() {
        isDeleting = true
        Task { @MainActor in
            defer { isDeleting = false }
            do {
                try await store.delete(id: activityID)
                dismiss()
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    // MARK: - Maps

    // Adds the trip's destination so "Art Institute" finds the one in Chicago
    private func searchText(for location: String) -> String {
        guard let destination = store.trip?.destination, !destination.isEmpty,
              !location.localizedCaseInsensitiveContains(destination) else { return location }
        return "\(location), \(destination)"
    }

    private func openInMaps(_ location: String) {
        var url = URLComponents(string: "https://maps.apple.com/")!
        url.queryItems = [URLQueryItem(name: "q", value: searchText(for: location))]
        if let link = url.url { openURL(link) }
    }
}

// Small, non-interactive map centred on the first MapKit search result
private struct PlaceMap: View {
    let query: String
    @State private var place: MKMapItem?

    var body: some View {
        ZStack {
            Theme.tint
            if let place {
                Map(initialPosition: .item(place), interactionModes: []) {
                    Marker(item: place)
                        .tint(Theme.forest)
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
            } else {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.forest)
            }
        }
        .accessibilityHidden(true)
        .task(id: query) {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            place = try? await MKLocalSearch(request: request).start().mapItems.first
        }
    }
}

#Preview {
    let store = TripStore(previewActivities: Activity.samples)
    NavigationStack {
        ActivityDetailView(activityID: store.activities[0].id)
    }
    .environment(store)
}
