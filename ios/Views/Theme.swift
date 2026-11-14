/*
 SyncTrip design tokens
 Colors and small shared pieces taken from the Figma "Final Design" page
 (--st-* variables), so every screen uses the same palette.
 */

import SwiftUI

enum Theme {
    // Backgrounds
    static let ground = Color(hex: 0xF3F4EF)      // --st-bg-ground (page background)
    static let surface = Color.white               // --st-bg-surface (cards)
    static let tint = Color(hex: 0xE3EADC)        // --st-bg-tint (light green)
    static let segment = Color(hex: 0xE7E9E3)     // --st-bg-segment (grey chip / bar track)

    // Text
    static let ink = Color(hex: 0x1A1F26)         // --st-text-ink
    static let muted = Color(hex: 0x5B6258)       // --st-text-muted

    // Accents
    static let forest = Color(hex: 0x2B3E2D)      // --st-accent-forest (primary)
    static let forkViolet = Color(hex: 0x5B4B8A)  // --st-fork-violet
    static let amberTint = Color(hex: 0xFBF3E3)   // --st-alert-amber-tint
    static let amberText = Color(hex: 0x8A5A12)   // --st-alert-amber-text
    static let line = Color(hex: 0xE3E5DF)        // --st-line-hair
    static let sage = Color(hex: 0x8FA382)        // --st-accent-sage (free slot border)
    static let unread = Color(hex: 0xD99A2B)      // unread chat dot

    // Avatar fills
    static let avatarGreen = Color(hex: 0xDDEAD6)
    static let avatarSand = Color(hex: 0xF6E8CC)
    static let avatarLilac = Color(hex: 0xE8E0F6)
    static let avatarPink = Color(hex: 0xF6DBDB)
    static let avatarBlue = Color(hex: 0xD9E5F6)

    // Card shadow (rgba(26,31,26,0.05))
    static let shadow = Color(red: 26 / 255, green: 31 / 255, blue: 26 / 255).opacity(0.05)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// White rounded card with the soft two-layer shadow used across the design
struct CardStyle: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Theme.shadow, radius: 7, x: 0, y: 4)
            .shadow(color: Theme.shadow, radius: 1, x: 0, y: 1)
    }
}

extension View {
    func stCard(radius: CGFloat = 16) -> some View {
        modifier(CardStyle(radius: radius))
    }
}

// Full-width 52 pt pill button. Filled = dark green, otherwise white with green text.
struct PillButtonStyle: ButtonStyle {
    var filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(filled ? Color.white : Theme.forest)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(filled ? Theme.forest : Theme.surface, in: Capsule())
            .shadow(color: filled ? .clear : Theme.shadow, radius: 4, x: 0, y: 4)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// Small all-caps section label, e.g. "NOTES"
struct CapsLabel: View {
    let text: String
    var color: Color = Theme.muted

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.72)
            .foregroundStyle(color)
    }
}

// Round initial badge for a trip member
struct AvatarView: View {
    let initial: String
    let color: Color
    var size: CGFloat = 28
    var border: Color = Theme.surface

    var body: some View {
        Text(initial)
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.24)
            .foregroundStyle(Theme.ink)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .overlay(Circle().stroke(border, lineWidth: 2))
    }
}

// 44 pt white circle holding an icon (back / more buttons)
struct CircleIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: 44, height: 44)
            .background(Theme.surface, in: Circle())
            .shadow(color: Theme.shadow, radius: 7, x: 0, y: 4)
            .shadow(color: Theme.shadow, radius: 1, x: 0, y: 1)
    }
}

// Thin divider inside a card, inset from the left
struct HairlineDivider: View {
    var leading: CGFloat = 16

    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1)
            .padding(.leading, leading)
    }
}
