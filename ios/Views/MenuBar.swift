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

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Page.allCases, id: \.self) { item in
                MenuBarItem(page: item, selected: page == item) {
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
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: page.icon)
                    .font(.system(size: 18, weight: .regular))
                    .frame(height: 22)
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
        .accessibilityLabel(page.label)
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

// MARK: - Hiding the bar on detail pages

extension EnvironmentValues {
    // RootView hides the bar while this is true (see hidesMenuBar())
    @Entry var menuBarHidden: Binding<Bool> = .constant(false)
}

extension View {
    // Hides the menu bar while this page is on screen, the way iOS hides
    // a tab bar on pushed detail pages (Figma 06 has no bar)
    func hidesMenuBar() -> some View {
        modifier(HidesMenuBar())
    }
}

private struct HidesMenuBar: ViewModifier {
    @Environment(\.menuBarHidden) private var hidden

    func body(content: Content) -> some View {
        content
            .onAppear { hidden.wrappedValue = true }
            .onDisappear { hidden.wrappedValue = false }
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
