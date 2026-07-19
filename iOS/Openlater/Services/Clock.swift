import Foundation

/// Injectable "now" provider. Production code reads `Date()` exactly once, here —
/// everywhere else (gating checks, re-seal math, views) takes a `Clock` so tests can
/// pass a fixed, deterministic instant instead of depending on wall-clock time.
protocol Clock {
    func now() -> Date
}

struct SystemClock: Clock {
    func now() -> Date { Date() }
}

/// Deterministic clock for tests and previews.
struct FixedClock: Clock {
    let fixedNow: Date
    func now() -> Date { fixedNow }
}
