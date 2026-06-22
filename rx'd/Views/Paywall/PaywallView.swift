import SwiftUI
import StoreKit

// Rex Pro upsell sheet. Custom marketing on top; the actual purchase + restore use the
// native StoreKit SwiftUI views (ProductView + the restore store button), so price,
// localization, the buy flow, and "purchased" state are all handled by the system.
// Dismisses itself once Pro is unlocked.
struct PaywallView: View {
    @State private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, title: String, detail: String)] = [
        ("infinity", "Unlimited medications", "Track more than two prescriptions."),
        ("bell.badge", "Persistent reminders", "Repeat nudges until a dose is taken."),
        ("heart.text.square", "Apple Health", "Import meds and chart vitals against adherence."),
        ("square.and.arrow.up", "Export your history", "Save your full dose log to CSV."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PillBuddy(mood: .happy, topColor: Theme.gold, size: 96)
                        .padding(.top, 8)
                    VStack(spacing: 6) {
                        Text("Rex Pro")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.ink)
                        Text("A one-time unlock — yours forever.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkFaded)
                    }

                    LabelCard {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(features, id: \.title) { f in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: f.icon)
                                        .font(.title3)
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(f.title).font(.headline).foregroundStyle(Theme.ink)
                                        Text(f.detail).font(.caption).foregroundStyle(Theme.inkFaded)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(18)
                    }

                    // Native purchase control: price, buy flow, and purchased state.
                    ProductView(id: StoreManager.proProductID) {
                        RxMonogram(size: 38, color: Theme.gold)
                    }
                    .productViewStyle(.compact)
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))

                    Text("Pro is a one-time purchase — no subscription. Everything you've already set up stays free.")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkFaded)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // Native restore control (App Store requires a restore path).
            .storeButton(.visible, for: .restorePurchases)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onInAppPurchaseCompletion { _, result in
                await store.process(result)
            }
            .onChange(of: store.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }
}
