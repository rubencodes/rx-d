import Foundation

struct CalendarDay: Identifiable {
    let date: Date
    let total: Int
    let taken: Int
    var id: Date { date }
    var adherence: DayAdherence { DayAdherence(total: total, taken: taken) }
}
