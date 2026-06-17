import Foundation
import UIKit

// Stores per-dose photos as files in the App Group container's DosePhotos/ directory.
// DoseLog stores only the filename; the image bytes live on disk (not in SwiftData).
enum PhotoStore {
    private static var directory: URL? {
        guard let base = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ModelContainerFactory.appGroupIdentifier)
        else { return nil }
        let dir = base.appendingPathComponent("DosePhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // Saves JPEG data, returns the generated filename to store on the DoseLog.
    static func save(_ image: UIImage) -> String? {
        guard let dir = directory,
              let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        var url = dir.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            // Exclude from iCloud backup by default
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
            return filename
        } catch {
            return nil
        }
    }

    static func load(_ filename: String) -> UIImage? {
        guard let dir = directory else { return nil }
        let url = dir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(_ filename: String) {
        guard let dir = directory else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(filename))
    }

    // Removes image files no longer referenced by any DoseLog.
    static func cleanupOrphans(referencedFilenames: Set<String>) {
        guard let dir = directory,
              let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path)
        else { return }
        for file in files where !referencedFilenames.contains(file) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
        }
    }
}
