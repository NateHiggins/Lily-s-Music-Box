# SR7-B — the passenger elevator's landing-door interlock

**Status: production-rendered proof complete.**

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn`, at the real F01 elevator
opening, shot through the player's own camera and lit by the lobby's chandelier
and the player's own service lamp. There is no proof-only wall, prop, material,
light or camera rig. The landing door in these frames is the production door,
moved only through the lift's own guarded service setter.

Harness: `res://tests/MaintenanceInterlockShot.tscn` through the serialized
Godot runner with `-Windowed`.

## The truth this teaches

The 1921 code does not require a hoistway door to be **shut**. It requires that
the car not move away from a landing unless that door is *locked in the closed
position* — and those are two different facts, proved by two contacts in series:

| contact | made when |
| --- | --- |
| **SHUT** | the door's leading edge is home |
| **LOCKED** | the latch has entered the keeper to its full depth |

A door can be shut and not locked. The fault this round corrects is not a
broken part — the lock works, the door works, the car answers — it is a
**bridging wire** laid across both pairs, which reads as perfect continuity
while proving neither. `circuit_continuous()` and `interlock_holds()` are
deliberately two different functions in the prop, and a bridge can only enter
the first.

## Sources

- **Otis landing-door interlock**, E. L. Dunn, assigned to Otis Elevator Co.,
  US 1,493,069 — filed 16 September 1921, granted 6 May 1924. A ratchet-and-pawl
  lock at each landing, released by a cam on the car acting through a roller on
  the pawl; stopping at a landing unlocks that door, and an open door locks the
  car's control so it cannot move away.
  <https://patents.google.com/patent/US1493069A/en>
- **American Elevator Safety Code, first edition 1921** (ASME; the A17
  designation arrives with the 1925 second edition). Hoistway-door interlock:
  a device to prevent the car moving away from a landing "unless … that
  hoistway door … is closed and locked (Door Unit System)", and to prevent the
  door being opened from the landing side unless the car is at that landing.
- **Retiring-cam practice.** The cam extends only when the car is level at the
  landing, pressing the roller arm to free the latch; the door-closed contact
  opens as the keeper is left, and the door-locked contact closes only after
  the latch has re-entered and the cam has retired. Both are in the safety
  circuit; jumping them out is the classic dangerous field repair this round
  refuses to portray as a repair.

## The verb chain

Five verbs, 34 seconds, in the three verbs the shared abstraction already
speaks. Transferable verb: **continuity** — the only one of the six ruled verbs
still unclaimed before SR7-B.

| # | verb | id | what it is |
| --- | --- | --- | --- |
| 1 | align | `gauge_keeper` | read how far the latch actually enters |
| 2 | hold_release | `pull_jumper` | hold the bridge against the terminal spring, let it come free |
| 3 | align | `true_keeper` | true the keeper so the latch enters full depth |
| 4 | turn | `bring_home` | bring the landing door fully home |
| 5 | hold_release | `prove_refusal` | crack the door and hold the call — an interlock is proved by what it refuses |

Step 5 deliberately targets **0.22**, not a shut door. An activity that ends
with everything closed proves nothing.

### What refuses, and why

- **Truing the keeper with the bridge still on** — with both pairs jumped there
  is no signal to true the keeper *against*. Refused.
- **Truing before gauging** — nothing to work to. Refused.
- **Proving through a bridge** — the circuit answers "continuous" with the door
  open. Refused; a bridged contact is never a repair.
- **Proving with the door home** — nothing is being proved. Refused.
- **`apply_maintenance_result` asking for `interlock_proved` while a jumper is
  present** — refused by the mechanism itself. No data file can talk this
  interlock into calling itself proved.

Every refusal is a knock and a visible shudder that clears itself, per
`design/PROP_ACTIVITIES.md`: a silent `false` is forbidden.

## Definitive frames

All frames are 1280×720. SHA-256 truncated to 32 hexadecimal characters.
Three framings are used because three claims need different distances; the two
close framings each carry their own frozen A/A pair.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_detail_control_a.png` | `4e1821932c0f716b9a722ac27ef5a7e9` | As found, contact-block framing. |
| `00_detail_control_b.png` | `71f709e4ff2db1c0f3fcc225110fae51` | Same state, same camera — the detail A/A floor. |
| `01_lock_control_a.png` | `0d8cff6759edaaafe9536407a3d06f95` | As found, whole-assembly framing. |
| `01_lock_control_b.png` | `5253e313b3bd08605c3622954064d41d` | Same state, same camera — the assembly A/A floor. |
| `02_landing_context.png` | `1f139eb38f8954a3e26980d86c35b7e7` | The real F01 opening: brass jambs, car gate, cab, call plate, and the interlock on its reveal. |
| `03_bridged_as_found.png` | `92c789374a52d13566d1f69da037ef33` | Both pairs standing open with one copper strap lying across them. The counterfeit, in one frame. |
| `04_bridge_pulled.png` | `818f56e8ab0707a52a0ecacd73e95d92` | The strap gone and nothing else moved. |
| `05_shut_but_not_locked.png` | `810160dc24fd8aec399340ffd2f462c8` | Door fully home: **left pair closed, right pair still gapped.** Shut is not locked. |
| `06_door_home_and_locked.png` | `692358742d7a72a6cd0b47f3d38f569f` | Keeper trued: both pairs closed, latch full depth. |
| `07_door_cracked_refusing.png` | `d62ddaaff3c7264d7ab5180513f38bdd` | Door deliberately cracked: retiring cam extended, latch out of the keeper, both contacts open. |
| `08_committed.png` | `d8a0cef33f5c99e982df71d7f0673a87` | The committed repaired state. |
| `09_lobby_wide.png` | `b834e2b58139ad18631c8e6b91c573e5` | The apparatus in the real Orison lobby. |

A contact here is **a gap that closes**, not a colour change. The first two
proof sheets tried to say "made" with albedo alone and came back unreadable —
in a warm 1928 lobby every small metal face is the same brown. A gap is legible
at any colour temperature, and it is also simply what the hardware does.

## A/A pricing

Normalized RMSE, ImageMagick. The declared detail ROI is `440x260+410+240` —
the contact block — because the frame also contains a door that moves, and a
whole-frame delta would let the door pay for claims about the contacts.

**Detail camera** (ROI floor **0.008039**):

| Pair | Whole frame | Contact ROI | × floor |
| --- | ---: | ---: | ---: |
| control A → control B | 0.005921 | **0.008039** | 1.0 |
| bridged → bridge pulled | 0.026343 | **0.072969** | **9.1×** |
| bridge pulled → door home | 0.199491 | **0.086022** | **10.7×** |
| shut-not-locked → both locked | 0.035156 | **0.071189** | **8.9×** |
| control → repaired | 0.200759 | **0.113033** | **14.1×** |

**Assembly camera** (whole-frame floor **0.002506**):

| Pair | Whole frame | × floor |
| --- | ---: | ---: |
| control A → control B | 0.002506 | 1.0 |
| control → door cracked, refusing | 0.058955 | **23.5×** |
| control → committed | 0.141209 | **56.3×** |
| cracked → committed | 0.131622 | **52.5×** |

Every claim clears the floor of the camera that took it, by 8.9× at worst.

## Executable proof

Every run went through `tools/run_godot_serial.ps1`.

- `MaintenanceInterlockTest.tscn`: **PASS 41/41**. The book validates and stays
  in the 25–40 s window; the order is enforced; all three rejection reasons name
  themselves without moving the chain; a bridged circuit reads continuous while
  the interlock does not hold; a shut door with an untrue keeper makes the shut
  contact and not the locked one; preview publishes nothing; abort restores; and
  no patch can prove an interlock that still carries its bridge.
- `MaintenanceInterlockLiveTest.tscn`: **PASS 39/39**. In the real Orison: the
  interlock stands in the F01 opening on the landing side of the door panels;
  every named part is present; the reach opens the authored activity by name;
  the whole chain lands on the production mechanism; the production landing
  door comes home and cracks under service through the lift's guarded setter;
  and — the point of the apparatus — **the production car refuses to leave a
  landing whose door is not locked, then accepts the very same call once it
  is.** The log carries both: `[ELEVATOR] F01 refuses: landing door not locked`
  followed by `[ELEVATOR] F01 -> F05`.
- `MaintenanceActivityTest`, `MaintenanceActivityLiveTest`,
  `MaintenanceServiceRoundTest`, `MaintenanceJobTest`,
  `MaintenanceDumbwaiterTest`, `MaintenanceDumbwaiterLiveTest`, `OtisTest`,
  `PassageNavTest`, `InteractionInventory`: all **PASS**.
- `WalkTest` (FAST): 2 failures — `production spine loads the one authored job,
  the chirp hunt` and `boiler's long parts list stays merged (23 meshes)`. Both
  are **pre-existing**: the same two, at the same line numbers, fail on a clean
  `d146e68` checkout with these changes stashed. SR7-B adds none.
- `WalkTest` (`WALKTEST_FULL=1`): the elevator section passes in full — all
  eight landings have doors, the doors at the car's landing stand open, the
  landing left behind is sealed, the car reaches F06 and B1, and a rider in the
  cab travels 19.6 m with it. Twelve real rides were accepted and the new guard
  never fired, because an unproved interlock permits everything. The FULL suite
  did not reach its verdict line: it was terminated by the mandated 60-second
  ceiling much later, in the case-network section. That ceiling, not this
  change, is the limit.

## Ownership

The prop owns the interlock and nothing else. It does not own the elevator, its
doors, its car or its state — it asks through `set_landing_door_for_service`
and accepts refusal, and the lift asks back through `permits_car_start`. It
closes no job, advances no case, publishes no plant state, creates no Dream
fact and holds no save record. Only `apply_maintenance_result` changes its
durable local condition.

**The regression guarantee:** an unproved interlock permits everything. A
building whose interlock still carries its bridging wire behaves exactly as it
did before this apparatus existed — which is why twelve WalkTest rides are
unaffected. The refusal is *earned* by the repair.

## What this does not yet close

- **One landing.** F01 only. The other seven stops have doors and call plates
  but no interlock hardware, and `landing_permits_start` returns true for them.
  This is not a claim that the elevator is interlocked; it is one honest
  landing.
- The apparatus is not on the Service Round route, and no job, case or resident
  refers to it. The prop reports completion by signal and waits.
- The car gate remains decoration — a scale-driven brass lattice with no
  collision and no gate contact of its own. A real car-gate contact is the
  obvious SR7-B follow-up and is deliberately not claimed here.
- Noted in passing, not fixed: `player_controller.gd` tests for a `cabin_panel`
  meta that `elevator.gd` never sets, so the cab floor buttons show no prompt
  though they work when pressed, and the prompt string still says "Select next
  floor" for what is now a per-floor panel.
