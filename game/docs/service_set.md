# Vantry service set — production contract

*Landed 2026-08-15. This describes the code that exists. The historical and
fictional design authority remains `design/VANTRY_SERVICE_RADIOPHONE_BRIEF.md`
and Bible §VIII.5.j.*

## Player-facing controls

| Verb | Desktop | Touch / remappable action | Physical result |
|---|---|---|---|
| Interact | `E` | `interact` | uses the first authored world mechanism under the 2.1 m eye ray; while seated it operates the remembered seat instead of trying to reacquire a ray behind the player |
| Work lamp | `L` | `lamp_toggle` / `LAMP` | moves the guarded two-state lever, changes the real SpotLight3D, beam plates and rear `LAMP` jewel together |
| Radio power | `R` | `radio_toggle` / `RADIO` | pushes the aerial home or pulls it out and changes the rear `NET` jewel |

Controller shoulders feed those same actions: left shoulder operates the lamp
and right shoulder operates the radio/aerial. N3 proves keyboard, controller and
touch converge on the one public lamp owner; there is no controller-specific
dream behavior.

The work lamp and radio are physical controls and remain available during a
protected conversation. `E` is the only world-interaction verb. Locked modal
interfaces continue to own their other input.

## The three lamps

- front amber `ORDER`: read-only projection of `WorkOrders.has_open_work()`;
  lit if any simple order or authored maintenance job is not closed;
- rear green `NET`: radio/aerial circuit powered;
- rear red `LAMP`: attached tungsten work-lamp circuit powered.

The rear pair was an owner amendment after the concept approval. They report
the two circuits in the player's hand; they do not encode quest stage, urgency,
battery percentage or messages. `ORDER` remains the sole task-state display.

`ServiceSetProp` listens to both WorkOrders transition signals and
`RealityState.state_changed`, so live transitions and mid-session restore both
recompute the aggregate. It owns no order copy and calls no lifecycle method.

## Production ownership

```text
InputMap / touch HUD
        |
        v
PlayerController.set_lamp_enabled()
        |                         WorkOrders + RealityState
        |                                  |
        v                                  v
real SpotLight3D              ServiceSetProp indicators
beam masks                              ^
        |                               |
        +------ ServiceSetCarrier ------+
                 pose / isolated pass
```

`BuildingRoot` constructs `ServiceSetCarrier`, not `PhoneCarrier`. The held
object still needs one isolated 3D SubViewport so it cannot clip through door
frames or be crushed by the room's screen-space beam treatment. The physical
set contains no screen SubViewport, camera world, PhoneOS, gallery or cart-app
tick.

## Phone dependency census

No old file was deleted. The classification performed before the production
swap is:

| Old responsibility / consumer | Decision | Production state |
|---|---|---|
| beam pose, lag and separate held-object pass in `phone_carrier.gd` | migrate | rewritten in `service_set_carrier.gd`; beam origin is the modeled lamp lens |
| spotlight and beam plates in `player_controller.gd` | retain behind neutral seam | `set_lamp_enabled`, `toggle_lamp`, `lamp_is_enabled`; variable is `carried_device`, not PhoneCarrier |
| cold LED color | replace | warm tungsten `(1.0, 0.80, 0.56)` |
| Phone3D screen, QWERTY, trackpad, camera/viewfinder/gallery | rehome or archive | source remains; no production instance |
| `cart_pairs`, `cart_maze`, `cart_shards` | archive pending signal-parlour ruling | source and focused historical tests remain; no production instance or tick |
| `PhoneShell.tscn`, `Phone3D.tscn`, phone viewer/device scripts | archive | direct historical harnesses only |
| old phone carry/camera/light shot tests | historical proof | retained, no longer production acceptance |
| `PhoneLightMask` | retain implementation, legacy name | still provides the carried beam's photographic plate/cookie treatment; owns no phone state or UI |
| debug torch gain and building-personality flashlight observation | retain | both observe the real PlayerController light and are device-neutral in behavior |

The old app tests that begin by looking up `root.phone_carrier` are historical
and intentionally no longer describe the production building. They are not
silently pointed at a fake radio-shaped PhoneOS.

## Universal E contract

`FunctionalProp` now creates a nonblocking, visual-bounds-derived Area3D for
every subclass that publishes both `interact_prompt()` and `interact()` but did
not already author an interaction area. Existing mechanism-specific areas win.
This exposed complete behaviors that previously had no ray owner—including all
18 refrigerators, stoves, bookshelves and several parlour activities—without
adding movement collision.

Seats register themselves as `PlayerController.seated_interaction`. This fixes
the old deadlock: a seat set `call_locked`, PlayerController returned before
polling `E`, and the player's new position no longer faced the original seat
volume anyway. While seated, the same E action directly operates the remembered
owner. Bench, bar seat and support desk all use this contract; Esc still leaves
the support interface through the same release path.

## Proof

- `ServiceSetTest.tscn`: production scene; no PhoneCarrier/Phone3D instance,
  no screen viewport in the prop, lamp/radio/ORDER transitions, 18/18 cold-box
  areas, a real 4B fridge ray open and close, 203/203 functional E owners, bench
  release and support-desk release.
- `ServiceSetShot.tscn`: carried lamp on/off, front ORDER and rear modification
  renders under production lighting.
- `WalkTest.tscn` at `WALKTEST_SCALE=8`: PASS at 480 Hz after the interaction
  areas and seat changes.

Proof renders and exact commands are in
`art/renders/service_set_q4/README.md`.
