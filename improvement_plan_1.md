# Improvement Plan 1

## Phase A — Self review findings

| ID | Issue | Severity | Fix |
|---|---|---|---|
| ISSUE-001 | SwiftData container crashed on first launch because the iCloud entitlement made SwiftData enable CloudKit integration, which rejects `.unique` constraints | Critical | Explicit `cloudKitDatabase: .none` on both persistent and in-memory `ModelConfiguration` (fixed) |
| ISSUE-002 | Forced unwrap of `env.profile` in the no-show path could crash if the profile was unavailable | Critical | Guarded optional binding (fixed) |
| ISSUE-003 | Category chips showed "Furniture" twice (the "All" chip reused the Furniture label) | Major | Added a dedicated `AllCategoryChip` with grid icon (fixed) |
| ISSUE-004 | The keyboard covered the AI draft button on the post screen | Major | Added `@FocusState` + keyboard toolbar "Done" (fixed) |
| ISSUE-005 | Bottom content sat under the floating tab bar on Post / Hauls / Wanted / Profile | Major | Added bottom content padding on each scroll view (fixed) |
| ISSUE-006 | Safe exchange used the listing coordinate even when a listing had no coordinates, searching the Gulf of Guinea | Major | Falls back to the user's coordinate when lat/lon are 0 (fixed) |
| ISSUE-007 | Notifications permission was requested before the user experienced any value | Major | Moved request to the first successful dibs (contextual) (fixed) |
| ISSUE-008 | Location permission appeared on top of onboarding because `RootTabView` requested it at launch | Minor | Request only when the user has already onboarded (fixed) |
| ISSUE-009 | Paywall prices are hardcoded as fallback strings when StoreKit products are unavailable | Minor | Fallback only; live prices always come from `Product.displayPrice` when products load |
| ISSUE-010 | Chat requires CloudKit for cross-device messaging; in local-only mode messages stay on device | Minor | Documented; graceful local mode by design |
| ISSUE-011 | No photo picking in the automated UI test, so posting is verified by unit tests | Minor | Added 12 unit tests covering posting, moderation, claims, confirmation, trust and wanted matching |

## Phase B — Implemented changes

- `AppEnvironment.swift` — `cloudKitDatabase: .none`, `init(inMemory:)` seam, UI-test onboarding flag.
- `ItemDetailView.swift` — removed force unwrap in the no-show path.
- `Components.swift` — new `AllCategoryChip`.
- `NearbyRootView.swift` — uses the new All chip.
- `PostItemView.swift` — keyboard toolbar Done + `@FocusState` + bottom padding.
- `MyHaulsView.swift`, `WantedView.swift`, `ProfileView.swift` — bottom padding.
- `SafeExchangeView.swift` — coordinate fallback to the user location.
- `OnboardingView.swift`, `RootTabView.swift`, `ItemDetailViewModel.swift` — contextual permission prompts.
- `DibslyTests/LogicTests.swift` — 12 passing unit tests.
- `DibslyUITests/DibslyUITests.swift` — navigation and screen smoke test, passing.

## Verification

- `xcodebuild build` — BUILD SUCCEEDED (iPhone 16, iOS 26.4).
- `xcodebuild test -only-testing:DibslyTests` — **12 / 12 passed**.
- `xcodebuild test -only-testing:DibslyUITests` — **1 / 1 passed**, covering Nearby, Wanted, Post, Hauls, Profile, Settings, AI config, Contact support and Paywall screens.
- Screenshots reviewed for each screen: no white screens, no clipped primary actions, consistent brand colors in light mode.

## Scores after iteration 1

- Usability: 4/5 — three taps to the map and one tap to dibs; zero sign-in.
- UI Consistency: 4/5 — one design system for colors, radii, chips, cards and buttons.
- Feature Completeness: 4/5 — 17 / 17 features from `us.md` implemented; claim flow validated by unit tests rather than cross-device UI.
- Download-to-Use: 4/5 — works immediately with no key; Apple Intelligence upgrades automatically on supported devices.
- Competitive Level: 4/5 — trust score, gatekeeper, confirmation loop, share card, safe-exchange layer.
- Contact Support: 5/5 — 7 subject tiles with SF Symbols, all required fields, backend POST, privacy microcopy, success/error states.
- Accessibility: 4/5 — semantic text styles, accessibility labels on all custom controls, Dynamic Type.

## Exit criteria

- Critical issues remaining: 0
- Major issues remaining: 0
- Build: SUCCEEDED
- Unit tests: 12 / 12 passing
- UI smoke test: passing
- TODO/stub code: none
