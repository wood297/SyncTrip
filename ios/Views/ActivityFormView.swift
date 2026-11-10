/*
 Input form for creating or editing an activity
 Shows extra fields based on the selected type.
 Save is disabled until there is a title and the end is not before the start.
 */

import SwiftUI

struct ActivityFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Activity
    let isNew: Bool
    let onSave: (Activity) -> Void

    init(activity: Activity, isNew: Bool, onSave: @escaping (Activity) -> Void) {
        _draft = State(initialValue: activity)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $draft.type) {
                        ForEach(ActivityType.allCases) { type in
                            Label(type.label, systemImage: type.icon).tag(type)
                        }
                    }
                    TextField("Title", text: $draft.title)
                }

                Section("Time") {
                    DatePicker("Starts", selection: $draft.start)
                    DatePicker("Ends", selection: $draft.end, in: draft.start...)
                }

                // Type-specific fields
                Section("\(draft.type.label) details") {
                    ForEach(draft.type.fields, id: \.self) { field in
                        TextField(field, text: detailBinding(field))
                    }
                }

                Section("Notes") {
                    TextField("Booking link, reminders", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isNew ? "New Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(cleaned)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            // Keep end after start when start moves later
            .onChange(of: draft.start) { _, newStart in
                if draft.end < newStart {
                    draft.end = newStart.addingTimeInterval(3600)
                }
            }
        }
    }

    private var isValid: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty && draft.end >= draft.start
    }

    // Trim text and drop empty fields or ones left over from a previously selected type
    private var cleaned: Activity {
        var activity = draft
        activity.title = activity.title.trimmingCharacters(in: .whitespaces)
        activity.details = activity.details
            .mapValues { $0.trimmingCharacters(in: .whitespaces) }
            .filter { activity.type.fields.contains($0.key) && !$0.value.isEmpty }
        return activity
    }

    // Binding into the details dictionary for one field
    private func detailBinding(_ field: String) -> Binding<String> {
        Binding(
            get: { draft.details[field, default: ""] },
            set: { draft.details[field] = $0 }
        )
    }
}

#Preview {
    ActivityFormView(activity: .blank(), isNew: true) { _ in }
}
