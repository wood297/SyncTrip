/*
 Detail page for one activity
 Shows all fields, with Edit (opens the form) and Delete (asks first)
 */

import SwiftUI

struct ActivityDetailView: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let activityID: UUID

    @State private var showEdit = false
    @State private var confirmDelete = false

    var body: some View {
        // Look up by id so edits show here right away
        if let activity = store.activity(id: activityID) {
            List {
                Section {
                    Label(activity.type.label, systemImage: activity.type.icon)
                    LabeledContent("Starts", value: activity.start.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Ends", value: activity.end.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Duration", value: activity.durationText)
                }

                let filled = activity.type.fields.filter { !(activity.details[$0] ?? "").isEmpty }
                if !filled.isEmpty {
                    Section("Details") {
                        ForEach(filled, id: \.self) { field in
                            LabeledContent(field, value: activity.details[field] ?? "")
                        }
                    }
                }

                if !activity.notes.isEmpty {
                    Section("Notes") {
                        Text(activity.notes)
                    }
                }

                Section {
                    Button("Delete Activity", role: .destructive) {
                        confirmDelete = true
                    }
                }
            }
            .navigationTitle(activity.title)
            .toolbar {
                Button("Edit") { showEdit = true }
            }
            .sheet(isPresented: $showEdit) {
                ActivityFormView(activity: activity, isNew: false) { store.save($0) }
            }
            .confirmationDialog("Delete this activity?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.delete(id: activityID)
                    dismiss()
                }
            }
        } else {
            ContentUnavailableView("Activity not found", systemImage: "questionmark.circle")
        }
    }
}

#Preview {
    let store = TripStore()
    NavigationStack {
        ActivityDetailView(activityID: store.activities[0].id)
    }
    .environment(store)
}
