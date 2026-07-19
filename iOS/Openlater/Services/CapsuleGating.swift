import Foundation

/// Pure, dependency-free date-gating logic for capsules. Everything here operates on
/// plain `Date` values and a `Calendar`, takes "now" as an explicit parameter, and
/// touches neither `Date()`/`Date.now` nor SwiftData — so it is trivially unit
/// testable with hand-picked fixed dates and safe to call on every app launch/tick
/// without ever "missing" an unlock just because the app wasn't open at the exact
/// instant the date arrived (checked against current time, not a timer).
enum CapsuleGating {

    enum State: Equatable {
        /// Unlock date has not yet arrived. `intact` — the seal has never been
        /// broken; a capsule always shows this state, with zero access to content,
        /// for every instant before its unlock date.
        case sealed
        /// Unlock date has passed and the capsule has not yet been viewed since
        /// unlocking — this is the moment the seal-break animation should play.
        case readyToBreak
        /// Unlock date has passed and the content has already been viewed at least
        /// once since this unlock cycle began.
        case open
    }

    /// The single source of truth for whether a capsule may reveal its content.
    /// `now` and `unlockDate` are compared with `>=` so the exact unlock instant
    /// itself already counts as unlocked (never "one tick early").
    static func state(now: Date, unlockDate: Date, hasBeenOpenedSinceUnlock: Bool) -> State {
        guard now >= unlockDate else { return .sealed }
        return hasBeenOpenedSinceUnlock ? .open : .readyToBreak
    }

    static func isLocked(now: Date, unlockDate: Date) -> Bool {
        now < unlockDate
    }

    /// Time remaining until unlock, floored at zero. Never negative, so a countdown
    /// label never reads as "unlocked -3 days ago" for an already-open capsule.
    static func timeRemaining(now: Date, unlockDate: Date) -> TimeInterval {
        max(0, unlockDate.timeIntervalSince(now))
    }

    /// Computes the next unlock date for a recurring capsule once it has been opened,
    /// by advancing the *original* unlock date forward by whole recurrence units
    /// until the result is strictly after `now`. Anchoring to the original unlock
    /// date (not `now`) keeps a yearly birthday letter landing on the same
    /// month/day every year, even if the user opens it late.
    static func nextUnlockDate(
        recurrence: RecurrenceRule,
        previousUnlockDate: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard recurrence != .none else { return nil }
        var candidate = previousUnlockDate
        var iterations = 0
        while candidate <= now, iterations < 10_000 {
            guard let advanced = advance(candidate, by: recurrence, calendar: calendar) else { return nil }
            candidate = advanced
            iterations += 1
        }
        return candidate
    }

    private static func advance(_ date: Date, by recurrence: RecurrenceRule, calendar: Calendar) -> Date? {
        switch recurrence {
        case .none:
            return nil
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }

    /// Free-tier capsule cap.
    static let freeCapsuleLimit = 3

    static func canCreateCapsule(existingCount: Int, isPro: Bool) -> Bool {
        isPro || existingCount < freeCapsuleLimit
    }

    static func canUseKind(_ kind: CapsuleKind, isPro: Bool) -> Bool {
        switch kind {
        case .text: return true
        case .photo, .voice: return isPro
        }
    }

    static func canUseRecurrence(_ recurrence: RecurrenceRule, isPro: Bool) -> Bool {
        recurrence == .none || isPro
    }
}
