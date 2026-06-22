import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query private var allLogs: [DoseLog]
    @Query private var allPrescriptions: [Prescription]

    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationStack {
            CalendarView(
                displayedMonth: $displayedMonth,
                allLogs: allLogs,
                allPrescriptions: allPrescriptions
            )
            .frame(maxWidth: .layoutWide)
            .frame(maxWidth: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Today") {
                        displayedMonth = Calendar.current.startOfDay(for: Date())
                    }
                }
            }
        }
    }
}
