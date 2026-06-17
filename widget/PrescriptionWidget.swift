import WidgetKit
import SwiftUI

// Widget configuration. The content view (PrescriptionWidgetView) lives in Shared.
struct PrescriptionWidget: Widget {
    let kind = "PrescriptionWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PrescriptionSelectionIntent.self,
            provider: WidgetProvider()
        ) { entry in
            PrescriptionWidgetView(entry: entry)
                .fontDesign(.serif)
                .containerBackground(Theme.background, for: .widget)
        }
        .configurationDisplayName("Doses")
        .description("Track and check off your doses.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
