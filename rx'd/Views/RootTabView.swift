import SwiftUI

struct RootTabView: View {
    @State private var selection = initialSelection()

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "pill.fill", value: 0) {
                TodayView()
            }
            Tab("Schedule", systemImage: "calendar", value: 1) {
                ScheduleView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: 2) {
                HistoryView()
            }
            Tab("Health", systemImage: "heart.text.square", value: 3) {
                HealthView()
            }
            Tab("Settings", systemImage: "gear", value: 4) {
                SettingsView()
            }
        }
        .tint(Theme.accent)
        .fontDesign(.rounded)
    }

    private static func initialSelection() -> Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--tab"), i + 1 < args.count {
            switch args[i + 1] {
            case "schedule": return 1
            case "history": return 2
            case "health": return 3
            case "settings": return 4
            default: return 0
            }
        }
        #endif
        return 0
    }
}
