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

// Build-time serializer from src/contract.js (not part of the sandboxed template code).
function serializeDefaultRow(command) {
  if (!command || !Array.isArray(command.region)) return null;
  var granted = [];
  var denied = [];
  ALL_CONSENT_TYPES.forEach(function (type) {
    if (type === 'security_storage') return;
    if (command[type] === 'granted') granted.push(type);
    else denied.push(type);
  });
  return {
    region: command.region.join(', '),
    granted: granted.join(', '),
    denied: denied.join(', '),
  };
}


const configurableTypes = ALL_CONSENT_TYPES.filter((type) => type !== 'security_storage');
const consentType = fc.constantFrom(...configurableTypes);
const countryCode = fc.tuple(
  fc.constantFrom(...'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),
  fc.constantFrom(...'ABCDEFGHIJKLMNOPQRSTUVWXYZ'),
).map((parts) => parts.join(''));
const subdivision = fc.tuple(
  countryCode,
  fc.array(fc.constantFrom(...'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'), { minLength: 1, maxLength: 3 }),
).map(([country, suffix]) => `${country}-${suffix.join('')}`);
const region = fc.oneof(countryCode, subdivision);

describe('GTM parsing contract', () => {
  it('normalizes, trims and de-duplicates valid ISO region rows', () => {
    fc.assert(fc.property(fc.uniqueArray(region, { minLength: 1 }), (regions) => {
      const input = regions.map((value, index) => index % 2 ? ` ${value.toLowerCase()} ` : value).join(',');
      expect(parseRegions(input)).toEqual({ ok: true, error: null, values: regions });
    }), { numRuns: 300 });
  });

  it('rejects empty, malformed and injection-shaped regions', () => {
    for (const input of ['', ' ', 'D', 'DE-', 'DE-ABCD', 'DE<script>', '__proto__', 'US, constructor']) {
      const result = parseRegions(input);
      expect(result.ok, input).toBe(false);
      expect(result.values).toEqual([]);
    }
  });

  it('accepts only allowlisted consent names and rejects hostile keys', () => {
    fc.assert(fc.property(fc.uniqueArray(fc.constantFrom(...ALL_CONSENT_TYPES)), (types) => {
      expect(parseConsentTypes(types.join(', '))).toEqual({ ok: true, error: null, values: types });
    }), { numRuns: 200 });

    for (const input of ['__proto__', 'constructor', 'prototype', 'ad_storage;alert(1)', 'unknown_storage']) {
      expect(parseConsentTypes(input).ok, input).toBe(false);
    }
  });

  it('keeps CSV output finite for arbitrary input and ignores non-strings', () => {
    fc.assert(fc.property(fc.anything(), (input) => {
      const values = splitCsv(input);
      expect(Array.isArray(values)).toBe(true);
      expect(new Set(values).size).toBe(values.length);
      for (const value of values) expect(value.trim()).toBe(value);
    }), { numRuns: 300 });
  });

  it('round-trips every valid regional mapping through the canonical serializer', () => {
    fc.assert(fc.property(
      fc.uniqueArray(region, { minLength: 1, maxLength: 8 }),
      fc.uniqueArray(consentType),
      fc.integer({ min: 0, max: MAX_WAIT_FOR_UPDATE }),
      (regions, granted, wait) => {
        const first = parseDefaultRow({ region: regions.join(', '), granted: granted.join(', '), denied: '' }, wait);
        expect(first.ok).toBe(true);
        const serialized = serializeDefaultRow(first.value);
        const second = parseDefaultRow(serialized, wait);
        expect(second).toEqual(first);
      },
    ), { numRuns: 500 });
  });

  it('rejects granted/denied conflicts and attempts to deny security_storage', () => {
    fc.assert(fc.property(consentType, region, (type, validRegion) => {
      expect(parseDefaultRow({ region: validRegion, granted: type, denied: type }, 500).ok).toBe(false);
    }), { numRuns: 100 });
    expect(parseDefaultRow({ region: 'DE', granted: '', denied: 'security_storage' }, 500)).toMatchObject({
      ok: false,
      error: 'security_storage cannot be denied',
    });
  });

  it('completes partial rows fail-safe and never copies extra properties', () => {
    const parsed = parseDefaultRow({
      region: 'DE',
      granted: 'analytics_storage',
      denied: '',
      __proto__: { polluted: true },
      arbitrary: 'granted',
    }, 500);
    expect(parsed.ok).toBe(true);
    expect(parsed.value.analytics_storage).toBe('granted');
    expect(parsed.value.security_storage).toBe('granted');
    expect(parsed.value.arbitrary).toBeUndefined();
    expect(parsed.value.polluted).toBeUndefined();
    expect(Object.keys(parsed.value).sort()).toEqual([...ALL_CONSENT_TYPES, 'region', 'wait_for_update'].sort());
  });

  it('honours wait boundaries and defaults every invalid or out-of-range value', () => {
    expect(resolveWaitForUpdate(0)).toBe(0);
    expect(resolveWaitForUpdate(MAX_WAIT_FOR_UPDATE)).toBe(MAX_WAIT_FOR_UPDATE);
    expect(resolveWaitForUpdate('750')).toBe(750);
    for (const input of [-1, MAX_WAIT_FOR_UPDATE + 1, Number.NaN, undefined, 'not-a-number']) {
      expect(resolveWaitForUpdate(input)).toBe(DEFAULT_WAIT_FOR_UPDATE);
    }
  });
});
