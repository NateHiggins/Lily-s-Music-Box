# DREAM TENTACLE — BLENDER REBUILD (owner direction 2026-08-22), verbatim

*Major task. Take what was learned building the procedural tentacle and
rebuild it as a modelled, layered, deformable creature. The single most
important rule is at the bottom: **the finished model must look impressive
in flat grey.** Shaders reveal anatomy; they do not invent it.*

---

Model it in Blender as a layered deformable creature, not one sculpt. The flesh is the load-bearing deformation mesh; eye, suckers, gold skeleton, crystals, cilia, and membrane are separate systems constrained to it. That gives Godot enough real geometry to sell the silhouette while keeping every hero feature independently animatable.

## 1. Start with the animation skeleton, not the sculpt
Build the neutral limb nearly straight along +Y, about 1.6 m long. Do not sculpt the final curled pose. Create a low-resolution base with deliberate cross-sectional changes: root ~15–18 cm, muscular and asymmetrical; proximal shaft broad/flattened; **ocular station at ~42 % of length, swelling noticeably to support the eye**; post-eye section compressed again; mid/distal shaft progressively more flexible; final 25–30 % narrower but not string-like; sensory club slightly expanded, rounded, tactile. Maybe 20–28 longitudinal control sections, 16–24 vertices around. **The silhouette should already be interesting before subdivision. Do not make a smooth hose and expect displacement to rescue it.**

## 2. A clean deformation cage
Keep a clean `TENTACLE_BODY_CAGE` beneath the detail. Modifier order while modelling: Mirror if useful → Subdivision Surface → corrective/deformation work; eventually Armature → corrective shape keys → Subdivision. The cage needs extremely clean longitudinal edge flow because the limb must bend sharply, twist, compress, flatten, swell, perform peristaltic waves, curl the distal third and rotate the sucker surface toward targets. Mostly quads. Density up around the eye station, high-curvature bends, the sucker-bearing distal third and the membrane/root transition; economical along the central shaft.

## 3. Sculpt flesh as large anatomy first
Duplicate the cage into a high-poly sculpt (Multires or voxel remesh for the sculpt only; preserve the clean cage). Large → medium → tiny. **Primary**: longitudinal muscular bundles, compression folds, asymmetric bulges, soft ridges, tension around bends, a thick root, the eye-bearing shoulder mass — halfway between muscle, cephalopod mantle and an unfamiliar organ, not a sausage. The long axis should read `convex → compressed → swollen → twisted → flattened → narrow → club`. **Secondary**: flesh bunching around gold sockets, shallow vascular channels, folds under the eye, a softer ventral sucker field, longitudinal tension creases, papilla-like raised regions. **Tertiary**: only hero-scale pits, pores, scars and microfold clusters — bake the rest.

## 4. Sculpt a real eye socket into the body
One of the most geometry-intensive areas. At 42 % expand the flesh into a dedicated ocular station and rebuild the topology so the orbit is a **real concavity**, not an eyeball intersecting the limb: heavy dorsal brow, thick lower cushion, lateral muscular wall, asymmetric rear socket, compression folds radiating into the shaft. The globe sits more than halfway inside. **From a 45° side view you should never be able to reconstruct the complete sphere. That is the test.**

## 5. The eyeball in layers
Separate objects `EYE_GLOBE`, `EYE_IRIS`, `EYE_PUPIL_INTERIOR`, `EYE_CORNEA`. Do not texture all this onto one sphere. Globe ~36 mm, slightly irregular. Iris physically recessed, with radial geometry giving muscular fibres, gold structures, channels, uneven depth. Pupil: a dark cavity behind the iris — literally a short funnel so it catches no direct light. Cornea: a separate convex cap, enough subdivisions that reflection deformation stays smooth.

## 6. Triple eyelids need dedicated topology
Three independent objects, not sculpted into the body. **Dorsal**: a thick crescent of purple muscle from above/oblique, modelled like a fleshy hood. **Ventral/lateral**: from below and around one side, topology allowing rotational closure rather than pure translation. **Nictitating**: thin, tucked into the lateral orbit, enough topology to slide diagonally over the cornea, with real thickness at its leading edge. All three need their own bones or shape keys, and **at full open, some geometry from every lid must remain visible** so the eye is never naked in a still.

## 7. Cilia from curves
Blender Curves, not hand-modelled cylinders. ~18 hero cilia around the ocular station in `CILIA_FLESH`, `CILIA_GOLD`, `CILIA_CRYSTAL`. Each begins inside a modelled follicle. Bezier with bevel depth tapering to near zero. Vary curvature, length, root angle, thickness, number of bends. **Avoid radial symmetry — elegant orbital whiskers, not a sea urchin.** Convert to mesh late; hook control points to bones or use 2–4 bone chains; keep them spring-friendly.

## 8. Suckers as actual hero geometry
The distal underside deserves real suckers because they deform on contact. Not scattered identical cups: 4–6 variants, each with a fleshy base mound, raised outer rim, concave centre, inner lip, slightly irregular circle. Distribute manually or with Geometry Nodes over a ventral vertex group, two staggered rows, density and size changing toward the club; more intricate tactile organs near the tip. Hero distal suckers stay separate instanced geometry for individual deformation; distant ones bake or merge.

## 9. Gold as an exoskeletal organ
**Do not make gold rings.** A `GOLD_SKELETON` collection of 20–40 individually recognizable elements: broken crescents, articulated plates, branching struts, socket rims, tendon-like forks, partially buried ribs, mineral knuckles, dendrites. They follow anatomy but never repeat. Every large piece needs a root. **Gold socket construction**: push the flesh inward, raise a rim around the entry, add compression folds, partially bury the gold, branch smaller roots beneath nearby flesh. Never place a metal mesh 1 mm above the body — from profile, some gold must visibly emerge from *inside* the flesh.

## 10. Mechanical joints in the gold
Important pieces are not fused into one static shell. Separate wherever movement occurs (`GOLD_EYE_BROW`, `GOLD_ORBIT_SUPPORT_A/B`, `GOLD_MID_PLATE_01`…), with small overlapping sockets so a 1–4 mm slide exposes no gaps. Model ball/socket, sliding overlap, nested plates, a gold tendon entering a crystal hinge, a telescoping mineral spine. **The mechanics should feel grown, not manufactured.**

## 11. Dendrites with Geometry Nodes
From manually placed curves around major gold structures: resample, controlled branching, varied radius, tapered ends, curve to mesh, occasionally terminating in crystal nodes. **Procedural systems fill connective detail; they do not decide the silhouette.** Branch direction follows the longitudinal axis, local stress lines, nearby veins, the orbit, the plates — then edit conspicuous branches by hand.

## 12. Crystal growth needs real facets
5–12 major crystal organs over the whole creature, not hundreds. Deliberately faceted low-poly forms: elongated prisms, asymmetrical clusters, embedded wedges, broken plates. Do not smooth-shade all the facets — the silhouette must catch the flashlight. Bases embedded in gold/flesh sockets. The transition reads `flesh → gold dendrites → mineral matrix → crystal`, never `flesh → gemstone glued on`. Create an inner duplicate/core mesh for Godot's fake volumetric interior.

## 13. The root membrane needs its own topology
The root must not simply end at the wall. A separate radial membrane mesh — a thick irregular flower/socket: purple flesh sheet, folds stretching toward the root, irregular attachment border, several gold anchors, crystal nodules, tension wrinkles. Enough radial loops to bulge, thin, stretch around the distal tip, cling during emergence and constrict during withdrawal. Rigged separately. **Critical to making the creature appear to extrude through reality instead of through a hole.**

## 14. More bones than you think
24–32 deform bones along the primary body — not excessive for a 1.6 m hero asset. Supporting spline-like bending, local compression, local twist, distal independence. `ROOT` → 4–5 heavy proximal → 5–6 ocular/midsection → 7–9 flexible mid/distal → 5–8 highly flexible tip. Separate secondary rigs for eyeball, three eyelids, ocular gold, cilia, hero suckers, membrane. B-Bones or spline IK for the primary limb.

## 15. Twist controls
The sucker field must stay correctly oriented through curves. Explicit roll/twist controls along the rig, so the ventral surface can rotate toward a radiator without twisting the whole limb unnaturally. Distribute it: root 10 %, mid 30 %, distal 60 %.

## 16. Squash without destroying volume
Bone envelopes/weights plus corrective shape keys: `BEND_SHARP_LEFT`, `BEND_SHARP_RIGHT`, `DORSAL_BEND`, `VENTRAL_BEND`, `DISTAL_CURL`, `OCULAR_COMPRESSION`, `TIP_FLATTEN`, `ROOT_STRETCH`, `CONTACT_COMPRESSION`. The rig provides motion; shape keys restore believable flesh.

## 17. Peristalsis in the topology
Longitudinal topology must support travelling compression waves. No horizontal hard rings; enough evenly distributed longitudinal loops that a shader or rig can locally expand, compress and shift surface mass. Prototype with Geometry Nodes or shape keys; Godot's shader supplies the fine version.

## 18. Visible muscular sliding
3–6 elongated subdermal ellipsoid/capsule forms under the skin, not rendered, used as deformers (Surface Deform / Mesh Deform or corrective shapes). During bends they create changing muscle masses beneath the epidermis — much more carnal than uniform spline bending.

## 19. Retopologize around deformation
Manually, not entirely Quad Remesh. Mostly longitudinal loops along the shaft; circular-ish but asymmetric topology around the orbit; gold sockets not forced into flesh topology if separate; body topology under the suckers only needs to support the field; radial deformation-friendly structure at the root. Aim 50k–120k quads for the hero body before subdivision.

## 20. Sculpt → retopo → bake
High poly: millions of polygons, full pores, microfolds, tiny mineralization, detailed vascular relief. Game hero mesh: silhouette, major folds, eye socket, gold, suckers, crystals, cilia. Bake normal, AO, curvature, height, thickness, cavity, position. Derive the Godot masks from those maps.

## 21. UVs follow anatomy
A long seam in the least visible dorsal/lateral region; unwrap the body into a relatively straight strip so directional veins, pores, wetness, mineral growth and peristaltic masks are authorable. High texel density at the ocular station, the distal club and the membrane root; lower along ordinary mid-shaft. Gold/crystal/eye on separate UV sets/materials.

## 22. Masks in Blender while the anatomy is available
Vertex colours/attributes for `flesh_thickness`, `wetness`, `vascular`, `papilla`, `gold_root`, `contact_sensitive`, `sucker_region`, `phase_sensitive`, `ocular_region`, `distal_region`. **Don't force Godot to rediscover anatomy procedurally if Blender already knows where everything is.**

## 23. Model for animation clearance
Before finishing detail, test S curve, hard distal curl, figure-eight contact, 90° bend, 180° tip curl, axial twist, sucker-side rotation, root extension, flinch coil. Watch for gold plates colliding, crystals entering flesh, eye deformation, cilia penetrating the cornea, sucker overlap, membrane collapse. Fix before final polish.

## 24. Modular collections
```
DREAM_TENTACLE
├── BODY (body_cage, body_high, subdermal_deformers)
├── EYE (globe, iris, pupil, cornea, lid_dorsal, lid_ventrolateral, lid_nictitating)
├── CILIA (flesh, gold, crystal)
├── GOLD (orbital, structural, dendrites, joints)
├── CRYSTALS
├── SUCKERS
├── MEMBRANE
├── RIG
└── BAKE
```

## The most important modelling rule
**The finished Blender model should look impressive with flat grey materials.** Turn off purple, gold, emission, SSS, wetness and iridescence and you should still see: an irregular muscular animal; an obvious embedded ocular organ; a tactile underside; living exoskeletal structures; different mechanical/anatomical zones; and a silhouette that could not be mistaken for a hose. **Shaders should reveal the anatomy. They should not be responsible for inventing it.**
