import SwiftUI
import WidgetKit

struct CalendarWidget: Widget {
    let kind = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            CalendarWidgetView(entry: entry)
                .containerBackground(Theme.background, for: .widget)
        }
        .configurationDisplayName("Adherence Calendar")
        .description("This month's doses at a glance.")
        .supportedFamilies([.systemLarge])
    }
}
