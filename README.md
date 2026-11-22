# Biscotti CMP – Google Tag Manager Consent Mode Template

Eigenständig versioniertes GTM-Web-Template für Google Consent Mode v2. Das Paket setzt einen globalen, verweigerten Default vor regionalen Overrides, übernimmt eine bereits gespeicherte Biscotti-Entscheidung und veröffentlicht spätere Änderungen genau einmal.

## Wichtige Architekturgrenze

Dieses Template lädt die CMP **nicht**. Ein über GTM asynchron geladener Boot-Stub kann nicht garantieren, vor allen Vendor-Tags der Seite aktiv zu sein. Installiere deshalb zuerst das kanonische Universal-Snippet aus `src/integrations/generic/cdn-snippet.html` im Dokument-`<head>` – vor dem GTM-Container. Es setzt `window.BiscottiConfig`, lädt `biscotti-boot.js` parser-blockierend vor `biscotti.min.js` und stellt so Request-Shield und `window.__tcfapi` bereit, bevor nachfolgende Tags laufen.

Plattformen mit eigenem Biscotti-Paket (WordPress/WooCommerce, Shopify, Joomla, Shopware, Magento, PrestaShop und Drupal) sollen dieses statt eines Paste-Snippets verwenden. Pro Seite darf nur eine Integration die CMP laden.

## Installation

1. Universal-Snippet bzw. Plattformpaket so früh wie möglich im `<head>` installieren.
2. `template.tpl` in **GTM → Templates → Tag Templates → New → Import** importieren. Die Gallery-Version 2.0.0 ist im externen Gallery-Repository veröffentlicht; `metadata.yaml` referenziert den zugehörigen Commit zusätzlich zum belegten Release 1.0.0.
3. Einen Tag mit **Biscotti CMP – Consent Mode** anlegen.
4. Als Trigger zwingend **Consent Initialization – All Pages** wählen. Nicht „Initialization“ oder „All Pages“.
5. In GTM Preview prüfen, dass der Consent-Default beim Consent-Initialization-Event vor Container Loaded und vor jedem Vendor-Tag steht.

## Felder

| Feld | Standard | Vertrag |
|---|---:|---|
| `defaultSettings` | leer | Optionale regionale Overrides mit `region`, `granted`, `denied`. Regionen sind ISO-3166-2-Codes. Unbekannte Signale, Konflikte, ungültige Regionen und ein verweigertes `security_storage` brechen den Tag fail-closed ab. |
| `waitForUpdate` | `500` | `0` bis `10000` ms; ungültige Werte fallen auf `500` zurück. |
| `enableTcfSupport` | aus | Setzt `gtag_enable_tcf_support`, wenn Biscotti TCF auf der Website aktiv ist. |
| `adsDataRedaction` | aus | Setzt `ads_data_redaction`. |
| `urlPassthrough` | aus | Setzt `url_passthrough`. |

Das Template besitzt bewusst **kein** Website-ID-, API-Key-, Connection-Token- oder Script-Loader-Feld. Website-ID und API-Umgebung gehören in das getrennte Universal-Snippet bzw. Plattformpaket; Secrets gehören in keines der beiden Artefakte.

## Mapping

| Biscotti-Kategorie | Consent-Mode-Signale |
|---|---|
| `marketing === true` | `ad_storage`, `ad_user_data`, `ad_personalization` → `granted` |
| `analytics === true` | `analytics_storage` → `granted` |
| `functional === true` | `functionality_storage`, `personalization_storage` → `granted` |
| immer | `security_storage` → `granted` |

Nur der boolesche Wert `true` erteilt eine Freigabe. Alle anderen Werte bleiben verweigert. Vor jeder regionalen Zeile wird immer ein globaler denied-Default gesetzt, damit Besucher außerhalb der angegebenen Regionen nie ohne Default bleiben.

Gespeicherte Entscheidungen werden aus `biscotti_consent` gelesen. Jeder Initialisierungs- und Update-Event enthält `biscotti_tcf_string` und `biscotti_ac_string`; nach Reject oder Withdraw werden fehlende Werte explizit als `null` veröffentlicht, sodass keine alten Strings im Data Layer stehen bleiben.

## Build und Gates

Im Paketverzeichnis:

- `npm run build` erzeugt `template.tpl`, `gallery-candidate.json` und das deterministische ZIP unter `dist/gtm/`.
- `npm test` führt die importgekoppelten Mapping-/Parsing-Property-Tests und das Paket-Gate aus.
- `npm run audit` prüft Drift, Metadaten, Berechtigungen, Hashes und Tests.
- `npm run audit:gallery` bleibt absichtlich rot, bis ein externer 40-stelliger Gallery-Commit-SHA und menschliche Review-Evidence vorliegen und `metadata.yaml` genau diesen Commit referenziert.

`src/contract.js` ist die Quelle für Mapping und Parser. Der Builder rendert dieselben Funktionskörper in `template.tpl`; Tests verwenden keine handgepflegte Kopie.

## Gallery-Status und Releasegrenze

`gallery-candidate.json` beschreibt den lokalen, unveröffentlichten Kandidaten und bindet ihn an Inhalts-Hashes. Das ist kein Ersatz für den Commit-SHA des eigenständigen Gallery-Repositories. Ohne externen Commit und Human Review ist 2.0.0 lokal installierbar, aber nicht Gallery-publish-ready.

Browser-, GTM-Preview-, Netzwerk-Trace- und TC-String-Decode-Evidence werden im gebündelten TCF-QA-Lauf erzeugt; die statischen und property-basierten Gates ersetzen diese reale Prüfung nicht.

## Lizenz und Support

Apache-2.0. Dokumentation: https://biscotti-cmp.com/docs/integrations/gtm · Support: support@biscotti-cmp.com
