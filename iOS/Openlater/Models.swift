import Foundation
import SwiftData

/// What kind of content a capsule holds. Text is free-tier; photo and voice are Pro.
enum CapsuleKind: String, Codable, CaseIterable {
    case text
    case photo
    case voice
}

/// How a capsule re-seals after being opened. Pro-only. `.none` capsules are consumed
/// (stay unlocked forever) once opened.
enum RecurrenceRule: String, Codable, CaseIterable, Identifiable {
    case none
    case yearly
    case monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "One time"
        case .yearly: return "Every year"
        case .monthly: return "Every month"
        }
    }
}

/// A sealed letter. Persisted with SwiftData. Photo/voice payloads are stored as
/// local file references (filenames under the app's Application Support directory),
/// never as remote URLs — nothing about a capsule is ever uploaded anywhere.
@Model
final class LetterCapsule {
    var id: UUID
    var title: String
    var kind: CapsuleKind
    var textBody: String
    /// Filename (not full path) of the on-device media file for .photo/.voice kinds.
    var mediaFilename: String?
    var createdAt: Date
    var unlockDate: Date
    var recurrence: RecurrenceRule
    /// Set the first time the (currently unlocked) capsule content is actually
    /// viewed, so the one-time "break the seal" animation only plays once per
    /// unlock cycle.
    var hasBeenOpenedSinceUnlock: Bool
    /// How many times this capsule has completed an open -> re-seal cycle.
    var timesOpened: Int

    init(
        id: UUID = UUID(),
        title: String,
        kind: CapsuleKind,
        textBody: String = "",
        mediaFilename: String? = nil,
        createdAt: Date,
        unlockDate: Date,
        recurrence: RecurrenceRule = .none,
        hasBeenOpenedSinceUnlock: Bool = false,
        timesOpened: Int = 0
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.textBody = textBody
        self.mediaFilename = mediaFilename
        self.createdAt = createdAt
        self.unlockDate = unlockDate
        self.recurrence = recurrence
        self.hasBeenOpenedSinceUnlock = hasBeenOpenedSinceUnlock
        self.timesOpened = timesOpened
    }
}
