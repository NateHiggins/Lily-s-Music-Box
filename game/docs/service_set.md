# Vantry service set — production contract

> **2026-08-24 presentation supersession:** the production APIs below remain
> authoritative, but their physical owner is now the Orison Electrical &
> Signal Works **TYPE 28-R**. TL-1 replaces the compact Model No. 4 silhouette
> with the measured historical chassis and five-landmark instrument/service
> grammar proved at `art/renders/model_28r/tl1_historical_silhouette/README.md`.
> The older Q4 renders are the visual baseline, not the current body.

*Landed 2026-08-15. This describes the code that exists. The historical and
fictional design authority remains `design/VANTRY_SERVICE_RADIOPHONE_BRIEF.md`
and Bible §VIII.5.j.*

## Player-facing controls

| Verb | Desktop | Touch / remappable action | Physical result |
|---|---|---|---|
| Interact | `E` | `interact` | uses the first authored world mechanism under the 2.1 m eye ray; while seated it operates the remembered seat instead of trying to reacquire a ray behind the player; after a non-modal object response, a powered set advances a service-wire field slip |
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

## The field-slip printer

The carried TYPE 28-R now has a Blender-built mechanical teletype attachment.
The complete supplied field report (title, body and condition) prints in ink on
persistent paper. Long reports wrap into pages without dropping their tail.
The type carriage traverses, hammer strikes, platen turns and ribbon spools
advance with the printing; tick and feed sounds accompany the mechanism.

**T** raises/lowers the set for reading; **[ / ]** feed previous/next pages.
The normal carry pose keeps the paper and feed assembly visible at the right.
Reading does not seize the mouse or pause the world. Modal interactions retain
input priority. These are remappable actions; dedicated touch controls remain
future work. The latest paper remains visible when the radio is switched off;
printing pauses and new reception is refused. Page turning resumes with power.

`TelegramHud.card_presented` feeds the physical printer, so full service-wire
cards share the same copy. The existing HUD remains an accessible enlarged
copy. Direct `print_telegram_card` callers can supply either a full dictionary
or a legacy title string. This is a physical output device, not a new AI service,
case owner or source of invented observations. Only the current report is held
in the printer; no new campaign save field is added.

The authored Blender source and reproducible builder are
`art/models/service_teletype/service_teletype.blend` and
`art/tools/build_service_teletype.py`. Lettering remains runtime Label3D ink.

The real torch emitter is now 18 mm right, 18 mm down and 35 mm forward of the
camera, facing along the view axis, for useful light against nearby surfaces.
The optical field and shadows still observe the same PlayerController light.
The held object has its own close carry pose; the optical origin intentionally
no longer follows the forward-most decorative lens (owner request, 2026-09-26).

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
| beam pose, lag and separate held-object pass in `phone_carrier.gd` | migrate | rewritten in `service_set_carrier.gd`; beam origin is eye-adjacent for close work |
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
  areas, powered/off field-slip behavior, shared non-modal telegram, a real 4B
  fridge ray open and close, 203/203 functional E owners, bench release and
  support-desk release.
- `ServiceSetShot.tscn`: carried lamp on/off, front ORDER and rear modification
  renders under production lighting.
- `TelegramStyleShot.tscn`: production HUD hierarchy and physical crown slip.
- `WalkTest.tscn` at `WALKTEST_SCALE=8`: PASS at 480 Hz after the interaction
  areas and seat changes.

Proof renders and exact commands are in
`art/renders/service_set_q4/README.md` and
`art/renders/telegram_style_i3/README.md`.
