import Foundation

enum Frequency: Equatable {
    case daily
    case weekly(days: Set<Weekday>)
}
