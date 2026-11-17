/*
 Review & save (Figma: 05 Review & save)
 Opens from Review on the add (03) or edit (07) form. Shows the activity as it
 will look in the Day plan, says that a Traveller's change to the main plan
 needs approval, and lists the trip's vote rules.

 Save and send saves it as waiting for approval; the Day plan then shows it as
 pending (Figma 09). The app has no roles yet, so like the Figma prototype it
 always takes the Traveller path. The grey "saves right away" line saves it as
 approved instead, as a Leader would (Figma 08). The vote rules are fixed
 values until trip settings (Figma 17) exist.
 */

import SwiftUI

struct ReviewSaveView: View {
    @Environment(\.dismiss) private var dismiss
    let activity: Activity
    let isNew: Bool
    // Saves the activity; the caller closes the form when it succeeds
    let onSave: (Activity) async throws -> Void

    @State private var isSaving = false
    @State private var failure: String?

    // Votes stay open this long (Figma 17 Trip settings: time limit 4 hours)
    private static let voteWindow: TimeInterval = 4 * 3600

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                preview
                approvalAlert
                voteRules
                Button("On your fork, or as a Leader, this saves right away.") {
                    save(pending: false)
                }
                .font(.meta)
                .foregroundStyle(Theme.muted)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityHint("Saves now without approval")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .disabled(isSaving)
        }
        .scrollIndicators(.hidden)
        .background(Theme.ground)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { sendButton }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .alert("Couldn’t save activity", isPresented: Binding(
            get: { failure != nil }, set: { if !$0 { failure = nil } }
        )) {
            Button("OK", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    // MARK: - Parts

    private var header: some View {
        ZStack {
            Text("Review")
                .font(.navTitle)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button("Back") { dismiss() }
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

    // The row as the Day plan will show it
    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: "How it will look")
            TimelineActivityRow(activity: activity)
        }
    }

    private var approvalAlert: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.amberText)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Needs approval")
                    .font(.callout15)
                Text("You’re a Traveller \(isNew ? "adding to" : "changing") the main plan. Leaders can approve it or open a vote.")
                    .font(.bodySmall)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.amberTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var voteRules: some View {
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: "If a vote opens")
            RowGroup {
                DetailRow("Who votes", value: "Leaders and Travellers")
                DetailRow("Passes at", value: "60% yes")
                DetailRow("Closes", value: closesText)
            }
        }
    }

    private var sendButton: some View {
        Button(isSaving ? "Saving…" : "Save and send") { save(pending: true) }
            .buttonStyle(PillButtonStyle(filled: true))
            .disabled(isSaving)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .background(Theme.ground)
    }

    // e.g. "6:00 PM today"
    private var closesText: String {
        let closes = Date.now.addingTimeInterval(Self.voteWindow)
        let time = closes.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        if calendar.isDateInToday(closes) { return "\(time) today" }
        if calendar.isDateInTomorrow(closes) { return "\(time) tomorrow" }
        return closes.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    // MARK: - Saving

    private func save(pending: Bool) {
        var result = activity
        result.isPending = pending
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                try await onSave(result)
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReviewSaveView(activity: Activity.samples[3], isNew: true) { _ in }
    }
}
