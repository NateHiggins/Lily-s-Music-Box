# Orison v2 M08C consumer census — 2026-08-28

Scope: runtime initialization, save reconstruction, dream return, tests, and tooling. Searches covered `orison_root.tscn`, `building_layout.json`, semantic IDs, anonymous `bed`, acoustic positions, raw `Vector3`/`pos` records, and root/node-path assumptions.

| Consumer family | Classification | Disposition |
|---|---|---|
| `GameBoot`, `CampaignShell` building selection | selector-compliant | Both use `BuildingRootSelector`; no duplicated path mapping. |
| v2 first-slice gameplay consumers | adapter-compliant | Existing F01 props, Vantry/chirp/Mina, terminal/call/audio, and CoreLoop are mounted through semantic identities. |
| `CoreLoopDirector` anonymous `bed` lookup | v1-only fallback | Retained unchanged after the optional semantic resolver; it is not used in a v2-selected wake. |
| v1 `BuildingRoot` layout coordinates and node topology | v1-only fallback | Remains the production default and is intentionally not migrated here. |
| milestone tests, capture scripts, evidence references | test/evidence-only | Direct root/review-scene loads are deliberate fixed-fixture selection. |
| generators and layout validators | test/evidence-only | Authoring inputs remain outside runtime selection and were not changed. |
| `VirusSoundDirector` authored debug-intro route coordinates | open non-blocking debt | Normal call/audio origin is semantic; its optional debug camera route remains v1-authored. |
| full first-shift ritual/service-round composition | blocking raw coupling | These consumers still depend on v1-only props/arrival topology outside the proven first slice; M08C does not counterfeit them. |

No selector state is serialized. No job, case, wake, audio, interaction, or save authority reads v2 coordinates directly.
