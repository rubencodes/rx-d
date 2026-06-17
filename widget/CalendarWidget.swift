import WidgetKit
import SwiftUI

struct CalendarWidget: Widget {
    let kind = "CalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { entry in
            CalendarWidgetView(entry: entry)
                .fontDesign(.serif)
                .containerBackground(Theme.background, for: .widget)
        }
        .configurationDisplayName("Adherence Calendar")
        .description("This month's doses at a glance.")
        .supportedFamilies([.systemLarge])
    }
}
