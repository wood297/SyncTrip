/*
 Vote models (static sample data for the prototype)
 An open vote is a proposed change to the main plan that members approve or reject.
 A decided vote is one that already passed or failed.
 Nothing here talks to the backend yet.
 */

import Foundation

enum VoteChoice: Equatable {
    case yes, no
}

struct OpenVote: Identifiable {
    let id = UUID()
    var kind: String            // e.g. "Add to main plan"
    var title: String           // e.g. "Sky Lagoon"
    var summary: String         // e.g. "Sat, Jun 13 · 2:00 – 4:00 PM · Kópavogur"
    var proposedBy: String      // first name
    var yes: Int
    var no: Int
    var eligible: Int           // members allowed to vote
    var passThreshold: Double   // fraction of eligible members, e.g. 0.6
    var closesAt: Date
    var myChoice: VoteChoice?

    var waiting: Int { max(eligible - yes - no, 0) }

    var yesFraction: Double {
        eligible == 0 ? 0 : Double(yes) / Double(eligible)
    }

    // e.g. "3h 20m left"
    func timeLeft(from now: Date = .now) -> String {
        let minutes = max(Int(closesAt.timeIntervalSince(now) / 60), 0)
        if minutes == 0 { return "Closing" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m left" }
        return m == 0 ? "\(h)h left" : "\(h)h \(m)m left"
    }

    // Records this member's vote, replacing any earlier vote
    mutating func cast(_ choice: VoteChoice) {
        guard myChoice != choice else { return }
        switch myChoice {
        case .yes: yes -= 1
        case .no: no -= 1
        case nil: break
        }
        switch choice {
        case .yes: yes += 1
        case .no: no += 1
        }
        myChoice = choice
    }
}

struct DecidedVote: Identifiable {
    let id = UUID()
    var title: String
    var passed: Bool
    var detail: String          // e.g. "Approved by a Leader · today"
}

extension OpenVote {
    static var samples: [OpenVote] {
        [
            OpenVote(kind: "Add to main plan",
                     title: "Sky Lagoon",
                     summary: "Sat, Jun 13 · 2:00 – 4:00 PM · Kópavogur",
                     proposedBy: "Maya",
                     yes: 2, no: 0, eligible: 5,
                     passThreshold: 0.6,
                     closesAt: Date.now.addingTimeInterval(200 * 60))
        ]
    }
}

extension DecidedVote {
    static var samples: [DecidedVote] {
        [
            DecidedVote(title: "Move Bæjarins Beztu to 1:00 PM", passed: true,
                        detail: "Approved by a Leader · today"),
            DecidedVote(title: "Add a Golden Circle tour", passed: false,
                        detail: "Didn’t pass · 1 yes, 3 no · yesterday")
        ]
    }
}
