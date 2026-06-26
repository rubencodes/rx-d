import Foundation
import StoreKit

// The app's "Rex Pro" entitlement brain. The native StoreKit SwiftUI views
// (ProductView / StoreView in PaywallView) own the purchase + restore UI; this type
// just tracks whether Pro is unlocked and mirrors it into SharedDefaults so
// notification/background code can gate features without touching StoreKit.
// `Transaction.currentEntitlements` is the source of truth.
@Observable
@MainActor
final class StoreManager {
    static let shared = StoreManager()

    static let proProductID = "RexPro"
    /// Free tier allows this many active medications; Pro removes the cap.
    static let freeMedicationLimit = 2

    private(set) var isPro: Bool = SharedDefaults.shared.proUnlocked

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = observeTransactionUpdates()
        Task { await refreshEntitlement() }
    }

    /// Whether a free user adding another medication would cross the limit.
    func canAddMedication(activeCount: Int) -> Bool {
        isPro || activeCount < Self.freeMedicationLimit
    }

    /// Recompute Pro from StoreKit's current entitlements. Cheap; safe to call often.
    func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        setPro(entitled)
    }

    /// Handle the result delivered by a native view's `.onInAppPurchaseCompletion`.
    func process(_ result: Result<Product.PurchaseResult, any Error>) async {
        if case let .success(.success(.verified(transaction))) = result {
            await apply(transaction)
        } else {
            await refreshEntitlement()
        }
    }

    // Grant entitlement straight from a verified transaction. Granting from the
    // transaction itself — rather than immediately re-querying currentEntitlements —
    // avoids a race where the just-completed purchase isn't yet reflected there, which
    // would leave Pro stuck off right after buying.
    private func apply(_ transaction: Transaction) async {
        await transaction.finish()
        if transaction.productID == Self.proProductID, transaction.revocationDate == nil {
            setPro(true)
        } else {
            await refreshEntitlement()
        }
    }

    /// Restore past purchases. The paywall uses the native restore store button; this
    /// backs the explicit "Restore Purchases" entry in Settings.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    private func setPro(_ value: Bool) {
        isPro = value
        SharedDefaults.shared.proUnlocked = value
    }

    // Catches transactions that arrive outside a purchase UI (renewals, another device,
    // Ask to Buy approvals). Finishes them and refreshes Pro.
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                if case let .verified(transaction) = update {
                    await self?.apply(transaction)
                } else {
                    await self?.refreshEntitlement()
                }
            }
        }
    }
}
