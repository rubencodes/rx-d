import SwiftUI

extension DoseStatus {
    var themeColor: Color {
        switch self {
        case .pending: Theme.pending
        case .taken:   Theme.taken
        case .snoozed: Theme.snoozed
        case .missed:  Theme.missed
        }
    }

    var iconName: String {
        switch self {
        case .pending: "hourglass"
        case .taken:   "checkmark"
        case .snoozed: "zzz"
        case .missed:  "exclamationmark"
        }
    }

    // Rubber-stamp wording
    var stampLabel: String {
        switch self {
        case .pending: "DUE"
        case .taken:   "TAKEN"
        case .snoozed: "SNOOZED"
        case .missed:  "MISSED"
        }
    }
}
