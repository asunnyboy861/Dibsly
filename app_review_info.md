# App Review Information

## Demo Account

Dibsly has no sign-in wall. Every reviewer starts as an anonymous "Neighbor" profile, so **no demo account or password is required**.

## How to reach the core loop in under 60 seconds

1. Launch the app.
2. Tap **Enable location and start** (or **Not now, browse a sample city**).
3. Tap **Post** in the tab bar.
4. Tap **Add** and pick one photo.
5. Type "gray sofa" in **Say what it is** and tap **AI draft title, details and value**.
6. Tap **Post to the neighborhood**.
7. Return to **Nearby**, switch to list view, and tap the created card.

Because dibs cannot be called on your own listing, claim flow is exercised on a second device/account, or by using the community feed populated through CloudKit by other users.

## AI Configuration

Dibsly has three AI engines, in priority order:

1. **Apple Intelligence** — on-device Foundation Models, iOS 26+, iPhone 15 Pro or later. Free and unlimited. Available on reviewer devices without any setup.
2. **Bring your own API key** — Settings → AI → paste a key from GLM, OpenAI-compatible, DeepSeek, Gemini (compatible), Claude, or any custom OpenAI-compatible endpoint. The key is stored in the iOS Keychain only.
3. **On-device heuristic rules** — always available deterministic fallback (keyword classification, value bands, moderation term lists). Every AI surface works with this engine, so no button dead-ends.

There is **no free-generation counter** and no hidden AI quota. Cloud credits are a consumable IAP used only for cloud moderation/valuation when no BYO key is configured.

## Subscription Testing

| Product | ID | Price |
|---|---|---|
| Pro Monthly (7-day trial) | `com.zzoutuo.Dibsly.pro.monthly` | $4.99 / month |
| Pro Annual | `com.zzoutuo.Dibsly.pro.yearly` | $34.99 / year |
| Pro Lifetime | `com.zzoutuo.Dibsly.pro.lifetime` | $59.99 once |
| Credits 100 | `com.zzoutuo.Dibsly.credits.100` | $2.99 |
| Credits 500 | `com.zzoutuo.Dibsly.credits.500` | $9.99 |

Restore Purchases and Manage Subscription are available in Settings and on the paywall.

## Required Links (in-app)

- Privacy Policy: https://asunnyboy861.github.io/Dibsly/privacy.html
- Terms of Use: https://asunnyboy861.github.io/Dibsly/terms.html
- Support: https://asunnyboy861.github.io/Dibsly/support.html

Links appear in **Settings → Legal** and on the paywall beneath the purchase button.

## Review Notes

### User generated content
This app is a UGC marketplace for free household items. It includes:
- an AI gatekeeper that blocks prohibited categories and flags commercial/scam phrasing before a listing goes live,
- a human review queue for low-confidence listings,
- per-listing **Report** action (top-right menu),
- community chat, with a scam-phrase warning and a permanent safety card,
- a 24-hour support response commitment.

### Location
Dibsly requests When-In-Use location only, to show nearby listings. The app stores a coarse geohash-5 grid plus city and uploads only blurred coordinates (±300 m). Exact coordinates are never transmitted or displayed. Location can be declined and the app continues with a sample city.

### Notifications
Notifications are opt-in, requested contextually after the first successful dibs, and can be disabled in Settings.

### Payments
All payments use StoreKit 2. No external purchase links exist. The paywall shows product title, length, price, auto-renewal disclosure, Privacy Policy, Terms of Use, Restore Purchases and Manage Subscription.

### Privacy
No contact list, no tracking, no third-party analytics SDKs, no advertising. Photos and chat content are used only to provide the service. Privacy manifest declares UserDefaults, file timestamp, coarse location, photos and user content.
