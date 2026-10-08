# Rear service alley material pass

Evidence class: **INERT**

REPORT - Rear alley finish continuation - 2026-10-08

Branch / starting HEAD / origin/main / merge-base: **main / 8ecceb4e / same / same**.

The coping requested **limestone**, an absent catalogue key, and rendered as
untextured white. Its local finish now uses registered concrete mineral maps
with restrained relief. Brick and paving receive quieter surface response;
grates, collector fittings and lamp supports reuse **iron_neutral**. Four
local recipes cover 34 installed material groups. Cached materials remain intact.

Both native files and both exports remain byte-identical to the starting commit.
Read-only Blender review reopens 342 positive closed stocks. Boundary UVs were
unsuitable for a mode change, so their original world projection is retained;
newer groundworks keep metric UVs. Native boundary comparison uses temporary
world-planar charts approximating that projection without saving the model.

## Review and verification

Packet: **art/renders/orison_v2/alley_finish_20261008**. Native boundary/grate
pairs include the plain-white coping fallback. Installed pairs show actual
materials at walked stations in unchanged production lighting with the carried
lamp enabled and its overlay hidden.

The focused test inherits the full rear-door/street return and groundworks/well
crossing. It adds exact recipes, map identity, mip chains, projection policy and
immutable-cache checks. Run 01 completed 25 waypoints but rejected an exact float
comparison in the cache assertion; it is a failed diagnostic, not acceptance.
The corrected assertion uses approximate equality. Production inputs are unchanged
between runs. Final run 02 passes 274 finish checks, 195 geometry/mapping checks and 32
waypoints, including the well grate in both directions. Its wrapper receipt is
**runtime02.log.receipt.json** in the packet. Seven existing Texture-RID shutdown
warnings remain; there are no script errors. Twelve comparison images are retained; native and installed finish views were reviewed.

No asset import or new texture generation. Reader NEW=0 and syntax preflight
pass. The inherited test writes inspection records, not a schema-2 runtime
contract; no ledger promotion or full service/weather acceptance is claimed.

## Closeout

Worktree clean at end: no; owner insitu files, supplied review inputs, two
pre-existing EOL-only edits and unrelated UIDs remain outside this batch.
Only named owned paths are staged. Protected paths and selector remain unchanged;
final static candidate comparison is recorded in the packet.

Changes outside expected boundary: focused test subclass and read-only Blender
review script. No changes to layouts, lights, door state, collision, catch or
collector geometry, or save owners. Open findings: city ground/roof boundaries,
remaining shell/detail work and independent weather/service capacity.
Decision needed from owner: none.

Last line: bounded rear-alley finish pass; broader V2 remains open.
