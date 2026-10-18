# Native construction shed — 2026-10-18

Evidence class: **INERT**. Work record; no completion or human acceptance grant.

## Change and retained authority

Replaced the eastern construction dogleg’s monolithic visual boxes with
Blender-authored stock: individual hoarding boards, cover battens, nailers,
roof decking, secondary members, lapped posts/beams, diagonal-brace cleats,
separate end grain, nails, through bolts, holed washers/nuts and helical thread.
The runtime keeps all 27 original collision actors, both original work-lamp
identities/poses and the closure notice’s separate Label3D lettering. The
western weather boundary is unchanged.

The native export has 1,426 planned stock/fastener entries, seven catalogue
partitions and 336,172 triangles before Godot’s generated LODs. The 14 measured
lap bearings retain contact after intersecting cuts. This is geometric fitting,
not structural engineering certification.

## Material and native review

Two catalogue keys, **site_softwood** and **site_softwood_endgrain**, provide
separate long/end-grain surfaces. Built-in imagegen produced the new long-grain
albedo; its pixels remain byte-exact. The exact prompt and source are recorded
in **art/textures/ai_sources/site_softwood_20261017.json**. Independent height
fields provide 0.136 mm and 0.132 mm measured relief, with calibrated normals
at strength 1. Colour never determines dents. Roughness represents raw wood;
there are no baked highlights, hardware marks, lettering or photographic pixels.

The generated plate was not mathematically periodic. Metre-space triangles
therefore split at reflected chart boundaries and use clamped sampling. Normal
slopes vanish at reflecting borders. Eight sub-ULP bevel slivers collapsed at
float32 export; the builder excludes these unrepresentable triangles before
constructing the mesh, while the final exported tangent validator stays strict.
All exported tangents pass; minimum derivative agreement is 0.9999988.

The earlier regular procedural grain was rejected. Paired native views and
failed diagnostics are retained under
**art/reviews/v2_construction_shed_20261017**. “Before” images reconstruct the
old source boxes in Blender under the same lights; they are not Godot captures.
Grey space below the approach view omits street context outside the shed floor.

## Verification and limits

Eleven focused tests pass: reflected chart area/scale/handedness/edges and export
precision; retained actor/light arrays and incompatible-source rejection; surviving contacts with displaced-stock
negative controls; finite stock; byte-exact pigment; independently reconstructed
normal/height agreement and reflecting borders. Import policy checks pass for
all 1,259 V2 textures and 30 selective mesh-precision entries.

Final composed qualification passes **28,363 checks**, zero failures. It
inventories **25,649 draws**, **6,096 materials** and **480 textures**. All six
new timber maps load GPU-compressed at 1,254 square with ten additional mip
levels. The canonical **surface_requirements_20261011/runtime_contract.json**
and matching wrapper/raw logs bind the actual execution and reviewed images.
The existing seven Texture RID shutdown warning remains; no global
resource-clean claim is made.

The shed controller walk passes all eight waypoints, plus closure and dogleg
occlusion checks. The street arrival is an explicit fixture; capture stances
are separate fixtures. Original collision actors, lights and notice are checked
in the loaded world. All eight final diffuse/carried views were reviewed.

A reader check after the preliminary pass caught the legacy source material
field becoming unread after box-draw retirement. Native/runtime validation now
rejects incompatible source stock. Original stock identifiers serve as
compatibility constraints; the replacement visual recipe deliberately uses
raw site softwood. Reader baseline: zero new unread fields. The native plan,
excluding source bindings, remains identical; native views are reused with an
explicit compatibility record. No runtime receipt is repinned. The initial gate board also caught missing
new-material definitions in the layout generator. Its two catalogue entries
now match the registered definitions exactly, and the persistence test passes.
Surface qualification was executed again against that corrected authoring
source; the physical service proof is unchanged and remains valid. The preliminary
pass and a deliberately cancelled, incomplete owned service run remain
separate diagnostics. The completed physical service/save test passes all 360 printed checks. It
retains the actual patrol/board/boiler input, finite workshop vent transport,
thread exchange, partial-supply negative control, sustained steam, resident
return, disk save and CampaignShell rebuild from the preceding checkpoint.
Both worlds release all 126,373 tracked nodes, 234 runtime-owned shapes and
164 observed audio playbacks. The 84 shared radiator shape IDs stay stable;
168 borrowed references remain explicitly measured, rather than called leaks.
The existing seven Texture RID shutdown warning remains outside this scope.

## Remaining scope

Two spatial manifest records are appended without changing any of the prior
10,071 entries. Existing drift remains 28 new failing, 43 reported and one
stale preserved. The raw native export origin remains coordinate debt; its
model, source frame and fixture must be regenerated together.

Loaded approach views expose exaggerated crack relief on adjacent masonry
and overbright nearby fittings/fascia. Those existing appearance defects and
the warm cast of production lamps remain open.

The four absent exterior-region records and migration of their retained
nonvisual authorities remain open. The shed route uses an explicit street
arrival fixture and does not prove the lobby-to-street route. Whole-building
navigation, the complete golden shift, human acceptance and retirement
authorization remain open. V2 is not complete.

## Integration preparation

A temporary clean checkout of **e0b0dd293325a49c207785888112262a4990e474**
produced a complete 55-row main baseline with zero dirty paths. The candidate
verifier validates its schema, version, commit, tree and required gate coverage
without errors. Its board is preserved under **clean_main_board** in this
review archive. The temporary checkout is removed after preservation.
This resolves the missing clean-baseline preparation; an isolated clean
candidate verification is still required before main integration. The canonical
checkout retains inherited work from other scopes.

## Final gates and broader branch findings

The final complete board has **79 rows**, **970 tool tests** in **68 suites**:
67 pass and the pre-existing spatial-dependency suite fails. There are zero
regressions against the preceding reviewed checkpoint board. Ledger readiness
is unchanged: first slice 0, golden shift 1, structural 114, whole-building
runtime 35, cutover 131 and retirement 133 blockers. This shed batch does not
promote absent region records by inference.

The newly captured clean main baseline exposes broader branch regressions
that the preceding dirty-checkpoint comparison could not establish. Structural
blockers increase **102 to 114**, cutover **119 to 131** and retirement
**121 to 133**. Several 2A/2B/4B room contracts lose earlier spatial proof.
Spatial drift changes from zero to 28 failing / 43 reported / one stale record;
five systemic review findings are additional to main. The complete comparison
is **clean_main_comparison.md** in the archive. These are integration debts in
the accumulated branch, not fixed or hidden by this geometry checkpoint.
Main integration remains blocked pending their repair and isolated candidate
verification. No V2 completion or owner acceptance is claimed.
