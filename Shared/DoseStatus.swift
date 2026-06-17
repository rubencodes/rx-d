import Foundation

enum DoseStatus: String, Codable {
    case pending, taken, snoozed, missed

    var label: String {
        switch self {
        case .pending: "Pending"
        case .taken: "Taken"
        case .snoozed: "Snoozed"
        case .missed: "Missed"
        }
    }
}
