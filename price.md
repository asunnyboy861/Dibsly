# Pricing Configuration

## Monetization Model: Freemium with Subscription + One-Time Purchase + Consumable Credits

Free download with no hard paywall. Dibsly Pro unlocks speed, unlimited volume and unlimited on-device AI via auto-renewable monthly/yearly plans or a one-time lifetime purchase. Cloud AI (GLM vision + reasoning) is a metered consumable and is never sold as unlimited.

## Subscription Group
- **Group Name**: Dibsly Pro
- **Reference Name**: Dibsly Pro
- **Products in group**: Dibsly Pro Monthly, Dibsly Pro Annual

## Subscription Tiers (Auto-Renewable)

### 1. Monthly Subscription
- **Reference Name**: Dibsly Pro Monthly
- **Product ID**: `com.zzoutuo.Dibsly.pro.monthly`
- **Type**: Auto-renewable subscription
- **Price**: $4.99 USD per month
- **Display Name**: `Dibsly Pro Monthly` (18 chars, ≤35 ✅)
- **Description**: `Unlimited alerts, quick-grab windows, unlimited posts` (53 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: Dibsly Pro
- **Restore Purchases**: ✅ Required

### 2. Yearly Subscription
- **Reference Name**: Dibsly Pro Annual
- **Product ID**: `com.zzoutuo.Dibsly.pro.yearly`
- **Type**: Auto-renewable subscription
- **Price**: $34.99 USD per year (42% savings vs monthly)
- **Display Name**: `Dibsly Pro Annual` (17 chars, ≤35 ✅)
- **Description**: `Best value. All Pro speed tools for a full year.` (48 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: Dibsly Pro (same group as monthly)
- **Restore Purchases**: ✅ Required

## One-Time Purchases (Non-Consumable)

### 1. Pro Lifetime
- **Reference Name**: Dibsly Pro Lifetime
- **Product ID**: `com.zzoutuo.Dibsly.pro.lifetime`
- **Type**: Non-consumable (one-time purchase, permanently unlocked)
- **Price**: $59.99 USD (one-time)
- **Display Name**: `Dibsly Pro Lifetime` (19 chars, ≤35 ✅)
- **Description**: `Pay once. All Pro features forever, no renewal.` (47 chars, ≤55 ✅)
- **Localization**: English (US)
- **Restore Purchases**: ✅ Required
- **⚠️ Differentiation Note**: Lifetime unlocks every Pro feature permanently but does **not** include cloud AI credits (those are consumable and priced separately). It exists for users who prefer a single payment over a subscription anchor.
- **Note**: Pro features (alerts, quick-grab window, unlimited posting, on-device AI) carry no ongoing server cost, so a lifetime purchase is structurally sustainable.

## Consumable Purchases (Cloud AI Credits)

Credits are spent only on cloud AI tasks (listing photo moderation, market valuation, Wanted deep matching, chat scam screening). On-device Apple Intelligence never consumes credits.

### 1. AI Credits 100
- **Reference Name**: Dibsly AI Credits 100
- **Product ID**: `com.zzoutuo.Dibsly.credits.100`
- **Type**: Consumable
- **Price**: $2.99 USD
- **Display Name**: `100 AI Credits` (14 chars, ≤35 ✅)
- **Description**: `100 cloud AI tasks: moderation, valuation, matching.` (52 chars, ≤55 ✅)
- **Localization**: English (US)

### 2. AI Credits 500
- **Reference Name**: Dibsly AI Credits 500
- **Product ID**: `com.zzoutuo.Dibsly.credits.500`
- **Type**: Consumable
- **Price**: $9.99 USD
- **Display Name**: `500 AI Credits` (14 chars, ≤35 ✅)
- **Description**: `500 cloud AI tasks at the best per-task price.` (46 chars, ≤55 ✅)
- **Localization**: English (US)

## Free Tier (Default)

- **Price**: Free
- **Features**:
  - Browse the map and list feed without limits
  - 3 keyword alert batches per day
  - Basic category filter
  - 1 active Giver post per day
  - 5 on-device AI listing drafts per month
  - In-app chat with every claim (free — chat is the trust foundation)
- **Conversion hooks**:
  - "You missed N items today" counter computed from your own nearby feed
  - "Estimated value around you today: $X" live banner
  - Quick-grab countdown visible but locked on high-value items

## Pro Features Unlocked (All Paid Tiers)

| Feature | Free | Pro (Monthly / Annual / Lifetime) |
|---------|:----:|:---------------------------------:|
| Map + list browsing | Unlimited | Unlimited |
| Real-time dibs alerts | 3/day batch | Instant, unlimited |
| Quick-grab window (60s) on items ≥ $150 | ❌ Locked | ✅ Priority claim |
| Posting limit | 1 active post/day | Unlimited posts + Wanted posts |
| Filters (distance / category / value) | Basic | Unlimited |
| On-device AI drafting & valuation | 5/month | Unlimited |
| Cloud AI credits | ❌ Not included — separate consumable | ❌ Not included — separate consumable |
| Ads | None (no ads at all) | None |
| Trust badge acceleration | Standard | Legend fast-track |

## Free Trial
- **Duration**: 7 days
- **Type**: Free trial (auto-converts to paid subscription)
- **Available for**: Monthly and Annual tiers (one trial per subscription group)

## BYO Key Model: Premium Features Unlock

- Users who configure their own GLM / OpenAI / Claude / Gemini / DeepSeek key get **unlimited cloud AI** and never spend credits.
- BYO does not bypass the free-tier posting/alert limits — Pro still unlocks app features.
- Subscription value is described as "faster alerts, quick-grab, unlimited posting", never as "unlimited AI generations".

## Policy Pages Required
- Support Page: ✅ (must include subscription management + cancellation instructions)
- Privacy Policy: ✅
- Terms of Use (EULA): ✅ (required — auto-renewable subscriptions)
- **Total policy pages**: 3

## Apple IAP Compliance Checklist
- [x] Auto-renewal terms will be included in Terms of Use
- [x] Cancellation instructions will be included in Support Page
- [x] Pricing clearly stated in PaywallView (fetched from StoreKit, never hardcoded)
- [x] Free trial terms included (7 days, monthly + annual)
- [x] Restore purchases functionality implemented (StoreKit 2 `Transaction.currentEntitlements`)
- [x] No external payment links (Guideline 3.1.1)
- [x] No price references to outside-App-Store options
- [x] All IAP descriptions ≤ 55 characters
- [x] All IAP display names ≤ 35 characters
- [x] Consumables are kept in their own section — never mixed with subscriptions or lifetime
- [x] Lifetime product explicitly states that cloud AI credits are NOT included
