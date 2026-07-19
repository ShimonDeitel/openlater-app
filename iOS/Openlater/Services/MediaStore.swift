import Foundation
import UIKit

/// Local-only storage for capsule media (photos and voice-memo audio). Everything
/// lives under Application Support in this app's sandbox — nothing is ever uploaded,
/// synced, or sent over the network. There is deliberately no CloudKit/iCloud
/// container here (see project notes): purely on-device files, addressed by
/// filename only, so a deleted app / fresh install has no residual off-device copy.
enum MediaStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("CapsuleMedia", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    @discardableResult
    static func savePhoto(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let filename = "photo-\(UUID().uuidString).jpg"
        do {
            try data.write(to: url(for: filename), options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    static func reservedVoiceFilename() -> String {
        "voice-\(UUID().uuidString).m4a"
    }

    static func delete(_ filename: String?) {
        guard let filename else { return }
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    static func loadImage(_ filename: String?) -> UIImage? {
        guard let filename else { return nil }
        return UIImage(contentsOfFile: url(for: filename).path)
    }
}
