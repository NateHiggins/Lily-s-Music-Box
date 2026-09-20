# Actual-build material ownership observations — prepared only

This is a fixture-only revision of the actual CampaignShell/BuildingRoot Vulkan
test. It is outside game, uninstalled and unrun. It extends the exact restored
5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3 fixture without
removing or changing any existing assertion, capture, transition method,
renderer setting, or retirement path. The scene file is unchanged.

The intended first production dependency is the registration/ownership repair
7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db. Focused source
green does not establish real build composition. Verify the final live owner
hash at the eventual handoff; this package never installs the owner. Measure
the ownership repair alone before deciding the separately prepared one-census
optimization. No timing effect is inferred from static preparation.

## What the instrument reads

Eight observations occur after actual cabinet warmup, after each of six
measured cycles, and immediately before real root retirement. The measured
transition function is byte-equivalent after line-ending normalization.
Observers run after both frame samples and no-op timers; their overhead and
elapsed time still affect the run context and are not release performance.

The instrument reads the actual owner constructed by BuildingRoot.build():

- Exactly the six shipped case IDs, their authored unit rooms/floor providers,
  nonempty finish rows and nonempty prop rows. All rows must target the current
  installed material, not a detached old resource.
- Each finish is an actual named imported finish draw on the correct real
  floor, in an allowed ancestry, with the production living_storey marker and
  encroachment parameters. The clipping rect agrees with the independently
  merged authored room bounds. No finish marker or replacement mesh is made.
- Actual case props retain the correct case/storey metadata, original material
  link, live override and exact owner field texture/origin/size.
- Each F02–F06 registry equals the independently censused unique materials of
  active floor draws plus actual root-level case props. Full overrides take
  precedence over surface slots. Missing registry keys, duplicate slots,
  invalid resources and unused/detached registrations are failures.
- Actual private-world and resident/player mesh populations are nonempty.
  Their material IDs and ancestry are recorded; they cannot acquire the
  building's living_storey/case marker or any main-building field texture.
  This is observed exclusion, not a claim that removing every guard would
  change this particular authored scene.
- Actual installed SurfacePass cache consumers are retained by weak draw
  references and IDs. A valid active surface requires current root ancestry,
  eligible boundary, a live mesh/slot and no full override. The same cached
  resource stays installed and carries the current ordinary governor budget.

The prop tier must be active and its queue empty at each observation.
The fixture does not pin or drain the governor to manufacture that condition.
If adaptive behavior prevents a meaningful material observation, its explicit
precondition fails; preserve the run and diagnose the coverage limit instead
of classifying stale rows as healthy.

Two synchronous probes use the production force/refresh hooks on current
installed materials. Before mutation, each probe records the inherited
ENCROACH/ENCROACH_FORCE environment, exact force values, six effective and
recorded intensities, and all actual beachhead owners and installed draw
material IDs. It requires the current effective/recorded intensities to agree
and stay below the actual BEACHHEAD_AT=0.3, with every present beachhead live
and its originals map empty. An unsafe precondition returns a failed receipt
without force assignment, refresh or gameplay writes. The wrapper does not
erase inherited ENCROACH_FORCE to manufacture this condition.

The six temporary values are0.10,0.12,0.14,0.16,0.18,0.20, all below0.3. Actual
beachhead node/mesh/override/active-surface identities must stay identical
before, during and after refresh. The probes read
changed finish and prop state, temporarily poison lifecycle values, and invoke
the real field's current lifecycle push. Unique material IDs are deduplicated
before poisoning so an alias cannot restore the poison itself. The exact
original force dictionary is restored; actual installed identity/state
snapshots and recorded intensities must match before/after. No await, physics tick or capture occurs
inside that probe, and persisted facts must remain unchanged.

Only IDs and WeakRefs survive the observation. After the unchanged real root
retirement, all observed unique case material resources must be gone.
The external native diagnostic gate still governs renderer/resource retention;
weak-reference checks cannot clear a native error.

V2 records explicit non-applicability and makes no ApartmentEncroachment build
claim. Its original composed/capture/retirement boundary remains required.

## Execution and gate

Only after explicit source/lane handoff, install the one proposed test script
at game/tests/vulkan_composed_root_test.gd. Keep the existing scene and every
production source unchanged by this fixture installation. The original
source bytes and fixture.patch are retained; prepare.py refuses original
fixture drift. Any later source repair gets a new run folder and exact binding.

Use the unchanged work/vulkan_composed/run_case.py and serial runner with a
fresh process-local APPDATA, current exact engine/source bindings, the declared
root/scope/variant and the existing 180-second ceiling. All original images
still require direct inspection. An unexpected parse, material or lifecycle
failure is retained and diagnosed, never bypassed.

After process exit, classify_result.py reads the immutable result.json with
explicit --owner-sha256, --fixture-sha256 and a NEW --out path OUTSIDE that run.
It verifies the consumed raw artifact hashes, source/diff binding and exact
unchanged saved base gate. It re-evaluates the existing native/capture/root gate
and adds material_gate.py. Neither gate can turn the other's red into green.
The post-classification output records both verdicts and their source receipt.
It does not rewrite the original run's artifact map.

material_gate.py requires every declared observation and all six cases/five
registries, active cache/private/actor populations, both exact restored state
probes and actual unique-material retirement. Its synthetic controls reject
missing observations/owners, duplicated or detached registries, stale rows,
private contamination, cache/queue failures, source drift and incomplete
restoration/retirement. These are parser/source controls, not engine evidence.

Independent read-only review identified two concrete draft gaps: cached slots
needed active draw/ancestry/override guards, and expected field keys needed
explicit registry coverage. Both are now enforced in the fixture and gate.
The reviewed pending nav/equivalence work is separate from this instrument.

A later independent review rejected draft8538b047 before any engine run:
Peter's fixture unit4B contradicted the shipped case/character data and
production owner, all of which specify4A. This was fixture expectation drift;
no production or canon data changed. That draft also allowed temporary values
to cross0.3 and did not guard an inherited active beachhead. Exact draft
source, tests, logs and receipts remain under
review_revisions/pre_beachhead_precondition_01. The revised independent unit
check and safe-threshold gate cover both errors, including a rejected active
or changed beachhead even when ordinary case-material snapshots match.

## Narrow actual-build omission

controls/build_marker_omission retains exact baseline 7c54c181… and omission
eb623645434945171f887f6e8a91aba0f0113280a392409d002a986131a98170.
marker_omission.py removes only the single living_storey assignment in actual
build() finish construction. The registry's own marker, case-prop marker,
ancestry guard, nullable metadata guard, callbacks, renderer helper and viewport
boundary remain unchanged. is_exact_omission rejects another baseline or any
additional changed byte.

The planned red must show missing marker/lost live finish-row identity in all
six real cases, and failed immediate installed finish-state propagation, while
the original renderer/capture/actual retirement assertions still complete.
Only those named material failures can support this control. Native errors,
other ownership failures, incomplete captures or retirement, changed source or
an access violation invalidate the expected-red interpretation. Then restore
the exact original owner bytes and obtain a clean same-source candidate.
No full historical material-source reversion is proposed.

The first offline control transform assumed CRLF, while this exact reviewed
owner uses LF. Its three preparation failures, source and logs are retained
under controls/marker_preparation_failure_01. The corrected transform removes
one exact LF line and preserves every other source byte. That is preparation
history, not a Godot red.

No actual runtime, visual, player traversal, production build acceptance or
release performance claim is made by this preparation.
