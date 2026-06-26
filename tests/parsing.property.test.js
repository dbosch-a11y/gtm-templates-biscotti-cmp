/**
 * Feature: gtm-community-template
 * Property 3: Default Settings Configuration Passthrough (+ region completeness)
 * Validates: Requirements 3.9, 3.10 and the B4 fail-safe completion fix.
 *
 * Tests the pure `parseCommandData` logic extracted from template.tpl's
 * Sandboxed JS. The function below MUST stay in sync with the template
 * implementation (wait_for_update is fixed at 500 here for determinism).
 */
import { describe, it, expect } from 'vitest';
import fc from 'fast-check';

const ALL_CONSENT_TYPES = [
  'ad_storage',
  'ad_user_data',
  'ad_personalization',
  'analytics_storage',
  'functionality_storage',
  'personalization_storage',
  'security_storage',
];

// --- Mirror of parseCommandData() in template.tpl ---
function parseCommandData(settings) {
  const splitInput = (input) => {
    if (!input) return [];
    return input
      .split(',')
      .map((e) => e.trim())
      .filter((e) => e.length > 0);
  };
  const regions = splitInput(settings.region);
  const grantedTypes = splitInput(settings.granted);
  const deniedTypes = splitInput(settings.denied);
  const commandData = {};
  if (regions.length > 0) commandData.region = regions;
  grantedTypes.forEach((entry) => {
    commandData[entry] = 'granted';
  });
  deniedTypes.forEach((entry) => {
    commandData[entry] = 'denied';
  });
  ALL_CONSENT_TYPES.forEach((t) => {
    if (commandData[t] === undefined) {
      commandData[t] = t === 'security_storage' ? 'granted' : 'denied';
    }
  });
  commandData.wait_for_update = 500;
  return commandData;
}

const consentType = fc.constantFrom(...ALL_CONSENT_TYPES);

describe('Property 3: Default Settings Configuration Passthrough', () => {
  it('parses region into trimmed, non-empty arrays (or omits when empty)', () => {
    fc.assert(
      fc.property(fc.array(fc.string()), (parts) => {
        const input = parts.join(',');
        const cd = parseCommandData({ region: input, granted: '', denied: '' });
        const expected = input
          .split(',')
          .map((s) => s.trim())
          .filter((s) => s.length > 0);
        if (expected.length === 0) {
          expect(cd.region).toBeUndefined();
        } else {
          expect(cd.region).toEqual(expected);
        }
      }),
      { numRuns: 100 }
    );
  });

  it('always emits all 7 consent types; granted listed -> granted, rest fail-safe (security granted)', () => {
    fc.assert(
      fc.property(fc.uniqueArray(consentType), (grantedArr) => {
        const cd = parseCommandData({ region: '', granted: grantedArr.join(', '), denied: '' });
        ALL_CONSENT_TYPES.forEach((t) => {
          expect(cd[t]).toBeDefined();
          if (grantedArr.includes(t)) {
            expect(cd[t]).toBe('granted');
          } else {
            expect(cd[t]).toBe(t === 'security_storage' ? 'granted' : 'denied');
          }
        });
        expect(cd.wait_for_update).toBe(500);
      }),
      { numRuns: 100 }
    );
  });

  it('explicit denied entries map to denied (incl. security_storage) and are trimmed', () => {
    fc.assert(
      fc.property(fc.uniqueArray(consentType, { minLength: 1 }), (deniedArr) => {
        const padded = deniedArr.map((s) => '  ' + s + ' ').join(',');
        const cd = parseCommandData({ region: '', granted: '', denied: padded });
        deniedArr.forEach((t) => {
          expect(cd[t]).toBe('denied');
        });
      }),
      { numRuns: 100 }
    );
  });
});
