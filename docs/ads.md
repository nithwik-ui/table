# AdMob Integration & Policy — SRU Timetable 3.0

## 1. Absolute Policy
- **Banner Ads ONLY**: No interstitials, rewarded ads, app-open ads, or modal popups.
- **Controlled Lifecycle**: Single banner instance created per screen/dashboard; retained across tab switches.
- **No Build Thrashing**: Banners must not be reloaded on `setState()`, widget rebuilds, or tab changes.

## 2. Metrics & Audit
- Target: Request count closely aligning with actual impressions (ratio near 1:1, avoiding the prior 2.59K requests to 823 impressions gap).
- `launchMode="singleTask"` configured in Android manifest to prevent duplicate task stacks or black screens when returning to the app from ad interactions.
