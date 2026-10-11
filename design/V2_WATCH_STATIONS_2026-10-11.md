# V2 native patrol signal boxes

Evidence class: **INERT**. Implementation report; no completeness promotion.

## Section 7 delivery

Base checkout: **fdd12af8**, canonical **C:/PleaseRemainOnTheLine**, main.
Verification baseline: **f1b6c3b7**, the previous clean verified source commit;
the intervening commit only archived its verification and report. Its original
complete board is reused without changing its identity or measurements.

Scope: seven existing patrol watch stations receive Blender-generated stock.
Twenty-one shared, closed meshes replace primitive visual stock: continuous
cast case, enamel lining, hollow door and sash, hinge knuckles, empty key socket,
crank, coded wheel teeth, pawl, indicator and bent conduit. Existing catalogue
PBR materials and Label3D lettering remain authoritative. No baked lettering.
V2 uses a visual subclass; the original patrol controls, station identities,
tour-key custody, refusal behavior, network, record and sound remain intact.

Door stock projects 14 mm forward of its former slab plane while retaining the
original moving hinge pivot. The indicator visual pivot moves 38 mm inward to
keep both signal states inside the case. These are deliberate visual fits.
Loaded-stock checks sample the door's ordinary/refusal range and both indicator
poses. Source authority and interaction volumes are unchanged.

This batch also corrects the active UV layer on window stock: Blender's default
cube charts are removed before authored metre-scale charts are assigned. Window
mechanics and resident settings are unchanged. Old isolated window pictures are
excluded from current visual qualification; fresh native and composed pictures
replace their appearance evidence.

Validation: final **watch_world3.log.receipt.json**, windowed production run,
466 checks, zero failures. Test-written schema-2 **runtime_contract.json** binds
the rendering inputs. All seven stations were operated through the production
player interaction ray; seven register marks were delivered, with zero patrol
failures. All 71 window controls/settings, continuous millwork and sky reviews
run in the same composed world, covering 200 spaces and 13 passage cells.
Surface inventory: 21,789 draws, 15,862 meshes, 5,684 materials, 413 textures;
zero UV/PBR/mipmap/filter defects. Surface evidence qualification passes.

Native stock validation: 21 meshes, zero nonmanifold edges, zero collapsed UV
triangles, positive volume on every stock. Builder assertions run before export;
Blender must use **--python-exit-code 1**. Three final native poses and current
closed/open/marked runtime views were rendered and reviewed. Patrol screenshots
with the carried register document the interaction round, not detail appearance.
Earlier intermediate runs are diagnostic only and are not acceptance evidence.

Packet: **art/renders/orison_v2/surface_requirements_20261011**.
Guide: **game/docs/V2_WATCH_STATIONS.md**. Reader: zero NEW unread fields.
Spatial consumer manifest: three reviewed additions, zero drift.
Historical seven texture RID shutdown warnings remain; full save/relaunch proof
and broader V2 completion are not claimed. No decision needed from the owner.

Fresh candidate verification will be appended after the implementation commit.
