# Independent renderer/material landing review

The proposed selection passes the checks below. No selection file, live game
file, tool, index entry or commit was changed by this review.

- All **3,784 selected raw files** match their SHA256 values: 690,763,319 bytes
  verified, with no missing or mismatched file.
- `paths.nul` contains exactly **3,786 unique paths**: the selected files plus
  `selection.json` and `paths.nul` themselves. No selected path is omitted.
- The selection contains exactly the declared **16 live game paths**. Their
  current raw hashes equal both before and after source maps in the final V1
  result, `94babcd295c78c1212b8eaddb5aef55aa4f7e54f86606ee5ebbc8a1e04b89f9d`.
- All **17 protected paths** retain identical HEAD, index and clean-filtered
  working Git blobs, with their separately recorded raw hashes unchanged.
  None appears in the landing pathspec. These include both layout JSONs, the
  root selector and all seven floor glTF/bin pairs.
- All explicitly excluded paths remain excluded. No new V2 operator revision,
  F01 reconstruction/C1/C2-named source, RGB8 proposal, Harukiya coverage
  proposal, APPDATA profile or Python bytecode is selected. The live-game
  allowlist independently prevents an additional provider or layout landing.
- HEAD remains `da68962aaeaabf56851abb7190dda14d7ff5675f`; the observed index
  contains no staged paths.

The bounded retained-result review checks **36 top-level result manifests and
1,850 artifact references**. Twenty-eight use direct path→SHA256 maps; eight
older composed-smoke results use explicit path/SHA256/byte-size rows. All
referenced bytes and declared sizes match, and each target is selected or
already tracked. No missing, changed, unselected-untracked or external-root
reference remains unresolved in those checked formats.

The initial direct-map-only pass is preserved under `initial_direct_maps`.
Its eight unclassified older results were subsequently inspected and checked
using their explicit row schema. The final JSON records all 36 manifests.

This is not generic schema completeness or recursive reference closure. It
does not certify every nested JSON object, prose link, profile reference,
custom command or future-state dependency. Matching retained artifacts does
not turn a historical red into a green, adopt a proposal, or promote human
acceptance. Source landing and post-commit audit execution remain root-owned.

The frozen selection remains
`4a7c1c923f3076343ee5fe29069ae6d60f808b67b927c26cc7b68d248f3f5cce`.
The exact pathspec is
`9eb0b02dae872e4ce6dba7a8baedc01dca9c94cfcffc4e1cd439d7520f876228`.
`review.json` retains every protected/source check and every resolved artifact
reference. `receipt.json` binds this review and its verifier.
