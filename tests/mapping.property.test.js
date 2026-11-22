/**
 * 2.0.0 standalone property tests. The contract block below is the SAME
 * generated code embedded in template.tpl (scripts/build-gtm-template-package.mjs
 * renderSandboxContract) — no hand-maintained mirror can drift from it.
 */
import { describe, expect, it } from 'vitest';
import fc from 'fast-check';

// BEGIN GENERATED CONTRACT — src/contract.js; do not edit in template.tpl

const ALL_CONSENT_TYPES = [
  "ad_storage",
  "ad_user_data",
  "ad_personalization",
  "analytics_storage",
  "functionality_storage",
  "personalization_storage",
  "security_storage"
];

const DEFAULT_WAIT_FOR_UPDATE = 500;

const MAX_WAIT_FOR_UPDATE = 10000;

function splitCsv(input) {
  if (!input || typeof input !== 'string') return [];
  var out = [];
  input.split(',').forEach(function (raw) {
    var value = raw.trim();
    if (value && out.indexOf(value) === -1) out.push(value);
  });
  return out;
}

function parseConsentTypes(input) {
  var values = splitCsv(input);
  for (var i = 0; i < values.length; i += 1) {
    if (ALL_CONSENT_TYPES.indexOf(values[i]) === -1) {
      return { ok: false, error: 'Unknown consent type: ' + values[i], values: [] };
    }
  }
  return { ok: true, error: null, values: values };
}

function parseRegions(input) {
  var raw = splitCsv(input);
  var values = [];
  for (var i = 0; i < raw.length; i += 1) {
    var value = raw[i].toUpperCase();
    if (!/^[A-Z]{2}(?:-[A-Z0-9]{1,3})?$/.test(value)) {
      return { ok: false, error: 'Invalid ISO 3166-2 region: ' + raw[i], values: [] };
    }
    if (values.indexOf(value) === -1) values.push(value);
  }
  if (values.length === 0) {
    return { ok: false, error: 'A regional default row needs at least one region', values: [] };
  }
  return { ok: true, error: null, values: values };
}

function resolveWaitForUpdate(value) {
  if ((typeof value !== 'number' && typeof value !== 'string') || value === '') {
    return DEFAULT_WAIT_FOR_UPDATE;
  }
  // Multiplication is supported in GTM Sandboxed JavaScript and performs the
  // numeric coercion needed for values coming from a TEXT parameter without
  // relying on the unavailable global Number.
  var n = value * 1;
  if (n !== n || n < 0 || n > MAX_WAIT_FOR_UPDATE) {
    return DEFAULT_WAIT_FOR_UPDATE;
  }
  return n;
}

function mapConsentState(categories) {
  var c = categories && typeof categories === 'object' ? categories : {};
  var granted = function (value) { return value === true ? 'granted' : 'denied'; };
  return {
    ad_storage: granted(c.marketing),
    ad_user_data: granted(c.marketing),
    ad_personalization: granted(c.marketing),
    analytics_storage: granted(c.analytics),
    functionality_storage: granted(c.functional),
    personalization_storage: granted(c.functional),
    security_storage: 'granted',
  };
}

function parseDefaultRow(settings, waitForUpdate) {
  var row = settings && typeof settings === 'object' ? settings : {};
  var regions = parseRegions(row.region);
  if (!regions.ok) return { ok: false, error: regions.error, value: null };

  var granted = parseConsentTypes(row.granted);
  if (!granted.ok) return { ok: false, error: granted.error, value: null };
  var denied = parseConsentTypes(row.denied);
  if (!denied.ok) return { ok: false, error: denied.error, value: null };

  // security_storage covers essential fraud prevention/authentication and is an
  // invariant of this template. A row that tries to deny it is rejected rather
  // than silently changing the user's request or violating the invariant.
  if (denied.values.indexOf('security_storage') !== -1) {
    return { ok: false, error: 'security_storage cannot be denied', value: null };
  }

  for (var i = 0; i < granted.values.length; i += 1) {
    if (denied.values.indexOf(granted.values[i]) !== -1) {
      return { ok: false, error: 'Consent type appears in granted and denied: ' + granted.values[i], value: null };
    }
  }

  var value = { region: regions.values };
  ALL_CONSENT_TYPES.forEach(function (type) {
    if (type === 'security_storage') value[type] = 'granted';
    else if (granted.values.indexOf(type) !== -1) value[type] = 'granted';
    else value[type] = 'denied';
  });
  value.wait_for_update = resolveWaitForUpdate(waitForUpdate);
  return { ok: true, error: null, value: value };
}

function globalDeniedDefault(waitForUpdate) {
  var value = mapConsentState({ functional: false, analytics: false, marketing: false });
  value.wait_for_update = resolveWaitForUpdate(waitForUpdate);
  return value;
}

// END GENERATED CONTRACT


const categoryValue = fc.oneof(
  fc.boolean(),
  fc.constant(null),
  fc.constant(undefined),
  fc.integer(),
  fc.string(),
);

describe('GTM mapping contract', () => {
  it('maps strict category booleans to all seven Consent Mode v2 signals', () => {
    fc.assert(fc.property(
      fc.record({ functional: categoryValue, analytics: categoryValue, marketing: categoryValue }),
      (categories) => {
        const mapped = mapConsentState(categories);
        expect(Object.keys(mapped).sort()).toEqual([...ALL_CONSENT_TYPES].sort());
        expect(mapped.ad_storage).toBe(categories.marketing === true ? 'granted' : 'denied');
        expect(mapped.ad_user_data).toBe(categories.marketing === true ? 'granted' : 'denied');
        expect(mapped.ad_personalization).toBe(categories.marketing === true ? 'granted' : 'denied');
        expect(mapped.analytics_storage).toBe(categories.analytics === true ? 'granted' : 'denied');
        expect(mapped.functionality_storage).toBe(categories.functional === true ? 'granted' : 'denied');
        expect(mapped.personalization_storage).toBe(categories.functional === true ? 'granted' : 'denied');
        expect(mapped.security_storage).toBe('granted');
      },
    ), { numRuns: 300 });
  });

  it('fails safe for null, primitives and hostile object keys', () => {
    fc.assert(fc.property(
      fc.oneof(fc.constant(null), fc.constant(undefined), fc.string(), fc.integer(), fc.dictionary(fc.string(), categoryValue)),
      (input) => {
        const mapped = mapConsentState(input);
        for (const type of ALL_CONSENT_TYPES) {
          expect(['granted', 'denied']).toContain(mapped[type]);
        }
        expect(mapped.security_storage).toBe('granted');
      },
    ), { numRuns: 300 });
  });

  it('always emits the global denied fallback with bounded wait_for_update', () => {
    fc.assert(fc.property(fc.anything(), (wait) => {
      const fallback = globalDeniedDefault(wait);
      for (const type of ALL_CONSENT_TYPES) {
        expect(fallback[type]).toBe(type === 'security_storage' ? 'granted' : 'denied');
      }
      expect(fallback.wait_for_update).toBeGreaterThanOrEqual(0);
      expect(fallback.wait_for_update).toBeLessThanOrEqual(10000);
    }), { numRuns: 300 });
  });
});
