import WidgetKit
import SwiftUI

@main
struct widgetBundle: WidgetBundle {
    var body: some Widget {
        PrescriptionWidget()
        CalendarWidget()
        LockScreenWidget()
        NextDoseControl()
    }
}
