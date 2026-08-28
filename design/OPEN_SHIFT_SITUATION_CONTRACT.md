# Open-shift situation contract

`OpenShiftSituation` is a small durable observation record, not a universal
director. One instance coordinates one domain-owned situation.

Required facts are `offered_at`, `noticed_at`, `accepted_at`,
`last_attended_at`, `urgency`, `physical_severity`, `social_pressure`,
`player_commitment`, `attempted_actions`, `observed_interference`,
`compensator`, `compensation_started_at`, `resolution_kind`, `residue`, and
`closed_at`. Times are house-clock minutes supplied by the existing project
clock authority; production code must not call a wall-clock API.

The model may record observation, attention, promises, attempts, interference,
escalation, compensation intent, resolution descriptions, and residue. It may
not mutate radiator/boiler mechanisms, inventory, WorkOrders, RealityCases,
dream state, relationships, or selector state. Domain owners perform those
changes and then report the concrete result.

Records live under `RealityState.data.open_shift_situations`. Additive absence
means no situation has yet been observed. Reconstruction uses the same facts
under either building root. The selector is never serialized.
