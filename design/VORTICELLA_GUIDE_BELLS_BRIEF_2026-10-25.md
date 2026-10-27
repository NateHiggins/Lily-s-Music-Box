# VORTICELLA GUIDE-BELLS — MAINTENANCE BREADCRUMB SYSTEM

Evidence class: **INERT**. Owner implementation requirements, 2026-10-25; not runtime or visual acceptance.

## Chosen organism

Use **Vorticella** as the immobile breadcrumb species.

It is already an authored zoo organism with the correct biology:

- sessile;
- permanently attached by a stalk;
- bell-shaped body;
- ciliated feeding crown;
- calcium-driven contractile spasmoneme;
- able to coil and collapse without becoming mobile;
- visually directional without resembling a conventional arrow.

For clarity, this brief treats “tardigrade prey” as the existing **Euplotes** prey used by the tardigrade lunch system. In this ecology, Euplotes and guide-bell Vorticella have a local symbiosis: the Vorticella concentrates edible microbial matter while Euplotes cleans its stalk and protects its holdfast from fouling. This relationship must not rewrite the existing tardigrade hunting authority.

---

# 1. Player-facing role

A sparse sequence of individual Vorticella appears along the supported route to the current maintenance target.

Each guide-bell:

- grows from a real architectural surface;
- remains fixed to that point;
- turns its bell and ciliary current toward the next valid route segment;
- becomes more biologically elaborate nearer the target;
- reacts to the carried lamp;
- may shelter tiny Euplotes symbionts around its holdfast;
- wilts and disappears once the player is closer to the target than that individual breadcrumb is.

The system should feel like the building has grown a temporary sensory trail—not like a quest-marker system wearing biological skins.

Do not add floating arrows, glowing lines, compass icons, text labels, or path projections.

---

# 2. Core navigation rule

Every breadcrumb stores one authoritative scalar:

```text
remaining_route_distance_from_crumb_to_target
```

During play, compare it with:

```text
remaining_route_distance_from_player_to_target
```

A breadcrumb begins wilting when:

```text
player_remaining_distance
    < crumb_remaining_distance - PASS_MARGIN
```

Recommended starting margin:

```text
PASS_MARGIN = 0.35 m to 0.75 m of route distance
```

Use route or traversal distance—not raw Euclidean distance.

Euclidean distance is insufficient because it fails across:

- floors;
- walls;
- locked doors;
- stair turns;
- lift travel;
- parallel corridors;
- vertically adjacent rooms;
- exterior/interior boundaries.

The same route authority that establishes a supported path to the maintenance target should provide breadcrumb placement and progress measurements.

If no valid route exists, spawn no breadcrumb trail. Never infer a straight-line route through architecture.

---

# 3. Authority boundaries

The breadcrumb system may read:

- current maintenance task identity;
- physical target position or target anchor;
- current supported route;
- player route position;
- loaded route segments;
- door and traversal availability;
- room lifecycle;
- lamp observations;
- encounter seed.

It must not own or modify:

- maintenance task progress;
- task selection;
- target identity;
- door locks;
- lift state;
- inventory;
- repair parts;
- player movement;
- tardigrade hunger or hunting state;
- Euplotes population authority;
- `DreamExposureField`;
- lamp switching or electrical state.

The breadcrumb director is a presentation and bounded ecology adapter.

---

# 4. Trail construction

## 4.1 Eligibility

A trail may exist only when:

- one maintenance task is currently active;
- its physical target is loaded or has a supported route anchor;
- the route authority returns a valid traversable path;
- the task permits directional assistance;
- the player is not already inside the target’s immediate work zone;
- the active scene is not tearing down;
- no incompatible scripted sequence owns navigation presentation.

Do not spawn breadcrumbs for:

- completed tasks;
- canceled tasks;
- purely administrative tasks without a physical destination;
- targets lacking a supported route;
- objectives intentionally requiring discovery without assistance;
- tasks already visible and immediately reachable.

## 4.2 Spacing

Place breadcrumbs sparsely at decision points rather than at constant intervals.

Preferred locations:

- before corridor turns;
- beside the correct stair or lift approach;
- just beyond a doorway;
- at a branch where two routes diverge;
- near a change in floor or region;
- near the final approach to the maintenance target.

Avoid:

- room centers;
- door swing volumes;
- stair treads used by the player;
- manipulation points;
- movable props;
- wet or actively hazardous surfaces unless the species is deliberately adapted to them;
- inaccessible ceilings;
- positions behind the direction of travel;
- locations visible through a wall before their route segment is reached.

Typical trail:

- 3–8 individuals;
- at least 2.5–4 m apart along route distance;
- no more than one at an uncomplicated straight segment;
- denser only around a genuinely ambiguous junction.

## 4.3 Surface selection

Each breadcrumb needs:

- a stable static surface;
- a valid surface normal;
- sufficient clearance for bell and stalk;
- unobstructed view from the expected approach;
- a retreat direction into its holdfast;
- no collision with player navigation;
- no overlap with required controls.

Preferred attachment surfaces:

- floor/wall seams;
- baseboard joints;
- pipe collars;
- drain rims;
- stair-stringer edges;
- wall cracks;
- conduit penetrations;
- radiator feet;
- service thresholds;
- damp grout or masonry joints.

The holdfast must visibly belong to the selected surface.

## 4.4 Monotonic route order

For breadcrumbs ordered from player toward target:

```text
crumb[0].remaining_distance
    > crumb[1].remaining_distance
    > ...
    > final_crumb.remaining_distance
```

Reject any placement that violates this order.

A breadcrumb must point toward:

- the next breadcrumb, if one exists;
- otherwise the maintenance target’s final approach anchor.

It should never point directly through a wall merely because the target is close in world space.

---

# 5. Directional language

Vorticella communicates direction through anatomy.

Each individual should orient:

- bell opening toward the next route segment;
- oral ciliary spiral flowing in that direction;
- internal vacuole chain biased toward the outgoing side;
- stalk bend leaning slightly along the route;
- sheltered Euplotes clustered on the target-facing side;
- lamp highlights concentrated around the forward lip.

The direction should remain readable from the player’s expected approach but imperfect enough to feel biological.

Do not rotate the entire organism like a signpost every frame. The holdfast and stalk base remain fixed. Directional adjustment comes from:

- gradual stalk torsion;
- bell rotation;
- ciliary flow;
- asymmetric expansion;
- sensory papilla alignment.

---

# 6. Modeling instructions

## 6.1 Holdfast

Model a real attachment structure:

- thin secreted pad;
- branching adhesive fibrils;
- embedded grit or plaster particles;
- damp ring around the attachment;
- a narrow transition into the stalk;
- tiny cavities where Euplotes can shelter.

The holdfast should conform to surface curvature.

## 6.2 Contractile stalk

The stalk contains a visible spasmoneme:

- central calcium-responsive contractile fiber;
- translucent sheath;
- helical supporting fibrils;
- small fluid channels;
- periodic attachment nodes;
- slight asymmetry from repeated contraction.

The stalk should be slender but not a simple cylinder.

Its defining behavior:

- extended state: mostly straight with gentle living tension;
- attentive state: slight bend toward route direction;
- alarm state: rapid helical coiling;
- wilt state: loss of internal pressure followed by collapsing folds;
- disappearance: coiled remnant draws into the holdfast.

## 6.3 Bell body

The bell should include:

- flared oral crown;
- peristomial lip;
- ciliary ring;
- cloudy cytoplasm;
- contractile vacuoles;
- food vacuoles;
- macronucleus;
- small micronuclear body;
- cortical fiber bands;
- digestive granules;
- thin posterior attachment zone.

Internal structures must occupy distinct depths.

The bell must not look like a flower or glass goblet. It is a single cell enlarged to an unsettling architectural scale.

## 6.4 Directional ciliary crown

The oral cilia create the primary route cue.

Model or instance:

- several ciliary bands;
- uneven lengths;
- localized gaps;
- directionally biased bend;
- metachronal wave sequence;
- small clumps of trapped particulate matter.

The wave should travel toward the route-facing intake region.

## 6.5 Individual variation

Breadcrumbs share species identity but vary in:

- bell width;
- stalk length;
- crown flare;
- vacuole arrangement;
- pigment density;
- internal granules;
- Euplotes symbiont count;
- degree of mineral inclusion;
- resting torsion.

Variation must not change their directional function or species-defining anatomy.

---

# 7. Euplotes symbiosis

## 7.1 Relationship

Euplotes lives around the Vorticella holdfast because:

- Vorticella’s ciliary flow concentrates bacterial and organic particles;
- Euplotes consumes settled material the Vorticella cannot capture;
- Euplotes clears fouling from the stalk sheath;
- its cirri disturb films that would smother the holdfast;
- the Vorticella provides shelter and a predictable feeding current.

This is a localized mutualism.

## 7.2 Presentation

Each mature guide-bell may show zero to three small Euplotes individuals:

- tucked beneath the bell;
- walking around the holdfast;
- pausing inside adhesive folds;
- collecting particles ejected from the oral groove;
- freezing when the stalk contracts;
- retreating into the attachment seam during wilting.

These should use the existing Euplotes species identity and gait logic where practical.

Do not silently add them to the tardigrade lunch system’s authoritative prey record. They are breadcrumb-owned presentation instances or explicitly borrowed ecology instances with separate ownership.

## 7.3 Tardigrade relationship

The tardigrade recognizes Euplotes as prey and may interpret a guide-bell colony as a feeding site. That ecological association can inform visual storytelling, but the breadcrumb system must not summon or steer the tardigrade.

If a tardigrade is naturally present:

- it may orient toward the colony through existing observation rules;
- breadcrumb Euplotes may hide;
- the Vorticella may contract;
- no guaranteed hunt or task interruption is introduced.

---

# 8. Optical treatment

Use the current instantaneous lamp optical field and shared material receiver path.

Do not use persistent ecological irradiance as direct lamp light.

## 8.1 Bell membrane

The bell should be:

- translucent;
- cloudy;
- opalescent at grazing angles;
- visibly thicker at the oral lip;
- thinner over some vacuoles;
- wet without looking glassy.

Front light reveals:

- cortical texture;
- ciliary roots;
- wet lip;
- restrained specular response.

Side light reveals:

- bell-wall thickness;
- crown folds;
- spasmoneme alignment;
- directional cilia.

Backlight reveals:

- nucleus;
- vacuoles;
- food inclusions;
- rear ciliary silhouettes;
- partial internal occlusion.

## 8.2 Stalk

The stalk shader should show:

- translucent sheath;
- anisotropic helical fibers;
- denser central spasmoneme;
- compression during coiling;
- subtle mineral glints;
- no constant emission.

## 8.3 Direction cue

The route direction must emerge from real optical and animated structure:

- ciliary wave direction;
- asymmetrical bell opening;
- directional internal flow;
- moving suspended particles;
- target-facing opalescent lip.

Do not brighten the “correct side” with an arbitrary emissive mask.

## 8.4 Passed/wilting state

As the player passes a crumb:

- wet highlights dull;
- ciliary motion loses coordination;
- vacuoles collapse;
- cytoplasm becomes denser and more purple-gray;
- the bell folds inward;
- transmitted light weakens;
- the stalk coils and desaturates;
- symbiotic Euplotes hide or withdraw.

This should be anatomical senescence, not a uniform alpha fade.

---

# 9. Breadcrumb lifecycle

Use a strict state machine:

```text
UNSPAWNED
→ GERMINATING
→ INDICATING
→ PASSED_PENDING
→ WILTING
→ RETRACTING
→ CLEARED
```

## 9.1 Germinating

On activation:

- holdfast appears first;
- stalk extrudes;
- bell inflates;
- internal vacuoles separate;
- cilia unfold;
- direction settles toward the next route point.

Duration: roughly 0.8–1.8 seconds.

Avoid spawning in the player’s direct center view when possible. It should appear as something discovered at the route edge.

## 9.2 Indicating

While active:

- stalk remains anchored;
- bell tracks the next route segment slowly;
- cilia maintain a target-biased metachronal wave;
- internal particles flow toward the oral groove;
- Euplotes forage around the base;
- lamp response remains fully physical.

The individual does not follow the player.

## 9.3 Passed pending

Begin a short confirmation interval when:

```text
player_remaining_distance
    < crumb_remaining_distance - PASS_MARGIN
```

Recommended interval:

```text
0.25–0.60 seconds
```

Cancel the pending transition if route recalculation shows the player has not actually passed the crumb.

This prevents jitter near equal-distance boundaries.

## 9.4 Wilting

Once confirmed:

1. Route-facing cilia stop first.
2. Remaining cilia lose wave synchronization.
3. Bell lip droops.
4. Contractile vacuoles empty or collapse.
5. Cytoplasm clouds and darkens.
6. Macronucleus sinks toward the stalk.
7. Euplotes retreat into the holdfast seam.
8. Stalk begins a slow coil.

Duration: approximately 1.0–2.2 seconds.

The wilt should be visible if the player turns around, but it must not demand attention.

## 9.5 Retracting

After wilting:

- bell collapses into a folded translucent mass;
- stalk coils tightly;
- internal material drains toward the holdfast;
- the organism retracts into the seam;
- the adhesive pad dries and flakes;
- remaining particles fade.

Duration: approximately 0.5–1.2 seconds.

Then release:

- render geometry;
- collision, if any;
- receiver registrations;
- particles;
- audio;
- Euplotes presentation instances;
- materials owned uniquely by the crumb.

## 9.6 Immediate cleanup

Skip visible wilting and clean immediately when:

- task is canceled;
- target changes;
- supported route becomes invalid;
- room unloads;
- scene tears down;
- save reconstruction excludes the encounter;
- breadcrumb’s surface owner disappears.

Do not delay teardown to finish animation.

---

# 10. Route changes

Maintenance targets and routes may change while a trail exists.

On route revision:

1. Request a fresh supported route.
2. Keep breadcrumbs that still lie on the new monotonic route.
3. Wilt breadcrumbs now behind or outside the route.
4. Spawn replacements only at new decision points.
5. Do not teleport existing organisms.
6. Do not rotate a breadcrumb toward a target through architecture.
7. Rate-limit trail reconstruction to prevent churn.

Suggested minimum reconstruction interval:

```text
0.5–1.0 seconds
```

Immediate reconstruction is allowed if the current route becomes impossible.

---

# 11. Distance logic pseudocode

```gdscript
func update_breadcrumb(crumb, route_progress) -> void:
    if not route_progress.valid:
        crumb.clear_immediately()
        return

    var player_remaining := route_progress.player_remaining_m
    var crumb_remaining := crumb.remaining_to_target_m

    var has_passed := (
        player_remaining
        < crumb_remaining - PASS_MARGIN
    )

    match crumb.state:
        INDICATING:
            if has_passed:
                crumb.enter_passed_pending()

        PASSED_PENDING:
            if not has_passed:
                crumb.enter_indicating()
            elif crumb.pending_time >= PASS_CONFIRM_S:
                crumb.enter_wilting()

        WILTING, RETRACTING:
            pass
```

Do not recompute `crumb_remaining_to_target_m` from straight-line distance.

When a new route is published, regenerate that value from the new route projection.

---

# 12. Handling backtracking

Once a breadcrumb has entered `WILTING`, it does not recover if the player walks backward.

This gives the trail a clear memory:

- unpassed crumbs remain alive ahead;
- passed crumbs die behind;
- backtracking does not regrow an already consumed cue;
- a completely rebuilt trail may create new individuals only after a meaningful target or route revision.

Do not make organisms repeatedly bloom and collapse around a threshold.

---

# 13. Final-target behavior

The last breadcrumb should be placed near the approach, not directly on the repair control.

It should:

- orient toward the actual work area;
- be more mature and anatomically complex;
- carry the clearest Euplotes colony;
- wilt when the player enters the target work zone or becomes closer to the target than the crumb;
- never obstruct grabbing or manipulating the maintenance apparatus.

The breadcrumb system does not complete, highlight, or operate the repair.

---

# 14. Save and reconstruction

Persist only high-level state if the existing save contract authorizes it:

- active maintenance task already exists elsewhere;
- optional trail seed;
- optional consumed route-segment identifiers if breadcrumb regrowth must be prevented.

Do not save:

- individual cilium phase;
- stalk coil amount;
- shader state;
- material bindings;
- Euplotes local positions;
- particle state;
- optical textures;
- wilt animation progress unless explicitly required.

On load, reconstruct from:

- active maintenance task;
- current supported route;
- current player route position;
- deterministic encounter seed.

Do not restore already-passed breadcrumbs behind the player.

---

# 15. Objective tests

## Authority and placement

- No active maintenance task creates no trail.
- Invalid route creates no trail.
- Valid route creates a monotonic sequence.
- Breadcrumbs occupy stable supported surfaces.
- No breadcrumb blocks a required control.
- No breadcrumb overlaps the player, door travel, or held-object path.
- Breadcrumb count stays within its cap.
- Same seed and route produce the same placements.

## Direction

- Each bell faces the next route segment.
- Final bell faces the target approach.
- No bell points through a wall.
- Stair and floor transitions follow supported traversal.
- Direction remains readable under the carried lamp.

## Passing and wilting

- A player farther from the target than the crumb does not wilt it.
- Equal distance does not wilt it.
- Crossing the configured margin begins pending confirmation.
- Sustained closer distance begins wilting.
- Brief distance jitter cancels pending confirmation.
- Wilting never reverses.
- Backtracking does not regrow a consumed crumb.
- Route revision retires invalid crumbs without teleporting them.

## Symbiosis

- Euplotes remains localized to the Vorticella holdfast.
- Euplotes presentation does not alter the tardigrade lunch owner.
- Stalk contraction causes symbionts to shelter.
- Wilting withdraws symbionts before final retraction.
- Cleanup releases every breadcrumb-owned symbiont.

## Optical response

- Lamp off removes instantaneous optical response.
- Front, side, and backlight reveal different anatomy.
- Bell transmission varies with thickness.
- Spasmoneme and helical stalk fibers respond directionally.
- Cilia outside the cone remain dark.
- Geometry occlusion attenuates the bell and stalk.
- Wilting changes material state anatomically rather than through a uniform fade.

## Teardown

- Task cancellation clears the complete trail.
- Room unload clears locally owned organisms.
- Target change leaves no stale receiver bindings.
- No retained RID, material, texture, particle system, audio player, or route reference remains.
- Maintenance task state is byte-identical before and after breadcrumb presentation, excluding its own independently advancing authority.

---

# 16. Review packet

Capture:

1. Full route with sparse guide-bells visible at decision points.
2. One bell clearly directing the player around a corner.
3. Stair or lift transition without straight-line wall pointing.
4. Front-lit bell anatomy.
5. Side-lit stalk and spasmoneme.
6. Backlit nucleus, vacuoles, and internal depth.
7. Euplotes around the holdfast.
8. Player still farther from target: crumb alive.
9. Player just closer than crumb: wilt begins.
10. Mid-wilt anatomical collapse.
11. Retraction into the attachment seam.
12. Clean passed route with no residue or retained resources.
13. Final breadcrumb near the maintenance approach.
14. Maintenance control remaining reachable and usable.

Machine receipt should include:

- task ID;
- target anchor;
- route revision;
- route length;
- player remaining distance;
- each crumb’s route coordinate;
- each crumb’s remaining target distance;
- surface owner;
- direction target;
- lifecycle transitions;
- spawn and removal reasons;
- optical registrations;
- symbiont ownership;
- retained-resource result.

---

# 17. Acceptance

Accept only if:

- Vorticella remains recognizably sessile;
- the trail communicates direction through biological structure;
- placements follow the real supported route;
- every individual disappears only after the player has genuinely passed it by route distance;
- wilting is irreversible and anatomically legible;
- Euplotes symbiosis enriches the organism without corrupting tardigrade prey authority;
- breadcrumbs never own or advance maintenance work;
- the final approach remains physically operable;
- complete cleanup leaves no stale route, optical, ecological, or rendering ownership.