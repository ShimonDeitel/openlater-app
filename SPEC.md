# Openlater — Time Capsule Letters

Category: Lifestyle / Journal · Platform: iOS 17+ · Bundle: `com.shimondeitel.openlater`

## Concept

A digital time capsule. Write a letter, attach a photo, or record a voice memo,
pick a future "open when…" date — a birthday, an anniversary, or any day worth
waiting for — and Openlater seals it with a literal wax seal. The content is
genuinely inaccessible until that date arrives: there is no settings toggle, no
developer menu, no way to peek early, for anyone, including the person who wrote it.

## Problem / evidence

People want to write to their future selves or loved ones — a letter to open on a
child's 18th birthday, a note for next year's anniversary, an "open when you need
this" letter for a hard day — but existing options are either a literal envelope in
a drawer (easy to lose, easy to open early) or a scheduled email (impersonal,
requires an account, and typically upload-everything-to-a-server). Openlater is a
pure, offline, on-device alternative: the discipline of a sealed envelope with the
convenience of a phone.

## Free tier

- Up to 3 sealed capsules at a time.
- Text-only letters.
- Full date-gating, the wax-seal visuals, and the seal-break animation are all
  available free — the limits are capacity and content kind only.

## Pro — $3.99/month (auto-renewable subscription, `com.shimondeitel.openlater.pro.monthly`)

- Unlimited capsules.
- Photo capsules (a photo, with an optional caption, sealed inside).
- Voice-memo capsules (record your own voice, played back only after unlock).
- Recurring capsules: a capsule can re-seal itself after being opened, landing on
  the next occurrence of the same yearly or monthly date — e.g. a birthday letter
  that is readable every year on the same day, then automatically locks again for
  the following year.

## Locking model (the actual guarantee)

- A capsule's lock state is a pure function of `(now, unlockDate,
  hasBeenOpenedSinceUnlock)` — see `CapsuleGating.state(...)` in
  `iOS/Openlater/Services/CapsuleGating.swift`. There is no timer that "fires" at
  the unlock moment; instead, the check re-runs every time the app becomes active
  (on launch and on returning to foreground), so a capsule that unlocked while the
  app was closed is correctly shown as unlockable the next time it's opened —
  tolerant of not having the app open, never tolerant of opening early.
- `now >= unlockDate` is the exact unlock instant already counting as unlocked (not
  one tick early, not one tick late).
- The locked view (`CapsuleDetailView.lockedView`) renders only the intact wax seal
  and the unlock date — no path in the view hierarchy reads `textBody`,
  `mediaFilename`, or any capsule content while sealed.
- Recurring re-seal math (`CapsuleGating.nextUnlockDate`) anchors to the *original*
  unlock date and advances by whole calendar units until the result is in the
  future, so a birthday letter opened late still lands on the correct month/day the
  following year rather than drifting to "one year from whenever it was opened."

## Local-first storage (no CloudKit, no network)

Openlater is fully offline. Text lives in a local SwiftData store; photos and voice
memos are written as plain files (`.jpg` / `.m4a`) under this app's own
`Application Support/CapsuleMedia` directory (see `Services/MediaStore.swift`) and
referenced by filename only. There is no CloudKit container, no iCloud sync, and no
network client anywhere in the codebase — deleting the app deletes everything.

## Animation hook — breaking the wax seal

Every capsule is represented as a wax seal (`Components.swift: WaxSealView`):

- **Sealed:** a solid, glossy disc with an embossed ring-and-line monogram. No
  crack, no gap — visually communicates "closed," with the unlock date shown
  underneath, but zero way to see through it.
- **Unlock moment:** the first time a ready-to-open capsule is viewed, a jagged
  crack (`CrackShape`, an animatable `Shape` whose `progress` is driven by
  `withAnimation`) draws itself across the seal in ~0.5s, then the two halves of the
  disc spring apart (`interpolatingSpring`) and fade slightly, revealing the letter
  behind it. This plays exactly once per unlock cycle — after that the capsule shows
  the already-broken seal at rest.
- **Re-seal:** when a recurring capsule's next unlock date is computed, the seal
  resets to intact for the next cycle.

## Design language

Warm keepsake palette: aged paper cream, ink brown, sealing-wax red, and a touch of
gold leaf for embossed detail — deliberately distinct from every other app in this
factory (no black/white/blue). Serif display type for titles, rounded sans for
labels, monospace for dates/countdowns — evokes handwriting and postmarks without
using a literal script font. Vector shapes only — no emoji, no photographic assets
beyond user-supplied capsule photos.

## Non-goals

- No AI feature of any kind — pure local content + date logic.
- No CloudKit/iCloud sync (see project notes — a prior app in this factory was
  permanently blocked by an iCloud container that could never be created).
- No sharing/export of capsules to other people in v1.
