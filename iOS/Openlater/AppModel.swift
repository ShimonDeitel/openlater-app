import Foundation
import SwiftData
import SwiftUI

/// App-wide state: the SwiftData container, the live capsule list, settings, and the
/// launch-time / foreground-time re-seal sweep for recurring Pro capsules. Holds a
/// `Clock` (defaults to `SystemClock`) so the one call to `Date()` in the whole app
/// lives here, injected, rather than scattered through views.
@MainActor
final class AppModel: ObservableObject {
    @Published var capsules: [LetterCapsule] = []
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey) }
    }

    var store: Store?
    let clock: Clock
    private let modelContext: ModelContext

    private static let themeKey = "openlater.theme"

    init(container: ModelContainer, clock: Clock = SystemClock()) {
        self.modelContext = ModelContext(container)
        self.clock = clock
        if let saved = UserDefaults.standard.string(forKey: Self.themeKey), let t = AppTheme(rawValue: saved) {
            self.theme = t
        } else {
            self.theme = .system
        }
        reload()
        sweepReseals()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([LetterCapsule.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    func reload() {
        let descriptor = FetchDescriptor<LetterCapsule>(sortBy: [SortDescriptor(\.unlockDate, order: .forward)])
        capsules = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Mutations

    func addCapsule(_ capsule: LetterCapsule) {
        modelContext.insert(capsule)
        save()
    }

    func delete(_ capsule: LetterCapsule) {
        MediaStore.delete(capsule.mediaFilename)
        modelContext.delete(capsule)
        save()
    }

    /// Called the moment a ready-to-break capsule is actually viewed. Marks it
    /// opened and, for recurring capsules, immediately computes and applies the
    /// next unlock date so the capsule instantly re-seals for its next cycle.
    func markOpened(_ capsule: LetterCapsule) {
        let now = clock.now()
        capsule.hasBeenOpenedSinceUnlock = true
        capsule.timesOpened += 1
        if capsule.recurrence != .none,
           let next = CapsuleGating.nextUnlockDate(
               recurrence: capsule.recurrence,
               previousUnlockDate: capsule.unlockDate,
               now: now
           ) {
            capsule.unlockDate = next
            capsule.hasBeenOpenedSinceUnlock = false
        }
        save()
    }

    /// Runs on launch and whenever the app returns to foreground: recurring
    /// capsules that were opened, then left the app open past another full cycle
    /// without being re-viewed, still get advanced so the countdown always reflects
    /// the true next unlock rather than a stale past date. Non-recurring, opened
    /// capsules are left untouched (they stay open forever).
    func sweepReseals() {
        let now = clock.now()
        var changed = false
        for capsule in capsules where capsule.recurrence != .none && capsule.hasBeenOpenedSinceUnlock {
            if let next = CapsuleGating.nextUnlockDate(
                recurrence: capsule.recurrence,
                previousUnlockDate: capsule.unlockDate,
                now: now
            ), next != capsule.unlockDate {
                capsule.unlockDate = next
                capsule.hasBeenOpenedSinceUnlock = false
                changed = true
            }
        }
        if changed { save() }
    }

    private func save() {
        try? modelContext.save()
        reload()
    }

    // MARK: - Derived

    func state(for capsule: LetterCapsule) -> CapsuleGating.State {
        CapsuleGating.state(now: clock.now(), unlockDate: capsule.unlockDate, hasBeenOpenedSinceUnlock: capsule.hasBeenOpenedSinceUnlock)
    }

    var canCreateMore: Bool {
        CapsuleGating.canCreateCapsule(existingCount: capsules.count, isPro: store?.isPro ?? false)
    }
}
