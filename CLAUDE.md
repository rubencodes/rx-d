# rx'd — Claude guide

iOS prescription/dose tracker. SwiftUI + SwiftData + WidgetKit + AppIntents + HealthKit.
Bundle id `codes.ruben.rx-d`, deployment target iOS 26.5.

## Build & verify

- Scheme is **`rx'd`** (the apostrophe is real — quote paths).
- A simulator that exists here: **`iPhone 17 Pro`** (there is no "iPhone 16 Pro"; check `xcodebuild -showdestinations` if unsure).
- Build: `xcodebuild -scheme "rx'd" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- **Trust `xcodebuild`, not the in-editor SourceKit diagnostics.** SourceKit constantly reports false "Cannot find 'Theme'/'Prescription' in scope" and "'main' attribute cannot be used…" errors for files in the synchronized groups. If `xcodebuild` says BUILD SUCCEEDED, the code is fine.
- After splitting/refactoring across files, prefer a clean build if results look stale: incremental builds sometimes don't recompile (this masked a HealthView rewrite once).

## Project structure conventions

- **One type per file.** One view per file; generally one model/enum/intent/service per file too. Name the file after the type. Small `private` helpers that exist solely to back one parent (e.g. a private `ViewModifier` behind a `View` extension, nested types) may stay with that parent.
- `rx'd/`, `Shared/`, and `widget/` are Xcode **file-system-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`). New `.swift` files in those folders are auto-added to the target — **do not hand-edit `project.pbxproj`** to register files.
- `Shared/` is compiled into **both** the app and the widget extension targets. Anything referenced by both lives there.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set project-wide. Expect to add `nonisolated` / `@MainActor` where appropriate.

## SwiftData + CloudKit (read before touching persistence)

- **Exactly one CloudKit-mirroring `ModelContainer` per store, and only in the app process.**
  - `ModelContainerFactory.makeAppContainer()` — CloudKit-aware; used *only* by the `@main` app's primary container.
  - `ModelContainerFactory.makeSharedContainer()` — always **local** (same App Group store, no CloudKit); used by the widget, App Intents, and the app's notification/background handlers. Their writes sync up via the app's container through persistent history.
  - Spinning up multiple CloudKit mirroring delegates (e.g. one per widget/intent, or two in one process) crashes with `-[OS_dispatch_mach_msg _setContext:]: unrecognized selector`. This crash is **async**, so a `do/catch` around the `ModelContainer` init cannot catch it.
- CloudKit also needs **server-side** provisioning (App ID with Push + iCloud, the `iCloud.codes.ruben.rx-d` container actually created, profile regenerated). The entitlements file alone is not sufficient; a mismatch crashes at launch. Push/iCloud are unavailable on personal (free) signing teams.
- Schema must stay CloudKit-compatible: every stored property has a default value, **no** `@Attribute(.unique)`, **no** SwiftData relationships. `DoseLog` joins to `Prescription` by a manual `prescriptionId: UUID`, not a relationship.

## DoseLog model (derive-on-the-fly)

- `DoseLog` records exist **only when something happens** (taken / snoozed / missed). "What's scheduled" is computed from `Prescription` + `ScheduleService`, then joined to any existing log.
- The auto-miss pass (`MissedDoseService`) inserts `.missed` logs for past unlogged occurrences on scene-active and background refresh.
- **Always upsert a DoseLog, never blind-insert.** Match on `prescriptionId` + `scheduledDate` to **minute** granularity (`Calendar.isDate(_:equalTo:toGranularity:.minute)`). A blind insert when a `.missed` log already exists creates a duplicate and the occurrence keeps showing the stale status (this was a real bug in the notification DONE handler).

## Notifications

- On marking a dose taken from anywhere (notification DONE, widget intent, in-app tap/swipe, Control Center confirm), cancel that occurrence's pending reminders — use `NotificationService.cancelOccurrence(prescriptionId:scheduledDate:)`.
- `NotificationService.rescheduleAll(prescriptions:logs:)` removes **all** pending requests first, then reschedules — so always pass the full active prescription set **and** the logs (it skips already-taken occurrences). Never call it with a single prescription.
- BGTask id `codes.ruben.rx-d.refresh` must stay listed in `BGTaskSchedulerPermittedIdentifiers` in `rx-d-Info.plist`, or registration is rejected.

## HealthKit (iOS 26 Medications API)

- Request **vitals** auth and **medication** auth separately. Folding medication types into a bulk `requestAuthorization(toShare:read:)` throws an **uncatchable** Obj-C exception. Medication types require per-object auth (`requestPerObjectReadAuthorization`), which returns a catchable Swift error.
- Medication auth is unsupported on the Simulator (guarded with `#if targetEnvironment(simulator)`).
- Read-only: rx'd never writes to Health.

## Widgets & accessibility

- Widget and Lock Screen views render **static timeline snapshots** — SwiftUI `.animation(value:)` does not produce live animation there. Don't add inert animations to widget views. Live, animated progress belongs in in-app views (e.g. `CapsuleProgress`).
- Reload widgets at mutation sites via `WidgetCenter.shared.reloadAllTimelines()`; there's also a central `ModelContext.didSave` observer as a safety net.
- The Simulator can't place widgets or Control Center controls. Use `WidgetGalleryView` (DEBUG) to screenshot widget layouts.
- Gate animations on `@Environment(\.accessibilityReduceMotion)` (the app honors Reduce Motion throughout).

## Design language

"Retro apothecary": parchment, bottle-green, oxblood, gold, serif type, ruled labels and
rubber-stamp statuses. All tokens and reusable components live in `Shared/` — reuse them, don't
reinvent.

- **Tokens** (`Theme.swift`): `background`/`surface`/`surfaceAlt`, `accent` (green), `oxblood`
  (℞ red), `gold`, `ink`/`inkFaded`, status colors (`taken` green / `pending` sepia / `snoozed`
  gold / `missed` oxblood), `cardCornerRadius`, and `rx` (the `\u{211E}` ℞ glyph).
- **Type:** apply `.fontDesign(.serif)` (system serif / New York). The ℞ is the Unicode glyph in
  serif — not a bundled font.
- **Components:** `LabelCard` (double-ruled cream "prescription label" card), `RuledHeader`
  (small-caps title between rules), `StatusStamp` (tilted ink stamp; for a future dose it reads
  SOON/LATER, not "DUE"), `RxMonogram`, `PillBuddy` (shape-drawn amber-bottle mascot, no assets),
  `AppleHealthBadge` (text-only — per Apple guidelines, no Apple logo or Health icon).
- **Colors:** build adaptive colors with `Color(light:dark:)`; prescription swatches use
  `Color(hex:)`.
- **Delight:** completion triggers `ConfettiBurst` + `Haptics` (both honor Reduce Motion).

## Identifiers

- App Group: `group.codes.ruben.rx-d`
- CloudKit container: `iCloud.codes.ruben.rx-d`
- BGTask: `codes.ruben.rx-d.refresh`
- Control kind: `codes.ruben.rx-d.NextDose`

## DEBUG launch arguments (verification harness)

`--seed`, `--tab <n>`, `--onboarding-step <n>`, `--all-done`, `--show-delete-alert`,
`--show-archived-detail`, `--health-connected`, `--fake-vitals`, `--show-import`,
`--confirm-dose`, `--widget-gallery`, `--prefill-name <name>`. Seeding logic is in `DebugSeed.swift`.
