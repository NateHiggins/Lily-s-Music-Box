# One transient census on verified floor ownership

Exact baseline: `2a440504ab80404f4d9f4ab16138df7db9255801ca879ff91aabafe3c7f4d0ca`.
Prepared candidate: `1a1b067ff5b95c03fea739747c97deaaf9621e03a635b318b3379cef07bd3776`.

Only `reach_props` changes. The existing actual floor ancestry policy applies
to known metadata before row retention and to each first claim before bounds.
The floor census is captured once; meshes are scanned once per call. No cache
survives a call. The original helper methods, material ownership repair,
state/lifecycle callbacks and final registry refresh are unchanged.

`encroachment_sweep.patch` and `preparation.json` bind exact source bytes.
The sibling `../../equivalence_revisions/ownership_2a440_01` reuses the exact
171-check fixture and selective priority/late controls with adapted copies.
This package is outside live game and engine-unrun. Do not infer current
performance from historical runs on other material sources. Final composed
proof must compare the verified floor-admission baseline and this candidate
on the same remaining source and completed phases.
