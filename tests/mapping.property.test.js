/**
 * Feature: gtm-community-template
 * Property 1: Category Mapping Correctness
 * Validates: Requirements 5.1–5.9
 *
 * Tests the pure `mapConsentState` logic extracted from template.tpl's
 * Sandboxed JS (which cannot be imported directly). The function below MUST
 * stay in sync with the template implementation.
 */
import { describe, it, expect } from 'vitest';
import fc from 'fast-check';

// --- Mirror of mapConsentState() in template.tpl ---
function mapConsentState(categories) {
  const granted = (val) => (val === true ? 'granted' : 'denied');
  return {
    ad_storage: granted(categories.marketing),
    ad_user_data: granted(categories.marketing),
    ad_personalization: granted(categories.marketing),
    analytics_storage: granted(categories.analytics),
    functionality_storage: granted(categories.functional),
    personalization_storage: granted(categories.functional),
    security_storage: 'granted',
  };
}

describe('Property 1: Category Mapping Correctness', () => {
  it('maps Biscotti categories to the 7 Consent Mode v2 signals', () => {
    fc.assert(
      fc.property(
        fc.record({
          marketing: fc.boolean(),
          analytics: fc.boolean(),
          functional: fc.boolean(),
        }),
        (categories) => {
          const r = mapConsentState(categories);
          expect(r.ad_storage).toBe(categories.marketing ? 'granted' : 'denied');
          expect(r.ad_user_data).toBe(categories.marketing ? 'granted' : 'denied');
          expect(r.ad_personalization).toBe(categories.marketing ? 'granted' : 'denied');
          expect(r.analytics_storage).toBe(categories.analytics ? 'granted' : 'denied');
          expect(r.functionality_storage).toBe(categories.functional ? 'granted' : 'denied');
          expect(r.personalization_storage).toBe(categories.functional ? 'granted' : 'denied');
          expect(r.security_storage).toBe('granted');
        }
      ),
      { numRuns: 100 }
    );
  });

  it('treats any non-true value (false, undefined, "true", 1) as denied — fail-safe', () => {
    fc.assert(
      fc.property(
        fc.record({
          marketing: fc.oneof(fc.constant(false), fc.constant(undefined), fc.constant('true'), fc.constant(1)),
          analytics: fc.boolean(),
          functional: fc.boolean(),
        }),
        (categories) => {
          const r = mapConsentState(categories);
          // Only a strict boolean true may grant; everything else is denied.
          expect(r.ad_storage).toBe('denied');
          expect(r.ad_user_data).toBe('denied');
          expect(r.ad_personalization).toBe('denied');
        }
      ),
      { numRuns: 100 }
    );
  });

  it('always grants security_storage regardless of category input', () => {
    fc.assert(
      fc.property(fc.dictionary(fc.string(), fc.boolean()), (categories) => {
        expect(mapConsentState(categories).security_storage).toBe('granted');
      }),
      { numRuns: 100 }
    );
  });
});
