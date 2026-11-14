/*
 Votes (Figma: 23 Votes · open and 24 Votes · none open)
 Lists open votes on proposed changes and the ones already decided.
 With no open votes it shows the empty state instead.

 Static prototype: uses sample data. Tapping Yes/No updates the counts on
 screen only; nothing is saved or sent to the backend yet.
 */

import SwiftUI

struct VotesView: View {
    var tripName: String = "Iceland Ring Road"
    @State var openVotes: [OpenVote] = OpenVote.samples
    var decided: [DecidedVote] = DecidedVote.samples
    // Opens the app's side menu; the ☰ button is hidden when nil (e.g. previews)
    var onMenu: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The navigation bar is hidden, so the side-menu button lives here
                if let onMenu {
                    Button(action: onMenu) {
                        CircleIcon(systemName: "line.3.horizontal")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Menu")
                    .padding(.bottom, 12)
                }

                header
                    .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: openVotes.isEmpty ? 18 : 14) {
                    if openVotes.isEmpty {
                        emptyState
                    } else {
                        openBanner
                        ForEach($openVotes) { $vote in
                            OpenVoteCard(vote: $vote)
                        }
                    }

                    if !decided.isEmpty {
                        decidedSection
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.ground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Votes")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(tripName)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
        }
    }

    // Amber "1 vote open" alert
    private var openBanner: some View {
        let count = openVotes.count
        let firstClose = openVotes.map(\.closesAt).min() ?? .now
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.amberText)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) vote\(count == 1 ? "" : "s") open")
                    .font(.system(size: 15, weight: .semibold))
                Text("Closes at \(firstClose.formatted(date: .omitted, time: .shortened)). Your vote counts.")
                    .font(.system(size: 14))
                    .lineSpacing(3)
            }
            .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.amberTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // 24 Votes · none open
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            Text("No open votes")
                .font(.system(size: 16, weight: .semibold))
                .tracking(-0.08)
                .foregroundStyle(Theme.ink)
            Text("When someone proposes a change to the main plan, it will show up here.")
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 26)
        .stCard(radius: 20)
    }

    private var decidedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: "Decided")
            VStack(spacing: 0) {
                ForEach(Array(decided.enumerated()), id: \.element.id) { index, vote in
                    if index > 0 { HairlineDivider(leading: 48) }
                    DecidedRow(vote: vote)
                }
            }
            .stCard()
        }
    }
}

// One open vote: proposal, result bar, counts, Yes/No buttons
private struct OpenVoteCard: View {
    @Binding var vote: OpenVote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                CapsLabel(text: vote.kind, color: Theme.amberText)
                Text(vote.title)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.44)
                    .foregroundStyle(Theme.ink)
                Text(vote.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                HStack(spacing: 8) {
                    AvatarView(initial: String(vote.proposedBy.prefix(1)),
                               color: Theme.avatarGreen, size: 22, border: Theme.ground)
                        .accessibilityHidden(true)
                    Text("Proposed by \(vote.proposedBy)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                }
            }

            ResultBar(fraction: vote.yesFraction, threshold: vote.passThreshold)
                .accessibilityLabel("\(vote.yes) of \(vote.eligible) voted yes. Needs \(Int(vote.passThreshold * 100)) percent.")

            HStack {
                Text("\(vote.yes) yes · \(vote.no) no · \(vote.waiting) waiting")
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("Needs \(Int(vote.passThreshold * 100))% · \(vote.timeLeft())")
                    .foregroundStyle(Theme.muted)
            }
            .font(.system(size: 13))
            .lineLimit(1)
            .minimumScaleFactor(0.85)

            HStack(spacing: 10) {
                // The highlighted button follows the member's choice (Yes by default)
                Button(vote.myChoice == .yes ? "Voted yes" : "Yes, add it") { vote.cast(.yes) }
                    .buttonStyle(PillButtonStyle(filled: vote.myChoice != .no))
                Button(vote.myChoice == .no ? "Voted no" : "No") { vote.cast(.no) }
                    .buttonStyle(PillButtonStyle(filled: vote.myChoice == .no))
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 1)
                Text("View-only members see results but can’t vote. Leaders can also approve it directly.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .stCard(radius: 20)
    }
}

// Track with the yes share filled and a tick at the pass threshold
private struct ResultBar: View {
    let fraction: Double
    let threshold: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Theme.segment
                Rectangle()
                    .fill(Theme.forest)
                    .frame(width: w * min(max(fraction, 0), 1))
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: 2)
                    .offset(x: w * threshold - 1)
            }
            .animation(.easeOut(duration: 0.2), value: fraction)
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct DecidedRow: View {
    let vote: DecidedVote

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: vote.passed ? "checkmark" : "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(vote.passed ? Color(hex: 0x3F8A4A) : Theme.muted)
                .frame(width: 18, height: 18)
                .accessibilityLabel(vote.passed ? "Passed" : "Didn’t pass")
            VStack(alignment: .leading, spacing: 2) {
                Text(vote.title)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                Text(vote.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

#Preview("23 Votes · open") {
    NavigationStack { VotesView() }
}

#Preview("24 Votes · none open") {
    NavigationStack { VotesView(openVotes: []) }
}
