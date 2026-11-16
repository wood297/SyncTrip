/*
 Shared rows, text buttons and text styles for form-style screens
 (Figma 03 Add activity, 06 Activity details, 07 Edit activity, 05 Review & save).
 Colours, cards, pill buttons and caps labels are in Theme.swift.
 */

import SwiftUI

extension Theme {
    static let danger = Color(hex: 0xB3261E)     // --st-status-danger
    static let onAccent = Color(hex: 0xFFFFFF)   // --st-text-on-accent
}

// Text styles from the Figma file, set in the system font
extension Font {
    static let titleLarge = Font.system(size: 30, weight: .bold)   // use with .tracking(-0.6)
    static let navTitle = Font.system(size: 17, weight: .semibold)
    static let buttonLabel = Font.system(size: 17, weight: .semibold)
    static let bodyEmphasis = Font.system(size: 16, weight: .semibold)
    static let bodyRegular = Font.system(size: 16)
    static let bodyMedium = Font.system(size: 16, weight: .medium)
    static let callout15 = Font.system(size: 15, weight: .semibold)
    static let meta = Font.system(size: 13)
    static let metaMedium = Font.system(size: 13, weight: .medium)
    static let labelCaps = Font.system(size: 12, weight: .semibold)
    static let tileLabel = Font.system(size: 12, weight: .medium)
}

extension View {
    // The card's two-layer shadow on its own, for shapes that set their own fill
    func cardShadow() -> some View {
        shadow(color: Theme.shadow, radius: 7, x: 0, y: 4)
            .shadow(color: Theme.shadow, radius: 1, x: 0, y: 1)
    }
}

// MARK: - Buttons

// 44 pt text-only button, e.g. "Delete activity" in danger red
struct TextButtonStyle: ButtonStyle {
    var color: Color = Theme.forest

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.buttonLabel)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// Highlights a tappable row while pressed
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(configuration.isPressed ? Theme.segment : .clear)
    }
}

// MARK: - Detail rows

// One row inside a RowGroup: muted label on the left, value on the right
struct DetailRow<Trailing: View>: View {
    let label: String
    var showsChevron = false
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.bodyRegular)
                .foregroundStyle(Theme.muted)
                .fixedSize()
            Spacer(minLength: 0)
            trailing
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .frame(minHeight: 44)
    }
}

extension DetailRow where Trailing == DetailValue {
    // Row with a plain text value
    init(_ label: String, value: String, valueColor: Color = Theme.ink,
         emphasized: Bool = false, showsChevron: Bool = false) {
        self.label = label
        self.showsChevron = showsChevron
        trailing = DetailValue(text: value, color: valueColor, emphasized: emphasized)
    }
}

struct DetailValue: View {
    let text: String
    var color: Color = Theme.ink
    var emphasized = false

    var body: some View {
        Text(text)
            .font(emphasized ? .bodyEmphasis : .bodyRegular)
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// White card that stacks rows with a hairline divider between them
struct RowGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(rows) { row in
                    if row.id != rows.first?.id {
                        HairlineDivider()
                    }
                    row
                }
            }
        }
        .frame(maxWidth: .infinity)
        .stCard()
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            CapsLabel(text: "Details")
            RowGroup {
                DetailRow("Name", value: "Sky Lagoon")
                DetailRow("Starts", value: "1:00 PM", valueColor: Theme.amberText,
                          emphasized: true, showsChevron: true)
                DetailRow("Where", value: "Kópavogur", showsChevron: true)
            }
            Button("Delete activity") {}
                .buttonStyle(TextButtonStyle(color: Theme.danger))
        }
        .padding(20)
    }
    .background(Theme.ground)
}
