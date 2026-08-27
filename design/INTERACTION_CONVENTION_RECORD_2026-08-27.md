# Interaction convention record: `has_method` is not a contract

**Status:** ADMIN-INT1 documentation-only audit, 2026-08-27. This records the
interaction convention the current Orison production happens to obey. It does
not create a Godot interface, base class, registry, compatibility promise or
extractable engine API. No runtime code changed for this task.

## 1. Ruling

The production player does not consume an interaction contract. It performs a
physics ray, walks from the collider toward the scene root, and asks each node
at runtime whether a method with a particular name exists. The prompt pass asks
for `interact_prompt`; the action pass separately asks for `interact_area` and
then `interact`. Godot verifies only that a method name exists. It does not
verify that the prompt and action form a pair, that arguments or return values
have the expected shape, that the call is safe in the current state, or that a
second project can use the object.

Therefore:

- `has_method("interact_prompt")` means only *this node has a callable with
  this name*;
- a shared spelling is a convention, not an interface;
- the current convention may guide a future interface, but must not be called
  engine-grade, portable, extractable or licensable;
- implementing a base class while documenting this seam would violate the
  extraction boundary's phase-1 stop rule.

## 2. The convention actually dispatched today

The authoritative consumer is
`game/scripts/player/player_controller.gd`.

| Surface | Observed call shape | Meaning in the current player | Actual guarantee |
| --- | --- | --- | --- |
| Prompt | `interact_prompt() -> String` by convention | Supplies carrier-free action copy. The player strips a leading legacy `[E]`, `[A]` or `[TAP]`, adds the active input carrier and hides an empty result. | Name existence only; the return is passed to a typed `String` parameter and a wrong type can fail at runtime. |
| Primary action | `interact(player: Node) -> Variant` by convention | Called on the first ancestor that has the name. | Name existence only. Return types in production include `void`, `bool` and `Dictionary`. |
| Area action | `interact_area(area: Area3D) -> Variant` by convention | If the ray collider is an `Area3D`, this takes precedence over `interact` on the same/ancestor node. | Name existence only. The area is the hit collider, not the player. |
| Card fallback | `service_wire_card() -> Dictionary` by convention | Used only after the authoritative action when its result is not a dictionary with non-empty `body`. | Optional duck-typed presentation hook; an invalid or body-less dictionary is silently ignored. |
| Seated action | same prompt and `interact(player)` names | A stored `seated_interaction` may answer E through `call_locked`, even when the original collider is no longer under the ray. | The owner must arrange and later clear the seat lock; no shared lifecycle enforces it. |
| Functional child | `control_prompt(id)` and `interact_control(id, player)` | `PropControlArea` adapts one child ray target into a larger prop's named control. | This is an adapter convention. The player does not know these names and the owner has no declared type. |

The two player passes are intentionally separate:

1. `_update_prompt()` raycasts 2.1 metres, special-cases elevator metadata, then
   walks ancestors until it finds `interact_prompt`.
2. `_try_interact()` performs a new 2.1-metre raycast. For an area hit it first
   seeks `interact_area`; otherwise it seeks `interact`.
3. After either action call, the player attempts service-wire presentation and
   emits `world_modified`, regardless of the action's return value and without
   proving that durable world state changed.

That last signal name is broader than its evidence. Consumers may treat it as
an interaction stimulus, but ADMIN-INT1 does not retroactively promise that
every emission denotes a mutation.

## 3. What an implementor must do to work in this game

This is a producer checklist for current Orison code, not a public API.

1. Put a ray-reachable collision owner on layer 1 within the player's 2.1 m
   reach, or place the answering node in that collider's ancestor chain.
2. Provide both `interact_prompt() -> String` and `interact(player: Node)` when
   the same ordinary world target should advertise and answer E. An empty
   prompt deliberately hides the affordance; it does not disable dispatch.
3. Keep prompt evaluation observational. `_update_prompt()` may call it every
   frame, so it must not mutate state, allocate durable owners, play effects or
   depend on a preceding action call.
4. Author semantic prompt copy, not an input device. Legacy carrier prefixes
   are tolerated for migration but stripped and replaced by the player.
5. Treat the passed player as a caller capability, not as state storage. Modal
   panels and seats must release any lock they acquire.
6. Make the action authoritative before returning presentation data. A
   dictionary card cannot open a job, acquire an item or substitute for the
   prop/case/work owner.
7. Return a dictionary with a non-empty `body` only when the interaction should
   offer a service-wire card. Otherwise return `{}`, `false` or no value as the
   existing owner requires. Do not make gameplay depend on the card being
   printed: modal/call-locked states and a missing/refusing carried printer
   suppress presentation.
8. For one large mechanism with several physical endpoints, use one
   `PropControlArea` per endpoint and keep state in the parent mechanism. A
   control owner must provide both `control_prompt(id)` and
   `interact_control(id, player)`; a missing half fails silently.
9. Use `interact_area(area)` only when the identity of the exact hit area is
   authoritative. Remember that it outranks `interact` during an area hit.
10. Test reach, non-empty prompt, dispatch, side effect/refusal, repeated use,
    and any card separately. `has_method` proves none of them.

## 4. Return and presentation dictionary convention

`TelegramHud.card_from_interaction()` accepts the action result first. If it is
not a `Dictionary` with a non-blank `body`, it asks the owner for
`service_wire_card()`. `TelegramHud.present()` currently reads these keys:

| Key | Required? | Default / behavior |
| --- | --- | --- |
| `body` | **Yes for display** | Blank suppresses the card. |
| `title` | No | `FIELD OBSERVATION` in the HUD; the carried printer request uses `FIELD COPY`. |
| `condition` | No | Blank hides the condition line. |
| `stamp` | No | `FIELD COPY`. |

Unknown keys survive in `last_card` but have no promised meaning. The
dictionary is presentation data, not a success envelope: there is no common
`ok`, `changed`, `reason`, `state_before` or `state_after` field.

## 5. Census and counterexamples

Static census at `bc6f167` plus the documentation working tree on 2026-08-27:

| Definition | Files under `game/scripts` |
| --- | ---: |
| `interact_prompt` | 65 |
| `interact` | 71 |
| `interact_area` | 6 |
| `service_wire_card` | 37 |
| `control_prompt` | 18 |
| `interact_control` | 18 |

The counts themselves disprove an interface claim. Two files define a prompt
without a same-file `interact`: `wayfinding_signage_pass.gd` dispatches through
`interact_area`, while `projector_prop.gd` advertises a prompt without either
player action name in that file. Eight files define `interact` without a prompt:
the two `arcade/swc_*` objects and six maintenance mechanisms reached through
control adapters. These may be intentional compositions or defects; method
discovery cannot distinguish them.

Representative valid variations also prevent a fictional single return type:
`case_interactable.gd` returns `Dictionary`, `switch_plate.gd` returns `void`,
and `arcade/swc_door.gd` returns `bool`.

## 6. Explicit non-contracts

Nothing in the current seam guarantees:

- a prompt has an action, or an action has a prompt;
- argument count, argument type, return type or dictionary schema;
- reachability, collision layer, ancestor placement or stable dispatch order
  after a scene-tree edit;
- idempotence, save reconstruction, authorization, refusal feedback or an
  observable before/after state;
- that `world_modified` corresponds to a mutation;
- that prompt evaluation is cheap or side-effect-free;
- keyboard/controller/touch copy beyond the player's current formatter;
- compatibility between releases or consumption by a second game.

Tests that call `has_method` merely repeat discovery and must not be cited as
interaction proof. A meaningful test calls the prompt and action through the
production owner, observes the relevant state/effect, and proves refusal and
repeat behavior where applicable.

## 7. Candidate future contract — requirements, not design

After the first friends build, if a second reference project justifies this
work, a real interaction contract would have to make the presently implicit
choices explicit: capability discovery, prompt type, caller/context type,
area/control identity, a discriminated result, mutation versus stimulus,
presentation payload, modal lifecycle, reachability registration, and versioned
compatibility. It would also need an adapter for existing props and a measured
rewrite list.

Do not infer that a `class_name Interactable` is the answer. Godot inheritance,
composition through child areas, resident conversations, seats, elevator
metadata and multi-control mechanisms place different pressures on the seam.
The second consumer must falsify or select the design. Until then the durable
artifact is this record of behavior and absences.

## 8. Closure

ADMIN-INT1 is complete when this document is present and linked from the engine
extraction audit. It closes only the request to write the missing convention
down. It does **not** advance any subsystem above the extraction audit's
“game-only” classification and does not satisfy second-consumer proof.
