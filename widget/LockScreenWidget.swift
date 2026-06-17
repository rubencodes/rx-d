import WidgetKit
import SwiftUI

// Widget configuration. The content view (LockScreenWidgetView) lives in Shared.
struct LockScreenWidget: Widget {
    let kind = "LockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PrescriptionSelectionIntent.self,
            provider: WidgetProvider()
        ) { entry in
            LockScreenWidgetView(entry: entry)
                .fontDesign(.serif)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Dose Status")
        .description("See your next dose at a glance.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
