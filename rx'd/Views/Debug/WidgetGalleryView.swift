#if DEBUG
    import SwiftUI
    import WidgetKit

    // DEBUG-only: renders the real widget content views at widget sizes so the design
    // can be screenshotted without placing the widget on a home screen.
    // Launch with `--widget-gallery`.
    struct WidgetGalleryView: View {
        private let now = Date()

        private func item(_ name: String, _ hex: String, _ offset: TimeInterval, _ status: DoseStatus) -> DoseItem {
            DoseItem(prescriptionId: UUID(), name: name, colorHex: hex,
                     scheduledDate: now.addingTimeInterval(offset), status: status)
        }

        private var listEntry: DoseEntry {
            DoseEntry(date: now, items: [
                item("Morning Vitamins", "#5B8DEF", -7200, .taken),
                item("Evening Magnesium", "#CC5DE8", 1800, .pending),
                item("Weekday Probiotic", "#20C997", 18000, .pending),
            ], streak: 5)
        }

        private var doneEntry: DoseEntry {
            DoseEntry(date: now, items: [
                item("Morning Vitamins", "#5B8DEF", -7200, .taken),
                item("Evening Magnesium", "#CC5DE8", -1800, .taken),
            ], streak: 6)
        }

        private var emptyEntry: DoseEntry { DoseEntry(date: now, items: [], streak: 0) }

        var body: some View {
            ScrollView {
                VStack(spacing: 22) {
                    Text("Widget Gallery").font(.title2.bold()).foregroundStyle(.white)

                    systemTile("Large — schedule", 360, 360) {
                        PrescriptionWidgetView(familyOverride: .systemLarge, entry: listEntry)
                    }
                    systemTile("Large — calendar", 360, 360) {
                        CalendarWidgetView(entry: .placeholder())
                    }
                    systemTile("Medium — all caught up", 360, 170) {
                        PrescriptionWidgetView(familyOverride: .systemMedium, entry: doneEntry)
                    }
                    HStack(spacing: 16) {
                        accessoryTile("Lock — rectangular", false, 160, 72) {
                            LockScreenWidgetView(familyOverride: .accessoryRectangular, entry: listEntry)
                        }
                        accessoryTile("Lock — circular", true, 72, 72) {
                            LockScreenWidgetView(familyOverride: .accessoryCircular, entry: doneEntry)
                        }
                    }
                    HStack(spacing: 16) {
                        systemTile("Small — next", 160, 160) {
                            PrescriptionWidgetView(familyOverride: .systemSmall, entry: listEntry)
                        }
                        systemTile("Small — empty", 160, 160) {
                            PrescriptionWidgetView(familyOverride: .systemSmall, entry: emptyEntry)
                        }
                    }
                    systemTile("Medium — today", 360, 170) {
                        PrescriptionWidgetView(familyOverride: .systemMedium, entry: listEntry)
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.18).ignoresSafeArea())
        }

        private func systemTile<V: View>(_ title: String,
                                         _ w: CGFloat, _ h: CGFloat,
                                         @ViewBuilder _ content: () -> V) -> some View
        {
            VStack(spacing: 8) {
                Text(title).font(.caption).foregroundStyle(.white.opacity(0.7))
                content()
                    .fontDesign(.serif)
                    .padding(16)
                    .frame(width: w, height: h)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }

        private func accessoryTile<V: View>(_ title: String, _ circular: Bool,
                                            _ w: CGFloat, _ h: CGFloat,
                                            @ViewBuilder _ content: () -> V) -> some View
        {
            VStack(spacing: 8) {
                Text(title).font(.caption).foregroundStyle(.white.opacity(0.7))
                content()
                    .fontDesign(.serif)
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(width: w, height: h)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: circular ? 36 : 16))
            }
        }
    }
#endif
