/*
 Add or edit an activity (Figma 03 Add activity and 07 Edit activity)
 Full-screen form. A new activity starts from its time slot and a type
 template; an edit highlights changed times in amber.
 Review is enabled once there is a name and the end is not before the start.
 Until the 05 Review & save screen exists, Review saves directly.
 */

import SwiftUI

struct ActivityFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Activity
    @State private var isSaving = false
    @State private var failure: Failure?
    @State private var editingTime = false
    @State private var confirmDelete = false
    private let original: Activity
    let isNew: Bool
    let onSave: (Activity) async throws -> Void
    let onDelete: (() async throws -> Void)?

    init(activity: Activity, isNew: Bool,
         onSave: @escaping (Activity) async throws -> Void,
         onDelete: (() async throws -> Void)? = nil) {
        _draft = State(initialValue: activity)
        original = activity
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isNew {
                        newActivityContent
                    } else {
                        editActivityContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .disabled(isSaving)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.ground)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .safeAreaInset(edge: .bottom, spacing: 0) { reviewButton }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Field.self) { field in
                switch field {
                case .location:
                    TextEntryView(title: "Where", prompt: "Address or place", text: $draft.location)
                case .notes:
                    TextEntryView(title: "Notes", prompt: "Booking reference, reminders",
                                  text: $draft.notes, multiline: true)
                }
            }
        }
        .tint(Theme.forest)
        .interactiveDismissDisabled(isSaving)
        .sheet(isPresented: $editingTime) {
            TimeSheet(start: $draft.start, end: $draft.end)
        }
        .confirmationDialog("Delete this activity?", isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        } message: {
            Text("This can’t be undone.")
        }
        .alert(failure?.title ?? "", isPresented: Binding(
            get: { failure != nil }, set: { if !$0 { failure = nil } }
        )) {
            Button("OK", role: .cancel) { failure = nil }
        } message: {
            Text(failure?.message ?? "")
        }
    }

    // MARK: - Layouts

    // 03 Add activity
    @ViewBuilder private var newActivityContent: some View {
        timeChip
        suggestionsRow
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: "Type")
            typeTiles
        }
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: "Details")
            RowGroup {
                nameRow
                whereRow
                templateRows
                NavigationLink(value: Field.notes) {
                    DetailRow("Notes", value: notesPreview, valueColor: valueColor(draft.notes),
                              showsChevron: true)
                }
                .buttonStyle(RowButtonStyle())
            }
        }
        // Forks are not part of this prototype, so new activities go to the main plan
        RowGroup {
            DetailRow("Add to", value: "Main plan", showsChevron: true)
        }
    }

    // 07 Edit activity
    @ViewBuilder private var editActivityContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: "Details")
            RowGroup {
                nameRow
                timeRow("Starts", draft.start, changed: differs(draft.start, original.start))
                timeRow("Ends", draft.end, changed: differs(draft.end, original.end))
                whereRow
                templateRows
            }
            if let note = timeChangeNote {
                Label(note, systemImage: "clock")
                    .font(.metaMedium)
                    .foregroundStyle(Theme.amberText)
                    .labelStyle(CompactLabelStyle())
            }
        }
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: "Notes")
            TextField("Add notes", text: $draft.notes, axis: .vertical)
                .font(.bodyRegular)
                .foregroundStyle(Theme.ink)
                .lineLimit(2...8)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .stCard()
        }
        if onDelete != nil {
            Button("Delete activity", role: .destructive) { confirmDelete = true }
                .buttonStyle(TextButtonStyle(color: Theme.danger))
        }
    }

    // MARK: - Pieces

    private var header: some View {
        ZStack {
            Text(isNew ? "New activity" : "Edit activity")
                .font(.navTitle)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.bodyMedium)
                    .foregroundStyle(Theme.forest)
                    .frame(minWidth: 72, minHeight: 44, alignment: .leading)
                    .disabled(isSaving)
                Spacer()
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }

    private var reviewButton: some View {
        Button(isSaving ? "Saving…" : "Review", action: review)
            .buttonStyle(PillButtonStyle(filled: true))
            .disabled(!isValid || isSaving)
            .opacity(isValid && !isSaving ? 1 : 0.4)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .background(Theme.ground)
    }

    // Pre-filled time slot; tap to change it
    private var timeChip: some View {
        Button { editingTime = true } label: {
            Label(timeSlotText, systemImage: "clock")
                .font(.callout15)
                .foregroundStyle(Theme.forest)
                .labelStyle(CompactLabelStyle(spacing: 8))
                .padding(.leading, 14)
                .padding(.trailing, 16)
                .frame(height: 44)
                .background(Theme.tint, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Change the date and time")
    }

    private var suggestionsRow: some View {
        Button {
            // Opens 04 Suggestions once that screen is built
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Get suggestions")
                        .font(.bodyEmphasis)
                        .foregroundStyle(Theme.ink)
                    Text("Ideas for this time slot")
                        .font(.meta)
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 16)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
            .stCard()
        }
        .buttonStyle(.plain)
    }

    private var typeTiles: some View {
        HStack(spacing: 8) {
            ForEach(Self.tileOrder) { type in
                TypeTile(type: type, isSelected: draft.type == type) {
                    draft.type = type
                }
            }
        }
    }

    private var nameRow: some View {
        DetailRow(label: "Name") {
            TextField("Required", text: $draft.title)
                .font(.bodyRegular)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
        }
    }

    private var whereRow: some View {
        NavigationLink(value: Field.location) {
            DetailRow("Where", value: draft.location.isEmpty ? "Add place" : draft.location,
                      valueColor: valueColor(draft.location), showsChevron: true)
        }
        .buttonStyle(RowButtonStyle())
    }

    // Extra fields from the selected type's template, e.g. Flight number
    private var templateRows: some View {
        ForEach(draft.type.fields, id: \.self) { field in
            DetailRow(label: field) {
                TextField("Optional", text: detailBinding(field))
                    .font(.bodyRegular)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
            }
        }
    }

    private func timeRow(_ label: String, _ date: Date, changed: Bool) -> some View {
        Button { editingTime = true } label: {
            DetailRow(label, value: timeText(date),
                      valueColor: changed ? Theme.amberText : Theme.ink,
                      emphasized: changed, showsChevron: true)
        }
        .buttonStyle(RowButtonStyle())
    }

    // MARK: - Actions

    private func review() {
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                try await onSave(cleaned)
                dismiss()
            } catch {
                failure = Failure(title: "Couldn’t save activity", message: error.localizedDescription)
            }
        }
    }

    private func delete() {
        guard let onDelete else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                try await onDelete()
                dismiss()
            } catch {
                failure = Failure(title: "Couldn’t delete activity", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

    private static let tileOrder: [ActivityType] = [.food, .custom, .flight, .transport, .hotel]

    private var isValid: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.title.count <= 200 && draft.notes.count <= 5000
            && draft.end >= draft.start
    }

    // Trim text and drop empty fields or ones left over from a previously selected type
    private var cleaned: Activity {
        var activity = draft
        activity.title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let kept = Set(activity.type.fields + [Activity.locationKey])
        activity.details = activity.details
            .mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { kept.contains($0.key) && !$0.value.isEmpty }
        return activity
    }

    private func detailBinding(_ field: String) -> Binding<String> {
        Binding(
            get: { draft.details[field, default: ""] },
            set: { draft.details[field] = $0 }
        )
    }

    private var notesPreview: String {
        let firstLine = draft.notes.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Add" : firstLine
    }

    private func valueColor(_ text: String) -> Color {
        text.isEmpty ? Theme.muted : Theme.ink
    }

    // e.g. "Sat, Jun 13 · 2:00 – 4:00 PM"
    private var timeSlotText: String {
        let calendar = Calendar.current
        if calendar.isDate(draft.start, inSameDayAs: draft.end) {
            let day = draft.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            return "\(day) · \(Self.timeRange(draft.start, draft.end))"
        }
        return (draft.start..<max(draft.end, draft.start))
            .formatted(.interval.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    // Time only, plus the date if it moved to another day
    private func timeText(_ date: Date) -> String {
        if Calendar.current.isDate(date, inSameDayAs: original.start) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    // e.g. "Moved 30 min later (was 12:30 – 1:30 PM)"
    private var timeChangeNote: String? {
        guard differs(draft.start, original.start) || differs(draft.end, original.end) else { return nil }
        let was = Self.timeRange(original.start, original.end)
        let shift = draft.start.timeIntervalSince(original.start)
        let sameLength = !differs(draft.end.addingTimeInterval(-shift), original.end)
        if sameLength {
            let amount = Duration.seconds(abs(shift))
                .formatted(.units(allowed: [.days, .hours, .minutes], width: .abbreviated))
            return "Moved \(amount) \(shift > 0 ? "later" : "earlier") (was \(was))"
        }
        return "Time changed (was \(was))"
    }

    // Ignores differences under a minute
    private func differs(_ a: Date, _ b: Date) -> Bool {
        abs(a.timeIntervalSince(b)) >= 60
    }

    // e.g. "2:00 – 4:00 PM"; AM/PM is shown once when both times share it
    private static func timeRange(_ start: Date, _ end: Date) -> String {
        let calendar = Calendar.current
        let samePeriod = calendar.isDate(start, inSameDayAs: end)
            && (calendar.component(.hour, from: start) < 12) == (calendar.component(.hour, from: end) < 12)
        let startText = samePeriod
            ? start.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
            : start.formatted(date: .omitted, time: .shortened)
        return "\(startText) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    private enum Field: Hashable {
        case location, notes
    }

    private struct Failure {
        let title: String
        let message: String
    }
}

// MARK: - Type tile

private struct TypeTile: View {
    let type: ActivityType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)
                Text(type.label)
                    .font(isSelected ? .labelCaps : .tileLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.forest)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface).cardShadow()
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// Icon and text with a set gap
private struct CompactLabelStyle: LabelStyle {
    var spacing: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - Time sheet

private struct TimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var start: Date
    @Binding var end: Date

    var body: some View {
        NavigationStack {
            VStack {
                RowGroup {
                    DetailRow(label: "Starts") {
                        DatePicker("Starts", selection: startKeepingLength)
                            .labelsHidden()
                    }
                    DetailRow(label: "Ends") {
                        DatePicker("Ends", selection: $end, in: start...)
                            .labelsHidden()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Theme.ground)
            .navigationTitle("Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.forest)
        .presentationDetents([.height(250)])
    }

    // Moving the start moves the end too, keeping the same length
    private var startKeepingLength: Binding<Date> {
        Binding(
            get: { start },
            set: { newStart in
                let length = max(end.timeIntervalSince(start), 0)
                start = newStart
                end = newStart.addingTimeInterval(length)
            }
        )
    }
}

// MARK: - Text entry

// Pushed screen for a longer value such as Where or Notes
private struct TextEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let prompt: String
    @Binding var text: String
    var multiline = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            Group {
                if multiline {
                    TextField(prompt, text: $text, axis: .vertical)
                        .lineLimit(4...12)
                } else {
                    TextField(prompt, text: $text)
                        .submitLabel(.done)
                        .onSubmit { dismiss() }
                }
            }
            .font(.bodyRegular)
            .foregroundStyle(Theme.ink)
            .focused($isFocused)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .stCard()
            .padding(20)
        }
        .background(Theme.ground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { isFocused = true }
    }
}

#Preview("New") {
    ActivityFormView(activity: .blank(), isNew: true) { _ in }
}

#Preview("Edit") {
    ActivityFormView(activity: Activity.samples[2], isNew: false) { _ in } onDelete: {}
}
