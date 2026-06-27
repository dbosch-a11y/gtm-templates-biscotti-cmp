___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "biscotti_cmp_consent_mode",
  "version": 1,
  "securityGroups": [],
  "displayName": "Biscotti CMP - Consent Mode",
  "brand": {
    "id": "brand_biscotti_cmp",
    "displayName": "Biscotti CMP"
  },
  "description": "Consent management template for Biscotti CMP. Sets Google Consent Mode v2 defaults and updates consent state from Biscotti\u0027s consent storage. Optional IAB TCF support for Google tags.",
  "categories": ["TAG_MANAGEMENT", "PERSONALIZATION"],
  "containerContexts": ["WEB"]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "websiteId",
    "displayName": "Biscotti Website ID",
    "simpleValueType": true,
    "help": "Your Biscotti website identifier (found in dashboard). Optional if script is loaded externally."
  },
  {
    "type": "PARAM_TABLE",
    "name": "defaultSettings",
    "displayName": "Default Consent Settings",
    "paramTableColumns": [
      {
        "param": {
          "type": "TEXT",
          "name": "region",
          "displayName": "Region (ISO 3166-2 codes, comma-separated)",
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
    "help": "Time in ms to wait for Biscotti to load before using defaults",
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
    "checkboxText": "Map IAB TCF consent to Google tags",
    "simpleValueType": true,
    "defaultValue": false,
    "help": "Enable when Biscotti\u0027s IAB TCF mode is active. Sets gtag_enable_tcf_support so Google tags read the TC String and Additional Consent (addtlConsent) directly from window.__tcfapi, which the Biscotti client registers."
  },
  {
    "type": "CHECKBOX",
    "name": "adsDataRedaction",
    "displayName": "Redact Ads Data",
    "checkboxText": "Enable ads data redaction",
    "simpleValueType": true,
    "defaultValue": false,
    "help": "When enabled and ad_storage is denied, ad click identifiers in requests are redacted"
  },
  {
    "type": "CHECKBOX",
    "name": "urlPassthrough",
    "displayName": "Pass through URL parameters",
    "checkboxText": "Enable URL passthrough",
    "simpleValueType": true,
    "defaultValue": false,
    "help": "Pass ad click info via URL parameters when cookies are denied"
  },
  {
    "type": "CHECKBOX",
    "name": "injectBiscottiScript",
    "displayName": "Load Biscotti script via GTM",
    "checkboxText": "Inject Biscotti client script",
    "simpleValueType": true,
    "defaultValue": false,
    "help": "Inject the Biscotti client script. Disable if script is already on the page."
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

// Required APIs
const setDefaultConsentState = require('setDefaultConsentState');
const updateConsentState = require('updateConsentState');
const localStorage = require('localStorage');
const JSON = require('JSON');
const gtagSet = require('gtagSet');
const callInWindow = require('callInWindow');
const setInWindow = require('setInWindow');
const logToConsole = require('logToConsole');
const createQueue = require('createQueue');
const injectScript = require('injectScript');
const makeNumber = require('makeNumber');

const STORAGE_KEY = 'biscotti_consent';

// Biscotti's Google-issued CMP Developer ID (CMP Partner Program approval).
const DEVELOPER_ID = 'dOTA1Nj';

const ALL_CONSENT_TYPES = [
  'ad_storage',
  'ad_user_data',
  'ad_personalization',
  'analytics_storage',
  'functionality_storage',
  'personalization_storage',
  'security_storage'
];

const dataLayerPush = createQueue('dataLayer');

/**
 * Maps Biscotti consent categories to Google Consent Mode v2 signals.
 * marketing  -> ad_storage, ad_user_data, ad_personalization
 * analytics  -> analytics_storage
 * functional -> functionality_storage, personalization_storage
 * security_storage is always granted.
 */
const mapConsentState = function(categories) {
  var granted = function(val) {
    return val === true ? 'granted' : 'denied';
  };
  return {
    ad_storage: granted(categories.marketing),
    ad_user_data: granted(categories.marketing),
    ad_personalization: granted(categories.marketing),
    analytics_storage: granted(categories.analytics),
    functionality_storage: granted(categories.functional),
    personalization_storage: granted(categories.functional),
    security_storage: 'granted'
  };
};

/**
 * Resolves wait_for_update, preserving an explicit 0.
 * (`data.waitForUpdate || 500` would wrongly turn a user-configured 0 into 500.)
 * Falls back to 500 for NaN/negative/empty values.
 */
const resolveWaitForUpdate = function() {
  var w = makeNumber(data.waitForUpdate);
  if (!(w >= 0)) {
    return 500;
  }
  return w;
};

/**
 * Parses a defaultSettings row into a consent command data object.
 * Every consent type is always set (missing -> denied, security_storage ->
 * granted) so a configured region never ends up with partially-undefined
 * signals (which would trigger "tag read consent before default was set").
 */
const parseCommandData = function(settings) {
  var splitInput = function(input) {
    if (!input) return [];
    return input.split(',').map(function(e) { return e.trim(); }).filter(function(e) { return e.length > 0; });
  };
  var regions = splitInput(settings.region);
  var grantedTypes = splitInput(settings.granted);
  var deniedTypes = splitInput(settings.denied);
  var commandData = {};
  if (regions.length > 0) {
    commandData.region = regions;
  }
  grantedTypes.forEach(function(entry) { commandData[entry] = 'granted'; });
  deniedTypes.forEach(function(entry) { commandData[entry] = 'denied'; });
  // Ensure completeness for this region (fail-safe to denied).
  ALL_CONSENT_TYPES.forEach(function(t) {
    if (commandData[t] === undefined) {
      commandData[t] = (t === 'security_storage') ? 'granted' : 'denied';
    }
  });
  commandData.wait_for_update = resolveWaitForUpdate();
  return commandData;
};

/**
 * Consent change callback. Registered with the Biscotti client and invoked
 * whenever consent changes; re-reads localStorage and pushes a fresh update.
 */
const onConsentUpdate = function() {
  var freshConsent;
  try {
    freshConsent = localStorage.getItem(STORAGE_KEY);
  } catch (e) {
    return;
  }
  if (!freshConsent) return;
  try {
    var freshParsed = JSON.parse(freshConsent);
    if (freshParsed && freshParsed.categories) {
      var freshConsentUpdate = mapConsentState(freshParsed.categories);
      updateConsentState(freshConsentUpdate);
      dataLayerPush({
        event: 'biscotti_consent_update',
        biscotti_consent: freshConsentUpdate
      });
    }
  } catch (e) {
    logToConsole('[Biscotti GTM] Failed to parse updated consent');
  }
};

// --- Main Execution (wrapped so unexpected errors call gtmOnFailure) ---
try {
  // 1. gtagSet calls — BEFORE setDefaultConsentState
  gtagSet('developer_id.' + DEVELOPER_ID, true);
  if (data.adsDataRedaction) {
    gtagSet('ads_data_redaction', true);
  }
  if (data.urlPassthrough) {
    gtagSet('url_passthrough', true);
  }

  // 2. IAB TCF support: let Google tags consume the TC String + Additional
  //    Consent (addtlConsent) directly from window.__tcfapi (registered by the
  //    Biscotti client). Must be set before Google tags load.
  if (data.enableTcfSupport) {
    setInWindow('gtag_enable_tcf_support', true, true);
  }

  // 3. Set default consent state (all denied except security_storage)
  if (data.defaultSettings && data.defaultSettings.length > 0) {
    // Region-specific defaults from the param table.
    data.defaultSettings.forEach(function(settings) {
      setDefaultConsentState(parseCommandData(settings));
    });
  } else {
    // Global defaults: deny all except security_storage.
    setDefaultConsentState({
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied',
      analytics_storage: 'denied',
      functionality_storage: 'denied',
      personalization_storage: 'denied',
      security_storage: 'granted',
      wait_for_update: resolveWaitForUpdate()
    });
  }

  // 4. Read existing consent from localStorage (graceful on privacy-mode errors)
  var storedConsent;
  try {
    storedConsent = localStorage.getItem(STORAGE_KEY);
  } catch (e) {
    storedConsent = null;
    logToConsole('[Biscotti GTM] localStorage not accessible; retaining denied defaults');
  }
  if (storedConsent) {
    try {
      var parsed = JSON.parse(storedConsent);
      if (parsed && parsed.categories) {
        var consentUpdate = mapConsentState(parsed.categories);
        updateConsentState(consentUpdate);

        // Initialization event to dataLayer
        dataLayerPush({
          event: 'biscotti_consent_initialized',
          biscotti_consent: consentUpdate
        });

        // TC String / AC String exposed on the dataLayer for TCF-aware custom
        // tags. (Google's own tags consume these via gtag_enable_tcf_support,
        // not from here — see step 2.)
        if (parsed.tcfString) {
          dataLayerPush({ biscotti_tcf_string: parsed.tcfString });
        }
        if (parsed.acString) {
          dataLayerPush({ biscotti_ac_string: parsed.acString });
        }
      }
    } catch (e) {
      logToConsole('[Biscotti GTM] Failed to parse consent from localStorage');
    }
  }

  // 5. Register consent change callback via setInWindow + callInWindow
  setInWindow('__biscottiGtmConsentCallback', onConsentUpdate, true);
  callInWindow('__biscottiRegisterConsentCallback', onConsentUpdate);

  // 6. Optional: inject the Biscotti client script
  if (data.injectBiscottiScript && data.websiteId) {
    var scriptUrl = 'https://api.biscotti-cmp.com/scripts/biscotti.min.js';
    injectScript(
      scriptUrl,
      function() { logToConsole('[Biscotti GTM] Script loaded successfully'); },
      function() { logToConsole('[Biscotti GTM] Script injection failed'); },
      scriptUrl
    );
  }

  // 7. Signal successful execution
  data.gtmOnSuccess();
} catch (e) {
  logToConsole('[Biscotti GTM] Unexpected error during execution: ' + e);
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
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "ad_storage" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "ad_user_data" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "ad_personalization" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "analytics_storage" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "functionality_storage" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "personalization_storage" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "consentType" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "security_storage" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
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
                  { "type": 1, "string": "key" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" }
                ],
                "mapValue": [
                  { "type": 1, "string": "biscotti_consent" },
                  { "type": 8, "boolean": true },
                  { "type": 8, "boolean": false }
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
                  { "type": 1, "string": "key" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" },
                  { "type": 1, "string": "execute" }
                ],
                "mapValue": [
                  { "type": 1, "string": "dataLayer" },
                  { "type": 8, "boolean": true },
                  { "type": 8, "boolean": true },
                  { "type": 8, "boolean": false }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "key" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" },
                  { "type": 1, "string": "execute" }
                ],
                "mapValue": [
                  { "type": 1, "string": "__biscottiRegisterConsentCallback" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "key" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" },
                  { "type": 1, "string": "execute" }
                ],
                "mapValue": [
                  { "type": 1, "string": "__biscottiGtmConsentCallback" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true },
                  { "type": 8, "boolean": false }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  { "type": 1, "string": "key" },
                  { "type": 1, "string": "read" },
                  { "type": 1, "string": "write" },
                  { "type": 1, "string": "execute" }
                ],
                "mapValue": [
                  { "type": 1, "string": "gtag_enable_tcf_support" },
                  { "type": 8, "boolean": false },
                  { "type": 8, "boolean": true },
                  { "type": 8, "boolean": false }
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
        "publicId": "inject_script",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              { "type": 1, "string": "https://api.biscotti-cmp.com/scripts/*" }
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
              { "type": 1, "string": "developer_id.*" },
              { "type": 1, "string": "ads_data_redaction" },
              { "type": 1, "string": "url_passthrough" }
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
- name: setDefaultConsentState is called with all 7 consent types at correct defaults
  code: |-
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});

    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertApi('setDefaultConsentState').wasCalledWith({
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied',
      analytics_storage: 'denied',
      functionality_storage: 'denied',
      personalization_storage: 'denied',
      security_storage: 'granted',
      wait_for_update: 500
    });

- name: updateConsentState is called correctly when valid consent exists in localStorage
  code: |-
    const storedConsent = JSON.stringify({
      categories: { essential: true, functional: true, analytics: true, marketing: true },
      timestamp: '2024-01-01T00:00:00Z',
      version: '1.0'
    });

    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return storedConsent; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});

    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertApi('updateConsentState').wasCalledWith({
      ad_storage: 'granted',
      ad_user_data: 'granted',
      ad_personalization: 'granted',
      analytics_storage: 'granted',
      functionality_storage: 'granted',
      personalization_storage: 'granted',
      security_storage: 'granted'
    });

- name: updateConsentState is NOT called when localStorage returns null
  code: |-
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});

    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertApi('updateConsentState').wasNotCalled();

- name: updateConsentState is NOT called when localStorage contains invalid JSON
  code: |-
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return '{invalid json!!!'; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});

    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertApi('updateConsentState').wasNotCalled();
    assertApi('logToConsole').wasCalled();

- name: marketing=true maps to ad_storage/ad_user_data/ad_personalization=granted
  code: |-
    const storedConsent = JSON.stringify({
      categories: { essential: true, functional: false, analytics: false, marketing: true },
      timestamp: '2024-01-01T00:00:00Z',
      version: '1.0'
    });

    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return storedConsent; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});

    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertApi('updateConsentState').wasCalledWith({
      ad_storage: 'granted',
      ad_user_data: 'granted',
      ad_personalization: 'granted',
      analytics_storage: 'denied',
      functionality_storage: 'denied',
      personalization_storage: 'denied',
      security_storage: 'granted'
    });

- name: functional=true maps to functionality_storage/personalization_storage=granted
  code: |-
    const storedConsent = JSON.stringify({
      categories: { essential: true, functional: true, analytics: false, marketing: false },
      timestamp: '2024-01-01T00:00:00Z',
      version: '1.0'
    });

    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return storedConsent; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});

    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertApi('updateConsentState').wasCalledWith({
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied',
      analytics_storage: 'denied',
      functionality_storage: 'granted',
      personalization_storage: 'granted',
      security_storage: 'granted'
    });

- name: gtagSet is called with developer_id
  code: |-
    let gtagSetCalls = [];
    mock('gtagSet', function(key, value) { gtagSetCalls.push({key: key, value: value}); });
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});

    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertApi('gtagSet').wasCalled();
    assertThat(gtagSetCalls[0].key).contains('developer_id.');
    assertThat(gtagSetCalls[0].value).isEqualTo(true);

- name: region-specific default consent state when regions are configured
  code: |-
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});

    const mockData = {
      defaultSettings: [
        { region: 'US-CA, US-CO', granted: 'security_storage', denied: 'ad_storage, ad_user_data, ad_personalization, analytics_storage, functionality_storage, personalization_storage' }
      ],
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertApi('setDefaultConsentState').wasCalledWith({
      region: ['US-CA', 'US-CO'],
      security_storage: 'granted',
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied',
      analytics_storage: 'denied',
      functionality_storage: 'denied',
      personalization_storage: 'denied',
      wait_for_update: 500
    });

- name: region row with partial types fills the rest (fail-safe to denied)
  code: |-
    let captured = null;
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});
    mock('setDefaultConsentState', function(obj) { captured = obj; });

    const mockData = {
      defaultSettings: [
        { region: 'DE', granted: 'analytics_storage', denied: '' }
      ],
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertThat(captured.analytics_storage).isEqualTo('granted');
    assertThat(captured.ad_storage).isEqualTo('denied');
    assertThat(captured.ad_user_data).isEqualTo('denied');
    assertThat(captured.ad_personalization).isEqualTo('denied');
    assertThat(captured.functionality_storage).isEqualTo('denied');
    assertThat(captured.personalization_storage).isEqualTo('denied');
    assertThat(captured.security_storage).isEqualTo('granted');

- name: enableTcfSupport sets the gtag_enable_tcf_support flag
  code: |-
    let tcfFlag = null;
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function(key, value) { if (key === 'gtag_enable_tcf_support') tcfFlag = value; });
    mock('logToConsole', function() {});

    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: true,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertThat(tcfFlag).isEqualTo(true);

- name: enableTcfSupport off does NOT set the gtag_enable_tcf_support flag
  code: |-
    let tcfFlag = null;
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function(key, value) { if (key === 'gtag_enable_tcf_support') tcfFlag = value; });
    mock('logToConsole', function() {});

    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertThat(tcfFlag).isEqualTo(null);

- name: wait_for_update value of 0 is preserved (not coerced to 500)
  code: |-
    let captured = null;
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});
    mock('setDefaultConsentState', function(obj) { captured = obj; });

    const mockData = {
      waitForUpdate: 0,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertThat(captured.wait_for_update).isEqualTo(0);

- name: data.gtmOnSuccess() is called on successful execution
  code: |-
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});

    let successCalled = false;
    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() { successCalled = true; },
      gtmOnFailure: function() { fail('gtmOnFailure should not be called'); }
    };

    runCode(mockData);

    assertThat(successCalled).isEqualTo(true);

- name: data.gtmOnFailure() is called when an unexpected error occurs
  code: |-
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function() {}; });
    mock('localStorage', { getItem: function() { return null; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});
    mock('setDefaultConsentState', function() { throw 'forced error'; });

    let failCalled = false;
    let successCalled = false;
    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() { successCalled = true; },
      gtmOnFailure: function() { failCalled = true; }
    };

    runCode(mockData);

    assertThat(failCalled).isEqualTo(true);
    assertThat(successCalled).isEqualTo(false);

- name: dataLayer push with correct event name and payload on consent initialization
  code: |-
    const storedConsent = JSON.stringify({
      categories: { essential: true, functional: false, analytics: true, marketing: false },
      timestamp: '2024-01-01T00:00:00Z',
      version: '1.0'
    });

    let dataLayerEvents = [];
    mock('gtagSet', function() {});
    mock('createQueue', function() { return function(event) { dataLayerEvents.push(event); }; });
    mock('localStorage', { getItem: function() { return storedConsent; } });
    mock('callInWindow', function() {});
    mock('setInWindow', function() {});
    mock('logToConsole', function() {});

    const mockData = {
      waitForUpdate: 500,
      enableTcfSupport: false,
      adsDataRedaction: false,
      urlPassthrough: false,
      injectBiscottiScript: false,
      websiteId: '',
      gtmOnSuccess: function() {},
      gtmOnFailure: function() {}
    };

    runCode(mockData);

    assertThat(dataLayerEvents.length).isGreaterThanOrEqualTo(1);
    assertThat(dataLayerEvents[0].event).isEqualTo('biscotti_consent_initialized');
    assertThat(dataLayerEvents[0].biscotti_consent.ad_storage).isEqualTo('denied');
    assertThat(dataLayerEvents[0].biscotti_consent.ad_user_data).isEqualTo('denied');
    assertThat(dataLayerEvents[0].biscotti_consent.ad_personalization).isEqualTo('denied');
    assertThat(dataLayerEvents[0].biscotti_consent.analytics_storage).isEqualTo('granted');
    assertThat(dataLayerEvents[0].biscotti_consent.functionality_storage).isEqualTo('denied');
    assertThat(dataLayerEvents[0].biscotti_consent.personalization_storage).isEqualTo('denied');
    assertThat(dataLayerEvents[0].biscotti_consent.security_storage).isEqualTo('granted');
