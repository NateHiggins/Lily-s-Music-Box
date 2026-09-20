# Canonical integration sequence

Sanitation base: `c2dc01771bc25b07f5dcf7a6040102345b8c57d5`. This file proposes adoption; completed landings are recorded in INTEGRATION_REGISTER.md.

## Authorized accepted dependency landing

After the complete sanitation packet exists and baseline runtime evidence is frozen, merge only `a9e455bfede9f89193c9acd0796eb8fc5a0c3548` with a dedicated non-fast-forward integration commit on the new canonical development branch. This preserves original commit identities and gives one reversible boundary. No origin/main push is part of this landing.

| Order | Exact commit | Scope |
| --- | --- | --- |
| 1 | `a0d0a53e7a322f248724225b3325dd1750f17524` | Audit nested durable state before V2 construction (ACCEPTED_CANDIDATE) |
| 2 | `dcd7f722f0b1e8e5132f4644bfb31749c4b213ac` | Track Orison v2 guard test identities (ACCEPTED_CANDIDATE) |
| 3 | `3855fa5e55d7d39f5bc146741cae7223540a9e53` | Record successful Orison v2 third dry run (EVIDENCE_ONLY) |
| 4 | `629db65376c32e613c23049fd2dbbe80276ab100` | Add source-owned Orison v2 bodega bucket (ACCEPTED_CANDIDATE) |
| 5 | `60a1fa8572a85defc318cdad800b30d1cb061a7d` | Add public Orison v2 exterior spatial seams (ACCEPTED_CANDIDATE) |
| 6 | `1da7dd68acdbfceeb94794fdc00092710d3156f0` | Land bounded Orison v2 exterior cell (ACCEPTED_CANDIDATE) |
| 7 | `1a284f4d59e7af3ca3a9f7df699ea4ae2a0b0274` | Prove Orison v2 first exterior cell (EVIDENCE_ONLY) |
| 8 | `c955b43be081a36765d4c4c9934c064816b4f4c6` | Record M11A first exterior cell checkpoint (EVIDENCE_ONLY) |
| 9 | `c8c52aab3a4ed8822c9da81cd28f377bbe107fd8` | Make Orison v2 first exterior cell readable (ACCEPTED_CANDIDATE) |
| 10 | `0429c07078f746d020d9bdad8c3cb72ba6fc452a` | Record M11A-A human readability acceptance (EVIDENCE_ONLY) |
| 11 | `0ea23bfd1296a3779773886b1fc062f10288fa23` | Declare Orison v2 F02/F04 service openings (ACCEPTED_CANDIDATE) |
| 12 | `a9e455bfede9f89193c9acd0796eb8fc5a0c3548` | Record M11B human acceptance (EVIDENCE_ONLY) |

Record the pre-merge canonical commit before landing. Rollback is a reviewable `git revert -m 1 <integration-merge>` on this canonical branch; it preserves the packet and history. Validate named protected paths and their hashes before/after; retain v1 selector and monolith. No rollback command has been executed.

Replay blockout guard red fixtures, M11A/M11B focused routes and save/rotated-instance proof, M08F, two-root reconstruction, and the seven current audits plus their fixture suites. Preserve failing exits and compare scopes, not raw green counts.

## Deferred lines

- M11C0 `f0ac9480fd252b2a412d79606b19b26e993125e6` + `edc18ffb7d5830e05acd98cdaa33a422ea4cb038`: retain partition failure and rehearsal evidence. No production adoption.
- M11C1 exact eight-commit range `edc18ffb7d5830e05acd98cdaa33a422ea4cb038..503465defa24d19d55b53c9a17bf8a4affdfb5eb`: retain owner-source lineage and technical proofs. No merge as accepted production truth; full per-commit list and dependencies in reviews/m11_review.json.
- M11C2 `4480a7994727f6529e726c41fc7f972d1f199a98` and `46d40e9a916ffa7c7cc2ae5031fa6bcbcdeb7777` plus dirty overlay: frozen hash inventory only. Independently reconstruct clean source/consumer parity, route, save, performance, lifecycle, protected hashes and human gate before adoption. If provenance cannot be reconstructed, present concrete alternatives to owner.
- Dream/lamp exact salvage order, accepted atlas/motion pairs, failed exclusions and dependency hashes are enumerated in reviews/dream_review.md. No whole-line merge. Accepted later art cannot silently authorize failed ancestors or missing-resource bundles.

After accepted landing: prioritize measured clean-baseline regressions and the F01 production-provider contract, then +z exterior route and F03 vertical proof. Date/time, save and observation authority defects are shared correctness dependencies; their fixes must preserve existing domain ownership.

Selector cutover, public claims/release, v1 retirement and deletion of recoverable history remain separately reserved owner boundaries.
