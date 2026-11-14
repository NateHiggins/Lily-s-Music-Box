# Current V2 service-round runtime reconstruction

The existing explicit-V2 M08F fixture passes 29 checks with empty stderr in
`runtime_final.log`: production ritual/service owners, early-action denial,
the complete service-round event trace, duplicate-action protection, real disk
save/destroy/CampaignShell reconstruction, bedside semantic return and protected
V1 layout hash. The fixture now uses a unique test-save path and retains sidecars
so repeated runs respect the crash-recovery storage contract.

This fixture invokes several domain methods directly. It does not establish
player targeting of every ritual control or a walked golden shift. Its teardown
does not measure all runtime-owned resources, so it is not promoted to the
completeness ledger's stricter schema-2 runtime-contract receipt.
