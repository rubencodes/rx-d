import Foundation
import SwiftData

enum ModelContainerFactory {
    static let appGroupIdentifier = "group.codes.ruben.rx-d"
    static let storeName = "rxd.store"
    static let cloudKitContainerID = "iCloud.codes.ruben.rx-d"

    private static func appGroupStoreURL() throws -> URL {
        guard let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        else {
            throw ContainerError.missingAppGroup
        }
        return groupURL.appendingPathComponent(storeName)
    }

    // The MAIN APP's primary container — the ONLY container that should ever drive
    // CloudKit mirroring. CloudKit requires exactly one NSCloudKitMirroringDelegate per
    // store; spinning up more than one (e.g. one here AND one per widget / intent /
    // background handler, several even in the same process) corrupts the shared
    // dispatch machinery and crashes with `-[OS_dispatch_mach_msg _setContext:]:
    // unrecognized selector`. Honors the opt-in iCloud toggle; uses a plain local
    // (App Group) store when sync is off.
    static func makeAppContainer() throws -> ModelContainer {
        let schema = Schema([Prescription.self, DoseLog.self])
        let storeURL = try appGroupStoreURL()
        let config: ModelConfiguration
        if useCloudKit {
            config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            config = ModelConfiguration(schema: schema, url: storeURL)
        }
        return try ModelContainer(for: schema, configurations: [config])
    }

    // CloudKit mirroring is only safe to switch on when the user has opted in AND an
    // iCloud account is actually signed in. Enabling it without a logged-in account
    // makes CloudKit's async setup tear down abnormally — surfacing as the
    // `OS_dispatch_mach_msg _setContext:` crash that a Swift do/catch around the
    // ModelContainer init can't catch (the init succeeds; the failure is async).
    static var useCloudKit: Bool {
        SharedDefaults.shared.iCloudSyncEnabled
            && FileManager.default.ubiquityIdentityToken != nil
    }

    // Auxiliary container for the widget extension, App Intents, and the app's own
    // notification / background handlers. ALWAYS local (never CloudKit): it points at
    // the same App Group store, so its writes are observed and synced up by the app's
    // CloudKit container through persistent-history tracking. Keeping CloudKit out of
    // these processes is what prevents the multiple-mirroring-delegate crash.
    static func makeSharedContainer() throws -> ModelContainer {
        let schema = Schema([Prescription.self, DoseLog.self])
        let storeURL = try appGroupStoreURL()
        let config = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // Fallback used before App Group entitlement is configured in Xcode
    static func makeLocalContainer() throws -> ModelContainer {
        let schema = Schema([Prescription.self, DoseLog.self])
        return try ModelContainer(for: schema)
    }

    enum ContainerError: Error {
        case missingAppGroup
    }
}
