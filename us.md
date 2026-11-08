# Dibsly — iOS Development Guide

## Executive Summary

Dibsly is a neighborhood free-stuff radar for the US market. It turns "curb alerts" into a trusted, real-time, gamified community: neighbors post things they no longer need, everyone else calls **dibs** before it is gone.

- **Tagline**: *Call dibs on free stuff.*
- **Category**: Lifestyle / Shopping
- **Target audience**: US bargain hunters, students, young renters, families in the Buy Nothing / Freecycle mindset, 22–45, 60%+ dark mode.
- **Positioning**: Snag ($30K MRR) proved the demand, but the category has a trust gap — scams, no-shows, no in-app chat, no moderation. Dibsly wins by making "the scam dumping ground" into "a reputation community".
- **Business model**: Free tier + Dibsly Pro subscription (monthly / yearly / lifetime) + consumable AI credits. AI is never sold as "unlimited" — on-device AI is free & unlimited, cloud AI is metered via credits or the user's own key.

### Seven Differentiators (product spine)

| # | Differentiator | What it does |
|---|---|---|
| 1 | **Dibs 60-second grab** | High-value items get a visible 60s priority claim window with a countdown; haptic + confetti win moment |
| 2 | **AI gatekeeper** | Every listing passes a moderation pipeline (banned goods, commercial resale, scam phrasing, stolen photos). Low confidence goes to a review queue — never silently live |
| 3 | **Trust Score** | Bidirectional confirmation raises trust, no-shows and scams lower it. Badges: Newbie → Neighbor → Trusted → Legend |
| 4 | **Confirmation loop** | Giver marks given + Taker marks received = deal closed. 24h auto-release prevents hoarding; 10min no-contact auto-release |
| 5 | **Share-card flywheel** | Closing a deal renders a "You saved $X" card with the item photo → share sheet → TikTok / IG Story |
| 6 | **AI valuation** | Every listing gets an "worth ~$X" estimate so the saving feels concrete; labeled as an estimate, not an appraisal |
| 7 | **Safe exchange** | Built-in safe-exchange-zone map layer (police stations / public places) + safety checklist in chat |

## Competitive Analysis

| App | Strengths | Weaknesses | Our Advantage |
|---|---|---|---|
| **Snag** ($30K MRR, 103K users) | Proven free + subscription funnel, aggregated supply, big install base | Pure aggregator of FB / Craigslist / Nextdoor, no trust system, no in-app chat, minute-level polling | Owned UGC supply, reputation layer, sub-second alerts, in-app chat |
| **Freebie Alerts** (235K ratings) | Category leader by installs, free | Scam / misleading listings, missing contact info, over-push, crashes, billing complaints | Moderation gate, real trust score, transparent billing + one-tap cancel |
| **Buy Nothing (official 3.0)** | Massive movement, fully free | Bug-heavy release (password reset, freezing, scrolling), no product polish | Reliable engineering, offline-first cache, polished SwiftUI |
| **Swoop / Freebox** (2026 entrants) | Fast clones of Snag | No differentiation, no network density | Differentiated trust + AI + safe-exchange wedge |
| **FB Marketplace / Craigslist free** | Largest raw supply | Scam hotspot, no verification, noisy UX | Curated, moderated, reputation-gated community |

## ⚠️ Feature Inventory (MANDATORY)

### Primary Features

| # | Feature | User Operation Flow | Data Input | Processing | Data Output | Persistence | Acceptance Criteria |
|---|---|---|---|---|---|---|---|
| 1 | **Location onboarding** | 1. Launch → 2. One-screen location explainer → 3. Allow location → 4. Straight into map with pins | CoreLocation authorization | Reverse-geocode to city; compute coarse geohash-5 grid; ±300m fuzzing for pin display | Full-screen map with nearby pins; city label | Cached coordinate + city in SwiftData/Settings | First launch reaches map in ≤2 taps; denying location falls back to a default city with a retry banner |
| 2 | **Map feed** | 1. Home tab → 2. Pan/zoom map → 3. Tap pin → 4. Bottom card slides up | Map camera, selected category chip | ViewModel queries local store by geohash grid + category, sorts by recency, fuses CloudKit remote items when available | Thumbnail pins with "worth $X" ribbon; bottom item card | SwiftData `Item` cache | Map shows only LIVE items; tap pin reliably opens the card; camera change triggers incremental query |
| 3 | **List feed** | 1. Toggle Map/List segmented control → 2. Scroll single-column cards → 3. Tap card | Category filter, search text | Search over title/description/category; distance sort | Single-column large-photo cards with distance + worth + trust badge | SwiftData | Toggle preserves filters; list scroll stays ≥55fps with 60 items |
| 4 | **Item detail + DIBS** | 1. Open detail → 2. Swipe photo carousel → 3. Read worth / trust / safety → 4. Tap **DIBS!** | Selected item | Claim validator: own item? already taken? claim window? distance limit? → atomic claim | Celebration (confetti + heavy haptic + "YOU GOT DIBS!"), countdown bar, My Hauls entry | `Item.status = DIBBED`, `Claim` record, `TrustEvent` | Only one winner per item; losing claim shows "Already taken" and suggests similar items; claim expires in 10 min if no contact |
| 5 | **Post flow (Giver)** | 1. Tap + → 2. Take/pick 1–3 photos → 3. AI drafts title/desc/category/value → 4. Edit a word → 5. Post | Photos, optional raw description | Local downscale to 1280px; AI draft (on-device first, cloud fallback); moderation pipeline → PASS / REVIEW / BLOCK | Listing appears in feed; block reason sheet with "how to fix" guidance | SwiftData `Item` + image files in Application Support; `ModerationLog` | AI draft fully populates 4 fields; BLOCK never publishes; AI offline → item enters REVIEW queue with clear "pending review" state |
| 6 | **Claim requests (Giver)** | 1. Notification/badge → 2. Open item → 3. Review claimants' trust badges → 4. Accept one | Claim list | Accept chosen claimant, release others with polite notification | Chat thread opens; accepted taker sees "You're in" | `Item.dibbedBy`, `Claim.result` | Accepting one auto-marks others LOST; giver can re-list after expire |
| 7 | **Confirmation loop** | 1. Giver taps "Mark Given" → 2. Taker taps "I received it" → 3. Both get +trust | Two taps | State machine LIVE→DIBBED→MEETING→GIVEN→DONE; 24h timeout job releases item back to LIVE | DONE item moves to My Hauls with saved amount; trust badges update | State persisted in SwiftData + CloudKit | Neither side alone can close the deal; 24h timeout re-lists the item automatically |
| 8 | **My Hauls** | 1. Profile → My Hauls → 2. Claimed / Given tabs → 3. See lifetime "Saved $X" → 4. Tap share | Local computed totals | Aggregate DONE claims, sum AI est. value, rank badges | Big saved-amount hero, item grid, share card | SwiftData aggregates + `UserProfile` | Saved total equals sum of completed claims; empty state shows FOMO copy |
| 9 | **Share card** | 1. Complete deal or tap Share on a haul → 2. Preview card → 3. System share sheet | Item photo + saved amount + brand | `ImageRenderer` composes 9:16 card (photo, "$X saved", Dibsly mark) → PNG | Share sheet with PNG | Temporary file in caches | Card renders without overflow, shares to Instagram/TikTok, no crash on missing photo |
| 10 | **Wanted (reverse post)** | 1. Wanted tab → 2. Photo or one sentence → 3. AI structures need → 4. Post | Photo / free text | AI parses into title + category + keywords; matcher scans new LIVE items for semantic overlap | Wanted card + match notifications | SwiftData `WantedPost` + `WantedMatch` | Posting a wanted item immediately matches existing listings with score ≥ threshold; new matching items notify |
| 11 | **In-app chat** | 1. After claim → 2. Open thread → 3. Send text → 4. Agree on place/time | Text | Message store; safety tips card auto-inserted on first message; scam-phrase lint warns user | Chat bubbles, safety card, report button | SwiftData `ChatMessage` + CloudKit | Chat works offline locally and syncs when iCloud available; first thread always shows Safety Tips; report creates moderation record |
| 12 | **Trust Score & badges** | 1. Profile → 2. See score + badge + event history | Trust events | Score engine: +3 give done, +2 claim done, +1 on time, −5 no-show, −20 scam; badge thresholds 10 / 50 / 100 | Badge chip across app (cards, detail, chat) | `UserProfile.trustScore`, `TrustEvent` | Score changes are always attributable to an event row; badges update live |
| 13 | **Safe exchange** | 1. Item detail → "Safe exchange" → 2. Map opens with safe zones → 3. Pick a public place | Item coordinate; optional MapKit search | MKLocalSearch for police stations / libraries / public plazas within 5km; sort by distance | Pins + suggestion list + checklist sheet | None (computed) | At least 3 suggestions in dense areas; checklist always reachable; map never reveals exact home coordinates |
| 14 | **AI assistant (drafting / valuation / moderation / matching)** | 1. Triggered by post, claim, wanted flows → 2. Result appears inline | Photos + text | Router: Apple Intelligence (iOS 26+, free, unlimited) → GLM cloud (Pro credits / BYO key) → local heuristic fallback | Drafted listing, valuation, verdict, matches | `AIConfiguration` in Keychain/UserDefaults; no keys in git | No feature ever dead-ends when AI is unavailable — heuristic fallback always returns a usable result |
| 15 | **Paywall (Pro + credits)** | 1. Trigger after first successful dibs (24h later) or from Settings → 2. Compare Free / Pro → 3. Purchase → 4. Unlock | Product choice | StoreKit 2 purchase, restore, entitlement sync; credits consumable balance | Pro badge, unlocked real-time alerts / quick-grab window / unlimited posting | StoreKit entitlement mirrored to `UserProfile.isPro`, credits in Keychain/UserDefaults | Legal links (Privacy + Terms) always visible; purchase restore works; prices come from StoreKit, never hardcoded |
| 16 | **Settings & support** | 1. Settings → 2. Notifications, location privacy, AI config, subscription management, policies, contact | Toggles, text | Preferences stored; contact form posts to feedback backend | Confirmation toasts; support email flow | UserDefaults + backend | Every toggle persists across relaunch; support form shows validation + success/error states |
| 17 | **Empty / offline states** | 1. No items nearby → 2. See FOMO copy + refresh → 3. Offline → 4. See cached feed | — | Freshness check, cached snapshot | "Stuff gets posted every few minutes near you" + counter; offline banner | SwiftData cache | Never shows a blank white screen; offline still browsable |

### Sub-Features & Detail Interactions

| # | Parent | Sub-Feature | Detail Description | Interaction Pattern |
|---|---|---|---|---|
| 4.1 | Item detail | Worth ribbon | `$0 · worth ~$240` chip over photo, "AI estimate, not an appraisal" microcopy | Tap to expand explanation |
| 4.2 | Item detail | Distance + freshness | "0.8 mi · 12 min ago" | Auto-updating |
| 4.3 | Item detail | Priority claim countdown | 60s bar turns red for items ≥ $150 | Animated progress bar |
| 5.1 | Post flow | AI auto-fill | Title/description/category/value filled within ~2s | Inline "AI drafted • edit freely" chip |
| 5.2 | Post flow | Block guidance | Friendly reason + concrete fix suggestion | Sheet with retry |
| 8.1 | My Hauls | Saved hero | Cumulative "Saved $X" with count-up animation | Tap → breakdown |
| 9.1 | Share card | Brand watermark | Dibsly mark + "call dibs" tagline | Share sheet |
| 11.1 | Chat | Safety tips card | Auto-inserted: meet in public, daylight, tell a friend | Static card, dismissible |
| 11.2 | Chat | Scam lint | Warns on venmo/zelle/shipping/deposit phrasing | Inline warning banner |
| 13.1 | Safe exchange | Checklist | Bring a friend, tell someone, don't go inside alone, phone charged | Checklist sheet |
| 15.1 | Paywall | Missed-items hook | "You missed N items today" computed locally | Animated number |
| 16.1 | Settings | AI configuration | Apple Intelligence status, GLM status, BYO key entry, test button | Form + connection test |

### Cross-Feature Dependencies

| Dependency | Source | Target | Data Passed | Trigger |
|---|---|---|---|---|
| Post → Feed | Post flow | Map/List feed | New `Item` (LIVE) | Moderation PASS |
| Claim → Chat | DIBS | Chat | itemID, giverID, takerID | Claim WIN |
| Claim → My Hauls | DIBS | My Hauls | Claim + item value | Claim WIN |
| Given/Received → Trust | Confirmation loop | Profile badge | TrustEvent delta | Both confirmations |
| Wanted → Matcher | Wanted | Feed / notifications | Keywords, category | New LIVE item inserted |
| AI valuation → Share card | Valuation | Share card | estValueCents | Deal DONE |
| Purchase → Feature gates | Paywall | Alerts / posting limits | `isPro`, credits | Transaction verified |

## Apple Design Guidelines Compliance

- **HIG — Maps**: MapKit standard style, user location control, compass; pins are tappable custom annotations with 44pt targets.
- **HIG — Navigation**: TabView with 5 tabs (Nearby, Wanted, Post, Hauls, Profile); primary actions in the bottom third thumb zone.
- **HIG — Dark Mode**: Full support via semantic colors; brand green/orange tuned for both appearances.
- **HIG — Dynamic Type**: All text uses system text styles; no fixed font sizes in body text.
- **HIG — Privacy**: Precise coordinates never uploaded; only geohash-5 + city; location purpose string explains "to show free stuff near you".
- **HIG — Haptics**: Heavy impact on claim success, success notification on deal close.
- **App Review 1.2 (UGC)**: Report, block, and moderation queue are mandatory and always reachable; 24h response commitment documented.
- **App Review 3.1.2**: Paywall shows title, length, price, auto-renew disclosure, Privacy + Terms links, Restore Purchases.
- **App Review 5.1.1**: Permission prompts are pre-explained; no contact-list access.

## ⚠️ App Store Compliance — AI Features

### Apple Intelligence (default free backend)
On iOS 26+ devices with Apple Intelligence, listing drafting, query expansion, and share-card copy run on-device for free and unlimited. On older devices the app falls back to a deterministic local heuristic (template + keyword extraction) and optionally cloud AI.

- Never render a AI button that dead-ends: every AI entry point has a deterministic fallback.
- No `freeGenerationsUsed` counters, no hidden quotas. Pro gating applies to cloud AI credits only, which are consumable IAP.

### BYO API Key (optional)
Settings → AI lets users store their own GLM / OpenAI / Claude / Gemini / DeepSeek / custom OpenAI-compatible key (Keychain only). BYO users get unlimited cloud AI and never consume platform credits.

### Cloud AI (GLM) — cost rule
Built-in cloud AI is **only** available to Pro subscribers / credit holders. There is **no lifetime unlimited cloud AI** design. On-device AI (free tier) is unlimited by design because it has zero marginal cost.

## ⚠️ App Store Compliance — Subscriptions

- Products: Pro Monthly $4.99 (7-day trial), Pro Yearly $34.99, Pro Lifetime $59.99, Credits 100 × $2.99, Credits 500 × $9.99.
- Paywall must include: product title, length, price (from StoreKit), auto-renew disclosure, Privacy Policy link, Terms of Use (EULA) link, Restore Purchases, and Manage Subscription deep link.
- Cancellation reminder is surfaced in Settings; billing details page lists what Pro includes.

## Technical Architecture

- **Language**: Swift 5.9+ (Swift 6 concurrency-safe where practical)
- **UI**: SwiftUI + MVVM with `@Observable` view models
- **Data**: SwiftData (local-first source of truth) + CloudKit public database for community sync (entitlement-gated, graceful degradation)
- **Maps**: MapKit (`Map`, `Annotation`, `MKLocalSearch`)
- **AI**: `FoundationModels` (iOS 26, `@available` guarded) + `AIService` protocol with GLM / OpenAI-compatible providers + local heuristic fallback
- **Payments**: StoreKit 2 (`Product`, `Transaction`, `AppStore.sync`)
- **Images**: PhotosUI, local downscale, `ImageRenderer` for share cards
- **Notifications**: UserNotifications local notifications (claim, expiry, match)
- **No third-party dependencies** — confetti, shimmer, and chat UI are hand-built to keep the project buildable offline

### Why local-first + CloudKit (instead of a required Supabase project)
The app must work the moment it is downloaded from the App Store. SwiftData is the source of truth; CloudKit's public database provides the real cross-device community feed with zero external server credentials. If iCloud is unavailable (simulator, signed-out device), the app degrades to a fully functional single-device mode instead of showing a broken login wall.

## Module Structure

```
Dibsly/
├── App/
│   ├── DibslyApp.swift
│   └── AppEnvironment.swift
├── Models/
│   ├── Item.swift
│   ├── Claim.swift
│   ├── ChatMessage.swift
│   ├── UserProfile.swift
│   ├── TrustEvent.swift
│   ├── WantedPost.swift
│   ├── ModerationLog.swift
│   └── Enums.swift
├── Services/
│   ├── LocationService.swift
│   ├── Geohash.swift
│   ├── CloudKitService.swift
│   ├── AIService.swift
│   ├── AIProviders.swift
│   ├── ModerationService.swift
│   ├── TrustService.swift
│   ├── PurchaseService.swift
│   ├── NotificationService.swift
│   ├── ShareCardRenderer.swift
│   ├── ContactSupportService.swift
│   └── ImageStore.swift
├── ViewModels/
│   ├── FeedViewModel.swift
│   ├── PostItemViewModel.swift
│   ├── ItemDetailViewModel.swift
│   ├── HaulsViewModel.swift
│   ├── WantedViewModel.swift
│   ├── ChatViewModel.swift
│   ├── ProfileViewModel.swift
│   └── PaywallViewModel.swift
├── Views/
│   ├── Onboarding/OnboardingView.swift
│   ├── Feed/FeedMapView.swift, FeedListView.swift, ItemCardView.swift, PinCardView.swift
│   ├── Detail/ItemDetailView.swift, ClaimSuccessView.swift
│   ├── Post/PostItemView.swift, PhotoPicker.swift
│   ├── Hauls/MyHaulsView.swift, ShareCardView.swift
│   ├── Wanted/WantedView.swift
│   ├── Chat/ChatView.swift, SafetyTipsCard.swift
│   ├── Profile/ProfileView.swift, TrustBadgeView.swift
│   ├── Paywall/PaywallView.swift
│   ├── Settings/SettingsView.swift, AIConfigView.swift, SafeExchangeView.swift
│   └── Components/ (chips, buttons, empty states, confetti)
└── Resources/
    ├── Assets.xcassets
    ├── PrivacyInfo.xcprivacy
    └── Info.plist keys (location, camera, photo library)
```

## ⚠️ Data Flow Diagram

```
Feature: Post Item
User photos (PhotosPicker / camera)
  → ImageStore.downscale(1280px) → save to Application Support
  → PostItemViewModel.draftAI() → AIService (Apple Intelligence → GLM/BYO → heuristic)
  → ModerationService.evaluate(photo, text) → PASS / REVIEW / BLOCK
  → PASS: SwiftData Item(status: .live) + CloudKitService.publish(item)
  → FeedViewModel observes ModelContext changes → map/list refresh
  → Summary: photo → local file → AI draft → verdict → persisted item → feed pin
```

```
Feature: Call Dibs
ItemDetail DIBS! tap
  → ItemDetailViewModel.claim() builds clientUUID (idempotency key)
  → CloudKitService.tryLock(item) (optimistic record save, .ifServerRecordUnchanged)
      success → Item.status = .dibbed, dibsExpiresAt = now+10m, Claim(WIN), TrustEvent
      conflict → Claim(LOST), UI shows "Already taken" + similar items
  → NotificationService schedules 10-min expiry check
  → ClaimSuccessView (confetti + haptic) → Chat thread created → My Hauls entry
```

```
Feature: Deal close & trust
Giver "Mark Given" → Item.status = .given (timestamp)
  → Taker "I received it" (only enabled after GIVEN) → .done
  → TrustService.apply(+3 giver / +2 taker) → TrustEvent rows → badge recompute
  → HaulsViewModel recomputes saved total → ShareCardRenderer renders PNG → share sheet
```

```
Feature: Wanted
Photo/text → AIService.structureNeed → WantedPost(keywords, category)
  → Matcher scans LIVE items (title/desc/category overlap score)
  → match score ≥ 0.6 → WantedMatch + local notification
```

## Implementation Flow

1. App shell: SwiftData container, environment, tab structure, design tokens.
2. Location + geohash + onboarding gate.
3. Models + Item CRUD + seed-free empty states.
4. Feed (map + list), item cards, filtering.
5. Post flow with photo pipeline and AI drafting.
6. Moderation pipeline with fallback and review queue.
7. DIBS claim, idempotency, expiry timers, celebration.
8. Chat with safety card and scam lint.
9. Confirmation loop + trust engine + badges.
10. My Hauls + share card renderer.
11. Wanted + matcher.
12. Safe exchange map + checklist.
13. StoreKit 2 paywall, credits, restore, manage subscription.
14. CloudKit public-DB sync + subscriptions (graceful degradation).
15. Settings, AI config (BYO key), contact support, policy links.
16. Polish: haptics, confetti, empty states, dark mode, accessibility labels.
17. Build on iPhone + iPad simulators, fix warnings, run smoke test.

## UI/UX Design Specifications

- **Colors**: Dibs Green `#16C784` (primary, trust + money), Sunset Orange `#FF6B35` (DIBS button, countdown urgency), Ink `#101418`, Fog `#F4F6F8`, dark surfaces `#16191D` / `#1E2328`.
- **Typography**: SF Pro Rounded for numbers/buttons/hero; system text styles for body; Dynamic Type everywhere.
- **Layout**: Full-bleed map home; bottom sheet item card; single-column large-photo list; primary actions in thumb zone; 20pt outer margins; 16pt card radius; soft shadows only in light mode.
- **Pins**: rounded-square thumbnail (56pt) + value ribbon; clustered by geohash cell; fuzzed coordinates.
- **Motion**: Dibs success = scale bounce + confetti + heavy haptic; countdown bar = red gradient shrink; card transitions = spring; list load = subtle staggered fade.
- **Empty states**: FOMO copy + live counter feel ("Stuff gets posted every few minutes near you").
- **Dark mode**: first-class, not an afterthought; glassy sheets; green stays legible on `#16191D`.

## Code Generation Rules

1. SwiftUI + MVVM + `@Observable`; no UIKit except necessary pickers (use PhotosUI).
2. `async/await` everywhere; one `APIClient`-style boundary per external service.
3. All writes idempotent via client-generated UUIDs.
4. Item status transitions are centralized in `ItemStateMachine` — views never mutate status directly.
5. AI routing on-device first; cloud only for Pro/credits/BYO; local heuristic fallback is mandatory.
6. Local-first persistence: every read has a cached answer; network failure must never block the core loop.
7. Secrets: BYO keys and tokens in Keychain only, never logged, never committed.
8. Images: compress on ingest, downsample on display; no full-resolution decoding in lists.
9. Notifications: opt-in, explainable, globally disableable.
10. Privacy: geohash-5 + city only; exact coordinates stay on device.
11. No third-party Swift packages (keeps builds reproducible; hand-roll confetti and chat).
12. Version strings read from `Bundle.main.infoDictionary`, never hardcoded.

## Build & Deployment Checklist

- [ ] `xcodegen` project generated with app target + iCloud entitlement
- [ ] Info.plist: `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`
- [ ] PrivacyInfo.xcprivacy declares location + user content collection
- [ ] StoreKit configuration file for local testing of 5 products
- [ ] Build green on iPhone and iPad simulators
- [ ] Table-driven smoke test: onboarding → feed → post → dibs → chat → given/received → share → paywall
- [ ] GitHub repo pushed with policy pages in `/docs`
- [ ] keytext.md (ASO, gitignored) generated
- [ ] capabilities.md manual checklist completed
