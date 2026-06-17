import Foundation

enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    // Maps Calendar.component(.weekday) values (1=Sun…7=Sat) to this enum
    init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday)
    }
}
