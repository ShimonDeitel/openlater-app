import XCTest
@testable import Openlater

final class OpenlaterLogicTests: XCTestCase {

    private let utc: TimeZone = TimeZone(identifier: "UTC")!

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h
        return cal.date(from: comps)!
    }

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal
    }

    // MARK: State

    func testState_BeforeUnlockDate_IsSealed() {
        let now = date(2026, 1, 1)
        let unlock = date(2026, 6, 15)
        XCTAssertEqual(CapsuleGating.state(now: now, unlockDate: unlock, hasBeenOpenedSinceUnlock: false), .sealed)
    }

    func testState_ExactlyAtUnlockInstant_IsReadyToBreak_NotSealed() {
        let unlock = date(2026, 6, 15)
        XCTAssertEqual(CapsuleGating.state(now: unlock, unlockDate: unlock, hasBeenOpenedSinceUnlock: false), .readyToBreak)
    }

    func testState_OneSecondBeforeUnlock_IsStillSealed() {
        let unlock = date(2026, 6, 15)
        let now = unlock.addingTimeInterval(-1)
        XCTAssertEqual(CapsuleGating.state(now: now, unlockDate: unlock, hasBeenOpenedSinceUnlock: false), .sealed)
    }

    func testState_AfterUnlockAndAlreadyOpened_IsOpen() {
        let now = date(2026, 7, 1)
        let unlock = date(2026, 6, 15)
        XCTAssertEqual(CapsuleGating.state(now: now, unlockDate: unlock, hasBeenOpenedSinceUnlock: true), .open)
    }

    func testState_LongAfterUnlock_NeverViewed_IsStillReadyToBreak() {
        // App simply wasn't opened for a year — should not be treated as "sealed"
        // or silently marked open; it must show the break animation whenever it is
        // finally viewed.
        let now = date(2027, 1, 1)
        let unlock = date(2026, 6, 15)
        XCTAssertEqual(CapsuleGating.state(now: now, unlockDate: unlock, hasBeenOpenedSinceUnlock: false), .readyToBreak)
    }

    func testIsLocked_MatchesState() {
        let unlock = date(2026, 6, 15)
        XCTAssertTrue(CapsuleGating.isLocked(now: date(2026, 6, 14), unlockDate: unlock))
        XCTAssertFalse(CapsuleGating.isLocked(now: unlock, unlockDate: unlock))
        XCTAssertFalse(CapsuleGating.isLocked(now: date(2026, 6, 16), unlockDate: unlock))
    }

    // MARK: Time remaining

    func testTimeRemaining_PositiveBeforeUnlock() {
        let now = date(2026, 6, 10)
        let unlock = date(2026, 6, 15)
        let remaining = CapsuleGating.timeRemaining(now: now, unlockDate: unlock)
        XCTAssertEqual(remaining, 5 * 86_400, accuracy: 1)
    }

    func testTimeRemaining_FlooredAtZero_NeverNegative() {
        let now = date(2026, 7, 1)
        let unlock = date(2026, 6, 15)
        XCTAssertEqual(CapsuleGating.timeRemaining(now: now, unlockDate: unlock), 0)
    }

    // MARK: Recurring re-seal date math

    func testNextUnlockDate_Yearly_AdvancesExactlyOneYearWhenOpenedOnTime() {
        let unlock = date(2026, 3, 10)
        let openedAt = date(2026, 3, 10, 9) // opened same day, a few hours later
        let next = CapsuleGating.nextUnlockDate(recurrence: .yearly, previousUnlockDate: unlock, now: openedAt, calendar: utcCalendar)
        XCTAssertEqual(next, date(2027, 3, 10))
    }

    func testNextUnlockDate_Yearly_SkipsMultipleYearsIfOpenedLate() {
        // Unlocked in 2024, but the user doesn't open the app until 2027 — the
        // birthday letter must land on the next *future* March 10, not repeat a
        // date that's already passed.
        let unlock = date(2024, 3, 10)
        let openedAt = date(2027, 5, 1)
        let next = CapsuleGating.nextUnlockDate(recurrence: .yearly, previousUnlockDate: unlock, now: openedAt, calendar: utcCalendar)
        XCTAssertEqual(next, date(2028, 3, 10))
    }

    func testNextUnlockDate_Monthly_AdvancesOneMonth() {
        let unlock = date(2026, 1, 31)
        let openedAt = date(2026, 2, 5)
        let next = CapsuleGating.nextUnlockDate(recurrence: .monthly, previousUnlockDate: unlock, now: openedAt, calendar: utcCalendar)
        // Calendar clamps Jan 31 + 1 month to the last valid day of February.
        XCTAssertNotNil(next)
        XCTAssertGreaterThan(next!, openedAt)
    }

    func testNextUnlockDate_None_ReturnsNil() {
        let unlock = date(2026, 3, 10)
        let next = CapsuleGating.nextUnlockDate(recurrence: .none, previousUnlockDate: unlock, now: date(2026, 3, 11), calendar: utcCalendar)
        XCTAssertNil(next)
    }

    // MARK: Free tier gating

    func testCanCreateCapsule_FreeTier_AllowsUpToThree() {
        XCTAssertTrue(CapsuleGating.canCreateCapsule(existingCount: 0, isPro: false))
        XCTAssertTrue(CapsuleGating.canCreateCapsule(existingCount: 2, isPro: false))
        XCTAssertFalse(CapsuleGating.canCreateCapsule(existingCount: 3, isPro: false))
    }

    func testCanCreateCapsule_Pro_Unlimited() {
        XCTAssertTrue(CapsuleGating.canCreateCapsule(existingCount: 50, isPro: true))
    }

    func testCanUseKind_FreeTier_TextOnly() {
        XCTAssertTrue(CapsuleGating.canUseKind(.text, isPro: false))
        XCTAssertFalse(CapsuleGating.canUseKind(.photo, isPro: false))
        XCTAssertFalse(CapsuleGating.canUseKind(.voice, isPro: false))
    }

    func testCanUseKind_Pro_AllKinds() {
        XCTAssertTrue(CapsuleGating.canUseKind(.photo, isPro: true))
        XCTAssertTrue(CapsuleGating.canUseKind(.voice, isPro: true))
    }

    func testCanUseRecurrence_FreeTier_OnlyNone() {
        XCTAssertTrue(CapsuleGating.canUseRecurrence(.none, isPro: false))
        XCTAssertFalse(CapsuleGating.canUseRecurrence(.yearly, isPro: false))
        XCTAssertFalse(CapsuleGating.canUseRecurrence(.monthly, isPro: false))
    }

    func testCanUseRecurrence_Pro_AllRules() {
        XCTAssertTrue(CapsuleGating.canUseRecurrence(.yearly, isPro: true))
        XCTAssertTrue(CapsuleGating.canUseRecurrence(.monthly, isPro: true))
    }

    // MARK: FixedClock

    func testFixedClock_AlwaysReturnsSameInstant() {
        let fixed = date(2026, 5, 5)
        let clock = FixedClock(fixedNow: fixed)
        XCTAssertEqual(clock.now(), fixed)
        XCTAssertEqual(clock.now(), fixed)
    }
}
