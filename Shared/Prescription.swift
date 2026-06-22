import Foundation
import SwiftData

@Model
final class Prescription {
    // Inline default values on every stored property keep the schema CloudKit-compatible.
    var id: UUID = UUID()
    var name: String = ""
    var scheduledTime: Date = Date()
    // Frequency stored as flat fields (SwiftData can't store associated-value enums)
    var frequencyType: String = "daily" // "daily" | "weekly"
    var weeklyDays: [Int] = [] // empty for daily; Weekday.rawValue ints for weekly
    var color: String = "#5B8DEF" // hex string e.g. "#FF6B6B"
    var notes: String?
    var isArchived: Bool = false
    var archivedAt: Date?
    var createdAt: Date = Date()
    var followUpInterval: TimeInterval = 7200 // seconds; default 2hr
    // When true, the follow-up reminder repeats every `followUpInterval` (a capped
    // series of nudges) until the dose is acted on, instead of firing just once.
    var repeatRemindersUntilDone: Bool = false
    // When true, reminders use the .timeSensitive interruption level so they break
    // through Focus / Do Not Disturb (not the hardware silent switch — that needs the
    // Critical Alerts entitlement). Requires the Time Sensitive Notifications capability.
    var timeSensitive: Bool = true
    // Set when imported from Apple Health: a base64 NSSecureCoding archive of the
    // HKHealthConceptIdentifier, used to match incoming HKMedicationDoseEvents.
    var healthConceptID: String?

    init(
        name: String,
        scheduledTime: Date,
        frequency: Frequency = .daily,
        color: String = "#5B8DEF",
        notes: String? = nil,
        followUpInterval: TimeInterval = 7200,
        repeatRemindersUntilDone: Bool = false,
        timeSensitive: Bool = true
    ) {
        id = UUID()
        self.name = name
        self.scheduledTime = scheduledTime
        self.color = color
        self.notes = notes
        isArchived = false
        archivedAt = nil
        createdAt = Date()
        self.followUpInterval = followUpInterval
        self.repeatRemindersUntilDone = repeatRemindersUntilDone
        self.timeSensitive = timeSensitive
        switch frequency {
        case .daily:
            frequencyType = "daily"
            weeklyDays = []
        case let .weekly(days):
            frequencyType = "weekly"
            weeklyDays = days.map(\.rawValue).sorted()
        }
    }

    var frequency: Frequency {
        get {
            if frequencyType == "weekly" {
                let days = Set(weeklyDays.compactMap { Weekday(rawValue: $0) })
                return .weekly(days: days)
            }
            return .daily
        }
        set {
            switch newValue {
            case .daily:
                frequencyType = "daily"
                weeklyDays = []
            case let .weekly(days):
                frequencyType = "weekly"
                weeklyDays = days.map(\.rawValue).sorted()
            }
        }
    }
}
