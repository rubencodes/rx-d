import SwiftData
import SwiftUI

@main
struct rx_dApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let container: ModelContainer = {
        do {
            // The app process owns the sole CloudKit-mirroring container. Widgets,
            // intents, and background handlers use makeSharedContainer() (local) so
            // there's only ever one mirroring delegate per store.
            return try ModelContainerFactory.makeAppContainer()
        } catch {
            // App Group not yet configured in entitlements — fall back to local store
            return try! ModelContainerFactory.makeLocalContainer()
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .modelContainer(container)
        }
    }
}
