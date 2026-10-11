# V2 window treatments

Evidence class: **INERT**. Implementation guide, not runtime acceptance.

Every habitable semantic window has a **WindowTreatment** child. The boiler
air hopper retains its existing operating mechanism. Mounts use the window's
actual reveal, sill, height and inward wall face rather than guessed positions.
The fitter runs after resident schedules bind and before household saves bind.

Blinds have constant-length crowned wood slats, ladder cords and rungs, lift
cords, bottom rail, tassel and tilt wand. Lift packs the bottom slats upwards;
tilt rotates deployed slats about their long axis. The packed stack lies flat.
Player interaction with the tassel advances lift by one quarter, the wand
advances tilt by 25 degrees, and the curtain edge toggles draw. The existing
interaction ray and prompt owner dispatch all three controls.

The continuous API is **set_settings(lift, angle, curtain_open, duration)**.
Lift/draw range from 0 to 1; tilt ranges from -75 to 75 degrees. Values are
clamped; nonfinite input is ignored. **restore_settings** requires a complete,
valid three-field dictionary and cancels an active tween. Saved settings record
the destination at animation start, so unrelated state commits cannot interrupt
movement or save an accidental intermediate pose. The existing HouseholdState
and RealityState own persistence; no additional save writer is introduced.
Earlier saves without window records use the authored household defaults.

The mirrored apartment life profiles contain each household's treatment,
material, tint, three settings and a characterization note. Day sleepers close
their rooms; sleeping residents close bedroom treatments. Bathrooms receive
privacy cafe panels and closed slats; kitchens omit loose curtain fabric.
Cam and Noel have different bedroom settings. Initial settings express character
and the starting schedule; residents do not repeatedly override player changes.

Curtain variants include neutral linen, sewn cafe panels, heavy colored drapes
and dark sleep shades. Modeled pleats, hem, hanging tabs, brass rods and wall
brackets provide their silhouette. Panels gather horizontally when drawn;
this is an authored deformation rather than a cloth simulation. Dark drapes
use tint and a heavy textile finish; no claim of certified blackout transmission
or a light-leak simulation is made.

Native source: **art/blender/scripts/build_window_treatments.py**, generating
**art/blender/window_treatments.blend** and **game/assets/props/window_treatments.glb**.
The review builder renders native stock and checks UV charts. Runtime MultiMesh
instances share the imported meshes; separate wood, cloth, cord and hardware
finishes use catalogue albedo/roughness/normal maps with full mip chains and
anisotropic mip filtering. Instance UV scale preserves metre-scale stock grain;
cloth retains its unfolded texture span while gathering.

Verify the isolated mechanism with **V2WindowTreatmentsTest.tscn**. The combined
**OrisonV2SurfaceInventory.tscn** run verifies all installations, household save
binding and restoration, physical control rays, and exhaustive loaded surface
requirements while capturing representative homes. Run through the lane broker
with a log path and windowed shot directory. The surface qualification packet
must be refreshed after any rendering input changes.
