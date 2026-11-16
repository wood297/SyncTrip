/*
 Bottom menu bar (Figma: tab bar on 01 Trips / 02 Day plan)
 Floating white capsule with Trips, Plan, Map, Votes, and Settings.
 Selecting an item switches the current page. Only Plan and Votes have
 screens so far; the other items are shown but disabled.
 Item order, labels, icons, and availability live in Models/Page.swift.
 */
import SwiftUI

struct MenuBar: View {
    @Binding var page: Page
    var votesBadge = 0   // activities waiting for approval (Figma 09 badge)

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Page.allCases, id: \.self) { item in
                MenuBarItem(page: item, selected: page == item,
                            badge: item == .votes ? votesBadge : 0) {
                    page.select(item)
                }
                .disabled(!item.isAvailable)
            }
        }
        .padding(6)
        .background(Theme.surface, in: Capsule())
        .shadow(color: Theme.shadow, radius: 7, x: 0, y: 4)
        .shadow(color: Theme.shadow, radius: 1, x: 0, y: 1)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

// One item: icon over label, with a light green pill when selected
private struct MenuBarItem: View {
    let page: Page
    let selected: Bool
    var badge = 0
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: page.icon)
                    .font(.system(size: 18, weight: .regular))
                    .frame(height: 22)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text("\(badge)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Theme.amberText, in: Capsule())
                                .offset(x: 12, y: -8)
                        }
                    }
                Text(page.label)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Theme.ink : Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(selected ? Theme.tint : Color.clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(MenuBarButtonStyle())
        .accessibilityLabel(badge > 0 ? "\(page.label), \(badge) waiting for approval" : page.label)
        .accessibilityHint(page.isAvailable ? "" : "Coming soon")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// Keeps disabled items looking like the Figma bar; dims briefly when pressed
private struct MenuBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview {
    @Previewable @State var page: Page = .plan
    VStack {
        Spacer()
        MenuBar(page: $page)
    }
    .background(Theme.ground)
}
