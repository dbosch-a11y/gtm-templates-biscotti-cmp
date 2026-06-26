# Biscotti CMP - Google Tag Manager Consent Mode Template

A Google Tag Manager Community Template that implements **Google Consent Mode v2** for websites using [Biscotti CMP](https://biscotti-cmp.com). This template reads consent state from Biscotti's localStorage, sets denied defaults before any tags fire, and updates consent signals in real time as visitors interact with the consent banner.

## Prerequisites

Before installing this template, ensure:

1. **Active Biscotti CMP account** — You must have a configured consent banner at [biscotti-cmp.com](https://biscotti-cmp.com) with a Website ID assigned to your domain.
2. **Biscotti client script loaded on the page** — The Biscotti client script (`biscotti.min.js`) must be loaded on your website, either:
   - Directly in your HTML (recommended): `<script src="https://api.biscotti-cmp.com/scripts/biscotti.min.js" data-biscotti-account="YOUR_WEBSITE_ID"></script>`
   - Via this template's optional "Load Biscotti script via GTM" setting
   - Via a separate Custom HTML tag in GTM

## Installation

### Step 1: Find the Template in the Gallery

1. Open your GTM container and navigate to **Templates** in the left sidebar.
2. Click **Search Gallery** in the Tag Templates section.
3. Search for **"Biscotti CMP"** and select the template.

### Step 2: Add to Workspace

1. Click **Add to workspace** on the template detail page.
2. Confirm the permissions dialog.

### Step 3: Create a New Tag

1. Go to **Tags** → **New**.
2. Under Tag Configuration, select **Biscotti CMP - Consent Mode** from the Community Template list.

### Step 4: Configure the Website ID

1. Enter your **Biscotti Website ID** in the configuration field. You can find this in your Biscotti dashboard under Account Settings.
2. Configure optional settings as needed (see [Configuration Options](#configuration-options) below).

### Step 5: Select the Trigger

1. Under Triggering, click to add a trigger.
2. Select **"Consent Initialization - All Pages"**.

> ⚠️ **Important:** You MUST use the "Consent Initialization - All Pages" trigger. See [Trigger Configuration](#trigger-configuration) for details.

### Step 6: Publish

1. Save the tag.
2. Use **GTM Preview mode** to verify the template is working correctly.
3. Once verified, **Submit** and **Publish** your container.

## Configuration Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `websiteId` | Text | _(empty)_ | Your Biscotti Website ID. Required if using the script injection option. |
| `defaultSettings` | Table | _(empty)_ | Region-specific default consent settings. Columns: `region` (ISO 3166-2 codes), `granted` (consent types), `denied` (consent types). |
| `waitForUpdate` | Number | `500` | Milliseconds to wait for the Biscotti client to load and provide consent before Google tags fire with defaults. |
| `enableTcfSupport` | Checkbox | `false` | When enabled, sets `gtag_enable_tcf_support` so Google tags read the IAB TC String and Additional Consent directly from the CMP. Enable only if Biscotti's IAB TCF mode is active. |
| `adsDataRedaction` | Checkbox | `false` | When enabled, redacts ad click identifiers in network requests when `ad_storage` is denied. |
| `urlPassthrough` | Checkbox | `false` | When enabled, passes ad click information via URL parameters when cookie storage is denied. |
| `injectBiscottiScript` | Checkbox | `false` | When enabled (and Website ID is provided), loads the Biscotti client script via GTM instead of requiring it in your HTML. |

## Category Mapping

The template maps Biscotti's consent categories to Google Consent Mode v2 signals as follows:

| Biscotti Category | Google Consent Mode v2 Signal | Default State |
|-------------------|-------------------------------|---------------|
| `marketing = true` | `ad_storage = granted` | `denied` |
| `marketing = true` | `ad_user_data = granted` | `denied` |
| `marketing = true` | `ad_personalization = granted` | `denied` |
| `analytics = true` | `analytics_storage = granted` | `denied` |
| `functional = true` | `functionality_storage = granted` | `denied` |
| `functional = true` | `personalization_storage = granted` | `denied` |
| _(always)_ | `security_storage = granted` | `granted` |

**How it works:**

- When a visitor **denies** a category (or has not yet interacted with the banner), the corresponding signals remain `denied` and Google tags will operate in cookieless/restricted mode.
- When a visitor **grants** a category, the signals switch to `granted` and Google tags operate normally.
- `security_storage` is always `granted` as it covers essential security features (e.g., authentication, fraud prevention).

## Region-Specific Defaults

You can configure different default consent states for specific geographic regions using the **Default Consent Settings** table. This is useful for applying stricter defaults only in regions where regulations require it (e.g., EU/EEA) while allowing granted defaults elsewhere.

### How to Configure

Add rows to the `defaultSettings` table with:

- **Region**: Comma-separated [ISO 3166-2](https://en.wikipedia.org/wiki/ISO_3166-2) codes (country or country-subdivision)
- **Granted**: Comma-separated consent types to default to `granted`
- **Denied**: Comma-separated consent types to default to `denied`

### Examples

| Region | Granted | Denied |
|--------|---------|--------|
| `DE, AT, CH` | _(empty)_ | `ad_storage, ad_user_data, ad_personalization, analytics_storage, functionality_storage, personalization_storage` |
| `US` | `analytics_storage, functionality_storage` | `ad_storage, ad_user_data, ad_personalization` |

- If **no regions** are configured, the template applies a global default of all signals `denied` (except `security_storage`).
- If regions **are** configured, only visitors from those regions receive the specified defaults. Visitors from other regions receive the global fallback.

## Ads Data Redaction & URL Passthrough

### Ads Data Redaction (`ads_data_redaction`)

When enabled and `ad_storage` is `denied`, Google Ads and Floodlight tags will redact ad click identifiers (e.g., `gclid`, `dclid`) from network requests. This provides an additional layer of privacy protection.

**When to enable:** Recommended for all websites serving EU/EEA visitors to ensure compliance with data minimization principles.

### URL Passthrough (`url_passthrough`)

When enabled and cookie storage is `denied`, Google tags will pass ad click information (e.g., `gclid`) and client/session IDs via URL parameters instead of cookies. This preserves measurement continuity for conversion tracking without storing cookies.

**When to enable:** Enable this if you need to maintain conversion measurement accuracy for Google Ads campaigns while respecting users who deny cookie storage.

## IAB TCF Support (for Google tags)

Biscotti CMP is a registered IAB Europe TCF Consent Management Platform. If you have enabled Biscotti's IAB TCF mode, also enable the **"Enable IAB TCF support for Google tags"** option in this template.

When enabled, the template sets `gtag_enable_tcf_support = true`. Google tags (Google Ads, Floodlight, GA4) then read the IAB **TC String** and Google **Additional Consent (AC) String** directly from `window.__tcfapi`, which the Biscotti client registers (including the `addtlConsent` field). This is the mechanism Google documents for [TCF string support on websites](https://developers.google.com/tag-platform/security/guides/implement-TCF-strings#website).

> The template also exposes `biscotti_tcf_string` and `biscotti_ac_string` on the dataLayer for your own TCF-aware custom tags. Google's own tags do **not** read those dataLayer keys — they rely on the `gtag_enable_tcf_support` flag above.

**When to enable:** Only when Biscotti's TCF mode is active. Leaving it on without an active `__tcfapi` may cause Google tags to wait for a TCF signal that never arrives.

## Trigger Configuration

> ⚠️ **Critical: You MUST use the "Consent Initialization - All Pages" trigger.**

This template **must** be triggered on **"Consent Initialization - All Pages"** — the built-in GTM trigger that fires before all other triggers, including "Initialization - All Pages" triggers.

### Why This Trigger is Required

Google Tag Manager processes triggers in this order:

1. **Consent Initialization** — Fires first, before anything else
2. **Initialization** — Fires second
3. **All Pages / DOM Ready / Window Loaded** — Fire after initialization

If you use any other trigger (e.g., "Initialization - All Pages" or "All Pages"), your consent defaults will NOT be set before other tags fire. This means:

- Google Analytics, Google Ads, and other tags may fire **without consent defaults**
- Tags will behave as if consent is `granted` for all signals
- Your website will **not be compliant** with GDPR, ePrivacy, or Google's EU User Consent Policy

### How to Verify

In GTM Preview mode:

1. Open the **Consent** tab in the debugger.
2. Verify that consent defaults appear at the "Consent Initialization" event (before "Container Loaded").
3. All signals should show `denied` (except `security_storage`) before any tags fire.

## Troubleshooting

### Consent not updating after user interaction

**Symptom:** The consent banner works, but Google tags don't respond to consent changes.

**Cause:** The Biscotti client script is not loaded on the page, or it loaded after the template.

**Solution:**
- Verify `biscotti.min.js` is loaded in your page source (check Network tab in DevTools).
- Ensure the script loads early — ideally in the `<head>` section.
- Alternatively, enable "Load Biscotti script via GTM" in the template configuration.

### Template not firing or firing too late

**Symptom:** Consent defaults are not set before other tags fire.

**Cause:** Wrong trigger assigned to the template.

**Solution:**
- Open the tag configuration and verify the trigger is **"Consent Initialization - All Pages"** (not "Initialization - All Pages" or "All Pages").
- In GTM Preview, check that the template appears under the "Consent Initialization" event.

### localStorage access errors

**Symptom:** Template logs errors about localStorage access.

**Cause:** Browser privacy settings, incognito mode, or third-party cookie blocking may restrict localStorage access.

**Solution:**
- This is expected behavior in strict privacy modes. The template will retain denied defaults (fail-safe behavior).
- No action needed — the template handles this gracefully.

### Verifying in GTM Preview Mode

To confirm the template is working correctly:

1. Enable **GTM Preview mode** and load your website.
2. In the GTM debugger, click on the **"Consent Initialization"** event in the timeline.
3. Check the **Consent** tab — you should see all 7 consent signals with their default values.
4. Interact with the Biscotti consent banner on your page.
5. A new **"Consent Update"** event should appear in the timeline.
6. Click it and verify the consent signals updated according to your choices.
7. Check the **Data Layer** tab for `biscotti_consent_initialized` and `biscotti_consent_update` events.

## EU User Consent Policy

This template helps websites comply with [Google's EU User Consent Policy (EUUCP)](https://www.google.com/about/company/user-consent-policy/), which requires:

- Obtaining legally valid consent from users in the EU/EEA and UK before using cookies or collecting personal data for advertising
- Providing clear information about data collection and usage
- Implementing Google Consent Mode to signal consent state to Google services

By using Biscotti CMP with this template, your website:

- Sets all advertising and analytics signals to `denied` by default until consent is obtained
- Updates consent signals in real time when users make choices
- Supports granular consent (users can accept analytics but deny marketing)
- Passes consent state to all Google tags in the container via Consent Mode v2

For full EUUCP compliance, ensure your Biscotti consent banner is configured with appropriate legal text and consent categories for your jurisdiction.

## License

This template is licensed under the [Apache License 2.0](LICENSE).

## Support

- **Documentation:** [biscotti-cmp.com/docs/integrations/gtm](https://biscotti-cmp.com/docs/integrations/gtm)
- **Website:** [biscotti-cmp.com](https://biscotti-cmp.com)
- **Issues:** [GitHub Issues](https://github.com/dbosch-a11y/gtm-templates-biscotti-cmp/issues)
- **Email:** support@biscotti-cmp.com
