import SwiftUI
import WidgetKit

@main
struct widgetBundle: WidgetBundle {
    var body: some Widget {
        PrescriptionWidget()
        CalendarWidget()
        LockScreenWidget()
        NextDoseControl()
    }
}
