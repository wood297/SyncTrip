/*
 Side menu that displays when hamburger button is pressed
 Selecting a row switches the current page and closes the menu
 */
import SwiftUI

struct SideMenu: View {
    // control var for if menu is open/closed (showing/not showing)
    @Binding var isShowing: Bool
    @Binding var page: Page

    var body: some View {
        ZStack(alignment: .leading) {
            // Dimmed background — tap to close
            if isShowing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { isShowing = false }
            }

            // The menu panel itself
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Menu")
                        .font(.title)
                        .bold()
                        .padding(.top, 60)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)

                    MenuRow(label: "Itinerary", icon: "calendar", selected: page == .itinerary) {
                        select(.itinerary)
                    }
                    MenuRow(label: "Time", icon: "clock.fill", selected: page == .time) {
                        select(.time)
                    }

                    Spacer()
                }
                // Menu frame
                .frame(width: 280)
                .frame(maxHeight: .infinity)
                .background(Color(.systemBackground))
                // No shadow while closed, so it doesn't show at the screen edge
                .shadow(radius: isShowing ? 8 : 0)
                .offset(x: isShowing ? 0 : -280)

                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isShowing)
        // Hide the closed menu from VoiceOver
        .accessibilityHidden(!isShowing)
    }

    private func select(_ newPage: Page) {
        page = newPage
        isShowing = false
    }
}

// Reusable row for each menu item
struct MenuRow: View {
    let label: String
    let icon: String
    let selected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(label)
                    .font(.body)
                    .fontWeight(selected ? .semibold : .regular)
                Spacer()
            }
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
