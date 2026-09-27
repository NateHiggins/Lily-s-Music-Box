# Shared roof ventilator fabrication

Evidence class: **INERT**

**art/blender/scripts/build_roof_ventilator.py** generates the editable
**art/blender/roof_ventilator.blend** and **game/assets/props/roof_ventilator.glb**.
The four V2 roof machines gain formed housing walls, hollow bell mouths, rolled
rain hoods, square-to-round throat aprons, four hood supports, motor cooling ribs, end bells, panel fasteners
and rounded belt guards aligned with the existing inspection face. The curb
retains its 720-millimetre collision footprint. The hood has a closed centre
and a real peripheral discharge gap. No lettering is baked into the model.

Blender rotor and shutter meshes mount on the original moving pivots. The
production motor still owns speed, automatic cycling, shutter angle, sound,
variant tints and the guarded-service refusal. Existing emitters, interaction
areas, plenum assignments and static curb collision remain in place. V1 keeps
its original presentation. No new maintenance completion or save field is added.

OrisonV2RoofVentilatorTest checks all four imported machines, actual curb
collision, guard and hood mesh rays, rotor movement, shutter poses and service
refusal, then renders each variant. OrisonV2VentilationTest checks production
access, motor assignments and player curb stops. Captures use an inspection
fill to expose the sheetwork; they are not a production night-lighting claim.
Logs and suite-run receipts live under **tmp/roof-ventilator**. No completeness
ledger or runtime-contract promotion is claimed.
