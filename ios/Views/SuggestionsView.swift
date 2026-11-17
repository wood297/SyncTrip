/*
 Suggestions (Figma: 04 Suggestions)
 Sheet opened from "Get suggestions" on the new activity form. Shows three
 ideas at a time; "Show different ideas" moves to the next three, and "Use"
 fills the form with that idea and closes the sheet.

 Prototype: ideas come from a fixed list (Suggestion.presets), not from the
 trip or place, so the note under the title says so instead of "Suggested by AI".
 */

import SwiftUI

struct SuggestionsView: View {
    @Environment(\.dismiss) private var dismiss
    let start: Date
    let end: Date
    let onUse: (Suggestion) -> Void

    @State private var page = 0

    private var slotMinutes: Int {
        max(Int(end.timeIntervalSince(start) / 60), 0)
    }

    private var ideas: [Suggestion] {
        Suggestion.page(page, forSlotMinutes: slotMinutes)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                note
                ForEach(ideas) { idea in
                    IdeaCard(idea: idea) {
                        onUse(idea)
                        dismiss()
                    }
                }
                Button("Show different ideas") {
                    withAnimation(.easeInOut(duration: 0.2)) { page += 1 }
                }
                .buttonStyle(TextButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
        .background(Theme.ground)
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Theme.ground)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Ideas for \(Activity.compactRange(from: start, to: end))")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.33)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Theme.segment, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            Text("General ideas that fit most trips. Check hours and prices before you go.")
                .font(.meta)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// One idea: name, type and length, a short description, and a Use button
private struct IdeaCard: View {
    let idea: Suggestion
    let onUse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(idea.title)
                        .font(.bodyEmphasis)
                        .tracking(-0.08)
                        .foregroundStyle(Theme.ink)
                    Text(idea.metaText)
                        .font(.meta)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Use", action: onUse)
                    .font(.callout15)
                    .foregroundStyle(Theme.forest)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(Theme.tint, in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(idea.title)")
            }
            Text(idea.blurb)
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .stCard()
    }
}

#Preview("04 Suggestions") {
    let start = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: .now)!
    Color.clear.sheet(isPresented: .constant(true)) {
        SuggestionsView(start: start, end: start.addingTimeInterval(2 * 3600)) { _ in }
    }
}
