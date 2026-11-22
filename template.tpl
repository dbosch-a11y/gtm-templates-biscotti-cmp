___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "biscotti_cmp_consent_mode",
  "version": 2,
  "securityGroups": [],
  "displayName": "Biscotti CMP - Consent Mode",
  "brand": {
    "id": "brand_biscotti_cmp",
    "displayName": "Biscotti CMP"
  },
  "description": "Consent Mode v2 defaults and updates for Biscotti CMP. Requires the Biscotti pre-GTM head snippet so the request shield and IAB TCF stub exist before the container.",
  "categories": [
    "TAG_MANAGEMENT",
    "PERSONALIZATION"
  ],
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "PARAM_TABLE",
    "name": "defaultSettings",
    "displayName": "Regional Consent Defaults",
    "help": "Optional stricter region rows. A global denied fallback is always installed first. Unknown consent types, conflicts, invalid regions and attempts to deny security_storage fail closed.",
    "paramTableColumns": [
      {
        "param": {
          "type": "TEXT",
          "name": "region",
          "displayName": "ISO 3166-2 regions (comma-separated)",
          "simpleValueType": true
        },
        "isUnique": false
      },
      {
        "param": {
          "type": "TEXT",
          "name": "granted",
          "displayName": "Granted consent types (comma-separated)",
          "simpleValueType": true
        },
        "isUnique": false
      },
      {
        "param": {
          "type": "TEXT",
          "name": "denied",
          "displayName": "Denied consent types (comma-separated)",
          "simpleValueType": true
        },
        "isUnique": false
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "waitForUpdate",
    "displayName": "Wait for Update (ms)",
    "simpleValueType": true,
    "defaultValue": "500",
    "help": "0 to 10000 ms. Invalid values fall back to 500 ms.",
    "valueValidators": [
      {
        "type": "NON_NEGATIVE_NUMBER"
      }
    ]
  },
  {
    "type": "CHECKBOX",
    "name": "enableTcfSupport",
    "displayName": "Enable IAB TCF support for Google tags",
    "checkboxText": "Let Google tags read the TC String from window.__tcfapi",
    "simpleValueType": true,
    "defaultValue": false,
    "help": "Enable only when TCF is active in Biscotti. The required pre-GTM head snippet installs window.__tcfapi before this container."
  },
  {
    "type": "CHECKBOX",
    "name": "adsDataRedaction",
    "displayName": "Redact Ads Data",
    "checkboxText": "Enable ads data redaction",
    "simpleValueType": true,
    "defaultValue": false
  },
  {
    "type": "CHECKBOX",
    "name": "urlPassthrough",
    "displayName": "Pass through URL parameters",
    "checkboxText": "Enable URL passthrough",
    "simpleValueType": true,
    "defaultValue": false
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

// GTM Sandboxed JavaScript — generated; edit this builder + src/contract.js.
const setDefaultConsentState = require('setDefaultConsentState');
const updateConsentState = require('updateConsentState');
const localStorage = require('localStorage');
const JSON = require('JSON');
const gtagSet = require('gtagSet');
const callInWindow = require('callInWindow');
const copyFromWindow = require('copyFromWindow');
const setInWindow = require('setInWindow');
const logToConsole = require('logToConsole');
const createQueue = require('createQueue');

const STORAGE_KEY = 'biscotti_consent';
const DEVELOPER_ID = 'dOTA1Nj';
const TEMPLATE_VERSION = '2.0.0';
const dataLayerPush = createQueue('dataLayer');

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

const publishStoredConsent = function(eventName) {
  var raw;
  try {
    raw = localStorage.getItem(STORAGE_KEY);
  } catch (e) {
    logToConsole('[Biscotti GTM] localStorage unavailable; denied defaults stay active');
    return;
  }
  if (!raw) return;
  try {
    var parsed = JSON.parse(raw);
    var categories = parsed ? (parsed.categories || parsed) : null;
    if (!categories) return;
    var mapped = mapConsentState(categories);
    updateConsentState(mapped);
    dataLayerPush({
      event: eventName,
      biscotti_consent: mapped,
      // Always publish both keys, including null, so withdraw/reject cannot leave
      // a stale TC/AC string in the dataLayer from the previous decision.
      biscotti_tcf_string: parsed.tcfString || null,
      biscotti_ac_string: parsed.acString || null
    });
  } catch (e) {
    logToConsole('[Biscotti GTM] Invalid biscotti_consent JSON; denied defaults stay active');
  }
};

const onConsentUpdate = function() {
  publishStoredConsent('biscotti_consent_update');
};

const run = function() {
  // A second tag would register the same callback twice and emit every dataLayer
  // update twice. It is not a second CMP — the engine guards its own instance —
  // but it is still an ambiguous container configuration, so fail closed.
  if (copyFromWindow('__biscottiGtmTemplateVersion')) {
    logToConsole('[Biscotti GTM] Template already initialized; duplicate tag ignored');
    data.gtmOnSuccess();
    return;
  }
  setInWindow('__biscottiGtmTemplateVersion', TEMPLATE_VERSION, false);

  // gtagSet flags must precede the default consent commands.
  gtagSet('developer_id.' + DEVELOPER_ID, true);
  if (data.adsDataRedaction) gtagSet('ads_data_redaction', true);
  if (data.urlPassthrough) gtagSet('url_passthrough', true);
  if (data.enableTcfSupport) setInWindow('gtag_enable_tcf_support', true, true);

  // Global fallback ALWAYS comes first, even if regional rows exist. The old
  // template used either regional OR global defaults, leaving visitors outside
  // every listed region with no default at all.
  setDefaultConsentState(globalDeniedDefault(data.waitForUpdate));

  var rows = data.defaultSettings || [];
  for (var i = 0; i < rows.length; i += 1) {
    var parsedRow = parseDefaultRow(rows[i], data.waitForUpdate);
    if (!parsedRow.ok) {
      logToConsole('[Biscotti GTM] Invalid regional default: ' + parsedRow.error);
      data.gtmOnFailure();
      return;
    }
    setDefaultConsentState(parsedRow.value);
  }

  publishStoredConsent('biscotti_consent_initialized');

  // The durable global callback is canonical. GTM's callInWindow cannot be
  // relied upon to deliver a sandboxed function to the page-side registrar, and
  // the engine may already have initialized before this tag runs. The engine
  // consumes the global slot lazily and uses the template version to avoid
  // invoking the same template callback twice.
  setInWindow('__biscottiGtmConsentCallback', onConsentUpdate, true);
  callInWindow('__biscottiRegisterConsentCallback', onConsentUpdate, TEMPLATE_VERSION);

  data.gtmOnSuccess();
};

try {
  run();
} catch (e) {
  logToConsole('[Biscotti GTM] Unexpected error: ' + e);
  data.gtmOnFailure();
}


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "access_consent",
        "versionId": "1"
      },
      "param": [
        {
          "key": "consentTypes",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ad_storage"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ad_user_data"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "ad_personalization"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "analytics_storage"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "functionality_storage"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "personalization_storage"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "consentType"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "security_storage"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_local_storage",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "biscotti_consent"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "dataLayer"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "__biscottiRegisterConsentCallback"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "__biscottiGtmConsentCallback"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "__biscottiGtmTemplateVersion"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "gtag_enable_tcf_support"
                  },
                  {
                    "type": 8,
                    "boolean": false
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "write_data_layer",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keyPatterns",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "developer_id.*"
              },
              {
                "type": 1,
                "string": "ads_data_redaction"
              },
              {
                "type": 1,
                "string": "url_passthrough"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: global denied fallback is always set before regional defaults
  code: |-
    var calls = [];
    mock('setDefaultConsentState', function(value) { calls.push(value); });
    mock('updateConsentState', function() {});
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('copyFromWindow', function() { return null; });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});
    runCode({
      defaultSettings: [{ region: 'DE', granted: 'analytics_storage', denied: '' }],
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    });
    assertThat(calls.length).isEqualTo(2);
    assertThat(calls[0].analytics_storage).isEqualTo('denied');
    assertThat(calls[0].region).isEqualTo(undefined);
    assertThat(calls[1].region[0]).isEqualTo('DE');
    assertThat(calls[1].analytics_storage).isEqualTo('granted');

- name: hostile consent type rejects the row and never applies it
  code: |-
    var defaults = [];
    var failed = false;
    mock('setDefaultConsentState', function(value) { defaults.push(value); });
    mock('updateConsentState', function() {});
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('copyFromWindow', function() { return null; });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});
    runCode({
      defaultSettings: [{ region: 'DE', granted: '__proto__', denied: '' }],
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      gtmOnSuccess: function() {},
      gtmOnFailure: function() { failed = true; }
    });
    assertThat(defaults.length).isEqualTo(1);
    assertThat(failed).isEqualTo(true);

- name: stored consent maps all seven signals and current TCF data
  code: |-
    var updates = [];
    var events = [];
    mock('setDefaultConsentState', function() {});
    mock('updateConsentState', function(value) { updates.push(value); });
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function(value) { events.push(value); }; });
    mock('localStorage', { getItem: function() { return JSON.stringify({ categories: { functional: true, analytics: true, marketing: false }, tcfString: 'TC', acString: 'AC' }); } });
    mock('copyFromWindow', function() { return null; });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});
    runCode({
      defaultSettings: [], waitForUpdate: 500, enableTcfSupport: true,
      adsDataRedaction: false, urlPassthrough: false,
      gtmOnSuccess: function() {}, gtmOnFailure: function() {}
    });
    assertThat(updates[0].ad_storage).isEqualTo('denied');
    assertThat(updates[0].analytics_storage).isEqualTo('granted');
    assertThat(updates[0].security_storage).isEqualTo('granted');
    assertThat(events[0].biscotti_tcf_string).isEqualTo('TC');
    assertThat(events[0].biscotti_ac_string).isEqualTo('AC');

- name: duplicate tag is ignored before defaults and callback registration
  code: |-
    var defaults = 0;
    var success = false;
    mock('setDefaultConsentState', function() { defaults += 1; });
    mock('updateConsentState', function() {});
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('copyFromWindow', function(key) { return key === '__biscottiGtmTemplateVersion' ? '2.0.0' : null; });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});
    runCode({
      defaultSettings: [], waitForUpdate: 500, enableTcfSupport: false,
      adsDataRedaction: false, urlPassthrough: false,
      gtmOnSuccess: function() { success = true; }, gtmOnFailure: function() {}
    });
    assertThat(defaults).isEqualTo(0);
    assertThat(success).isEqualTo(true);
