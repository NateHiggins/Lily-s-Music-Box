# VANTRY SERVICE RADIOPHONE — CARRIED DEVICE REPLACEMENT BRIEF

*Written 2026-08-15 after the owner replaced the carried phone with a radio and
attached work light.*

**Status: CORE DIRECTION RULED; IMPLEMENTATION PROPOSAL — OWNER REVIEW
REQUIRED.** The owner has ruled four facts: the object in the player's hand is
a radio, it carries its own light, it has no screen, and its only display-like
feedback is a lamp indicating that a work order has been filed. Bible §VIII.5.j
records those facts. The dimensions, name, control layout, audio behavior and
migration plan below are the recommended implementation and may be tuned before
production geometry replaces the current handset.

Concept target:
`art/concept/device/vantry_service_radiophone_v1.png`

Concept SHA-256:
`7305D68623F058E59714CA9C8274F92520BBFA93FDE5AB850C718D152501DEE5`

---

## THE ANSWER

Build the **Vantry & Co. Portable Building-Maintenance Service Radiophone,
Model No. 4** — called **the service set** by everyone who has to carry it.

It is a 1912 Vantry house-radio chassis in a last-factory-rebuild case dated
1924. It is a tall, one-kilogram Bakelite brick with a speaker, carbon
microphone, pull-up aerial, side push-to-talk bar and an ordinary forward
tungsten inspection lamp bolted into the upper shoulder. It has no screen,
camera, keyboard, keypad, menu or invented operating system.

One amber glass jewel is stamped **ORDER**. A selective call from the Orison
desk latches it when a work order exists; the authoritative job lifecycle
extinguishes it when the order closes. The lamp does not explain the job and
does not own its state. It says one thing: **there is work under your name**.

This is more plausible, more legible and much more Orison than the current
NOCTURNE 900. It makes the hand part of the maintenance loop rather than a
second game console.

---

## WHY THIS LINEAGE FITS

No single historical product needs to be copied. Five real tool families solve
five separate parts of the object.

| Precedent | Fact worth keeping | Orison use |
|---|---|---|
| U.S. Signal Corps SCR-536 / BC-611, 1942–45 | The War Department manual describes a dry-battery handheld set whose only operating controls are the aerial-operated power switch and side press-to-talk switch. Extending the aerial powers reception; pressing the bar transmits. | Two actions are enough. Pull aerial, speak with the side bar. No menu is missing because no menu exists. |
| Motorola HT200, 1962 | Motorola records the 33-ounce transistorized portable as “the brick.” A New Jersey field guide places every control except push-to-talk on top: on/off-volume and a frequency selector. | The correct mass and durable silhouette: compact enough for one hand, heavy enough to feel issued rather than owned. |
| Pye GP1FM GPO Linesman / Bantam, 1963–65 | Pye made a weatherproof Bantam variant specifically for British Post Office field staff. The Science Museum's related Bantam is 300 × 165 × 70 mm and 1.85 kg, shoulder carried. | Civilian infrastructure work, canvas strap, replaceable battery, field-service screws and a schematic—not military cosplay. |
| Selective-call mobile radio, documented 1960 | A coded call could light a call-indicator lamp that remained lit until deliberately cleared. Later Pye receivers offered individual/group selective calling. | The amber ORDER jewel is an authentic communications behavior, not a tiny fake UI. |
| 1917 Beacon Army light and contemporary telephone switchboard lamps | The Beacon tool used a metal body, glass lens, leather attachment and simple tab switch around a 3.8-volt bulb. Common-battery telephone switchboards already lit a lamp when a subscriber called. | The attached lamp remains ordinary pre-1928 tungsten hardware; the annunciator language is already native to the Orison's switchboard era. |

The radio earns the Rule of Signal's forty-year lead. The **lamp does not**: it
is a warm tungsten bulb, glass lens, brass reflector, tinned-steel hood and
simple contact lever that could have been made before the Orison opened.

---

## FORM AND DIMENSIONS

Production control dimensions:

| Measure | Target |
|---|---:|
| Body height | 225 mm |
| Body width | 85 mm |
| Body depth | 58 mm |
| Lamp lens | 38 mm diameter |
| Mass with battery | 1.1–1.3 kg |
| Aerial stowed / extended | 58 mm / 420 mm above body |

The target deliberately sits between the 935 g HT200 and the much larger field
sets. It is not pocketable. The strap carries the mass while the hand steadies
and operates it. In the normal first-person pose it occupies the lower-right
corner, lower and broader than the current phone, with the lamp shoulder
visible as the source of the beam.

### Front

- large punched-metal receiving speaker high on the face;
- small carbon microphone grille low on the face;
- one amber glass **ORDER** jewel between them;
- small dull-brass Vantry rebuild plate at the foot;
- no dead rectangle where a screen “would have been.” The body is designed
  around acoustic components, not as a phone with its display removed.

### Top and shoulders

- telescopic brass aerial through a cream ceramic collar at rear left;
- one knurled volume wheel, readable by touch;
- forward lamp barrel at upper right, deep enough to suppress side spill;
- replaceable convex glass and threaded bulb bezel.

### Left side

- broad rubber-covered push-to-talk bar under the fingers;
- guarded two-position metal lamp lever, **OFF / ON**;
- strap lug isolated from both controls so carrying tension cannot actuate
  either one.

### Back

- screwed service plate, not clips;
- pasted circuit and battery diagram inside;
- replaceable dry-cell cassette;
- repair dates, scratched initials and one nonmatching screw;
- belt/strap loop, but no tactical webbing or modern rail.

---

## MATERIAL LAW

- brown-black compression-moulded phenolic body, gloss worn dull under the
  palm and chipped pale at corners;
- dull brass or blackened tinned steel hardware;
- glass lenses and ceramic aerial bushing;
- black woven cotton strap with a repaired leather shoulder patch;
- cloth-braided internal leads visible only under the service cover;
- slotted screws throughout.

Ban aluminium, stainless steel, injection-moulded color, rubberized modern
soft-touch, LEDs, liquid-crystal glass and tactical olive drab. The amber ORDER
light is a tiny incandescent jewel, not an RGB status pixel. The forward lamp
is warm and imperfect: a slightly off-center filament, a dirty reflector edge
and a hard glass falloff.

The concept sheet is silhouette and material authority, not topology. The
production model must keep the one-jewel/no-screen rule even if individual
screws or grille perforations change for batching.

---

## THE COMPLETE CONTROL GRAMMAR

The player-facing set has four physical controls and no hidden modes:

| Control | Physical behavior | Game behavior |
|---|---|---|
| Aerial | pull fully out / push fully home | powers radio reception; collapsed is visibly off |
| PTT bar | spring return | hold to transmit, release to listen |
| Volume | top knurled wheel with stops | receive level only; never changes subtitle availability |
| Lamp lever | guarded `OFF / ON` detent | the one public carried-light toggle used by keyboard, controller and touch |

Frequency is fixed to the Orison service net. Changing crystals is a bench
operation under the rear plate, not a player menu. There is no squelch puzzle,
channel inventory, battery meter, compass, map, tuning minigame or “hold for
settings.” The radio may hiss, drift and briefly heterodyne, but it must work as
a tool before it works as atmosphere.

The amber ORDER jewel is an **indicator, not a control**. It has only two
steady states:

- dark — no authored maintenance job remains open;
- lit — at least one authoritative job is in `issued` through `repaired`.

It extinguishes on `closed`. It does not blink stage codes, change color, show
urgency or become a quest arrow. With the current one-job proof there is no
ambiguity. Before a second simultaneous job can ship, the designer must prove
that one lamp remains sufficient rather than quietly turning it into Morse UI.

---

## AUDIO AND FICTION

The service set is tuned to a low-power Vantry house repeater coupled to the
building's point wiring. Within the Orison it behaves like a private field net;
on the STREET and in the Vantry Arcade it survives through the buried service
trunk with more hiss and fewer high frequencies. This is radio, but it is radio
built by people who thought a building was an instrument.

An order filing produces one short relay clack, a two-tone selective-call pair
and the amber jewel coming up. The radio does not read objective prose. A voice
may say “Four-B, an order has been put through,” after which the paper order,
resident, fault and existing objective presentation carry detail.

PTT must sound physical: contact click, half-beat valve/transistor gate, then
sidetone. The player's release click matters as much as the words. In protected
calls, the existing call lock still owns gameplay safety; the radio merely
presents the exchange.

In the dream the station is absent but the set remains. It receives impossible
case fragments because the dream is exempt from the waking Rule of Signal. The
attached lamp—not a screen—is the pursuit decision. The ORDER jewel stays dark
after the case has closed, which gives the release-print dream a small, legible
truth: practical work is finished even while the passage is not.

---

## WHAT HAPPENS TO THE PHONE FEATURES

“No screen” is a content decision, not permission to delete working systems in
bulk. Audit every current consumer before subtraction.

| Current phone responsibility | Destination |
|---|---|
| carried beam, pose, lag and separate render pass | retain behind a renamed device-neutral carried-light interface, then bind to the service set lamp |
| keyboard/controller/touch light input | one public `set_lamp_enabled` / `toggle_lamp` contract |
| work-order/objective information | objective presentation and physical paper/desk surfaces; never projected onto the radio |
| calls and subtitles | radio audio plus existing accessibility presentation; no radio screen |
| camera/viewfinder/gallery | retire from the carried device; if photography becomes required, author a separate period camera and prove its gameplay |
| `cart_pairs`, `cart_maze`, `cart_shards` | archive intact until reviewed as signal-parlour programme material; do not ship them invisibly inside a no-screen radio |
| PhoneOS terminal, QWERTY and screen textures | remove from production instantiation only after dependency and export audits; preserve source history until replacements pass |
| raised readable pose | replace with a brief physical inspection pose only if the ORDER jewel cannot be read in normal carry |

The correct seam is not `PhoneCarrier` renamed in place while it still creates
a camera, CRT viewport and three applications. Introduce a narrow carried-light
contract, make both the old test handset and new control prop satisfy it, migrate
consumers, and only then stop instantiating the phone in production.

---

## PROPOSED OWNERSHIP

```text
WorkOrders ---------------------------> ServiceSetIndicator
 (authoritative lifecycle)                (read-only ORDER jewel)

Call / dialogue owners --------------> ServiceRadioAudio
 (conversation and protection)            (PTT, receive, sidetone)

Player input ------------------------> CarriedLight
 (keyboard/controller/touch)              (public lamp state)
                                             |
                                             v
                                     ServiceSetCarrier
                                     (pose, model, beam transform)
```

- `WorkOrders` remains the only lifecycle authority.
- The device stores no job copy and advances no stage.
- The carried-light interface owns lamp state, not pursuit logic.
- `DreamDirector` observes authoritative lamp state; it does not find a model
  node or call a phone script.
- The carrier owns pose and rendering, not radio conversations.
- Audio owners emit radio treatment; they do not own work orders.

Recommended production names:

```text
game/scripts/device/carried_light.gd
game/scripts/device/service_set_carrier.gd
game/scripts/device/service_set_prop.gd
game/scripts/device/service_set_indicator.gd
game/scripts/audio/service_radio_audio.gd
game/tests/ServiceSetTest.tscn
game/tests/ServiceSetShot.tscn
```

Names are proposed. The ownership boundaries are the important part.

---

## BUILD SEQUENCE

1. **Dependency census.** Enumerate every production and test consumer of
   `PhoneCarrier`, `Phone3D`, `PhoneOS`, camera roll and cart apps. Classify each
   as retain, migrate, rehome or archive. Delete nothing.
2. **Device-neutral light seam.** Put current beam state and toggle behind one
   public owner. Prove the old handset still renders identically through it.
3. **Control prop.** Build the exact silhouette with flat but ruled materials;
   make the lamp origin agree with the visible lens in carry and raised poses.
4. **ORDER jewel.** Bind read-only visibility/emission to real `WorkOrders`
   stages. Prove reported and discovered origins behave identically after issue,
   save/load restores it, and unrelated orders cannot mutate the job.
5. **Radio audio.** Route one real complaint exchange through PTT/receive
   treatment without changing dialogue authority or protection.
6. **Production swap.** Stop constructing the phone only after light, calls,
   touch/controller input, save/load, screenshots, performance and export tests
   pass on the service set.
7. **Archive decision.** Move or cut the camera/cart content in one named change
   after its destination is ruled. Never let unused phone worlds keep rendering.

N3's disposable pursuit corridor may begin after step 3, once the neutral lamp
contract and gray service-set control prop pass together. It need not wait for
ORDER/audio integration or final phone subtraction, but it must not entrench
`PhoneCarrier` in dream code while replacement is underway.

---

## ACCEPTANCE

### Object

- From the carried silhouette alone, five viewers call it a radio or field
  telephone before “phone.”
- No view contains a display-shaped dead zone.
- The visible lamp lens and measured beam origin agree in carry and inspection
  poses.
- All controls can be identified without reading more than `ORDER`, `OFF` and
  `ON`.
- Materials pass Bible §VIII: advanced signal chassis, ordinary 1928 lamp.

### Gameplay

- Keyboard, controller and touch drive the same lamp state.
- The ORDER jewel matches the real lifecycle before issue, at every open stage,
  after closure and after real-file restoration.
- The radio owns no quest transition and cannot duplicate or close a job.
- Calls remain protected and accessible with the device screen removed.
- Production creates no PhoneOS viewport, phone camera world or cart-app tick.

### Visual and performance

- carried-off, carried-on, ORDER-dark, ORDER-lit and inspection-pose renders;
- before/after production frames at the same station, clock and light budget;
- no new shadow caster from the isolated held-object pass;
- no material text smaller than the final carried resolution can actually show;
- performance at every station stays within its measured noise floor or the
  delta is attributed and accepted.

---

## SOURCES

Accessed 2026-08-15.

- U.S. War Department, *TM 11-235: Radio Sets SCR-536-A through -F* (1945),
  public-domain scan and catalogue record:
  https://commons.wikimedia.org/wiki/File:TM_11-235_Radio_Sets_SCR-536-A,_-B,_-C,_-D,_-E,_and_-F,_1945_(IA_Tm11-235).pdf
- Motorola Solutions, corporate timeline, “1962: Motorola HT200 Portable
  Two-Way Radio”:
  https://www.motorolasolutions.com/en_us/about/history/timeline.html
- New Jersey State Law Enforcement Planning Agency, *Project ALERT* equipment
  instructions, pp. 27–32 (HT200 weight, top controls and PTT):
  https://dspace.njstatelib.org/server/api/core/bitstreams/f089954b-ca1d-48f9-9771-7c28a3a8113f/content
- Science Museum Group, Pye Bantam radio telephone sets, 1963–65:
  https://collection.sciencemuseumgroup.org.uk/objects/co35090
- Pye Museum, PMR portables: GP1FM GPO Linesman, PF1 selective calling and
  aerial-operated equipment:
  https://www.pyemuseum.org/divisions/communications/pye_telecom/products/portables.php
- Jack Helmi, *Two-Way Mobile Radio Handbook* (1960), selective-call indicator
  lamp behavior, p. 114:
  https://www.worldradiohistory.com/BOOKSHELF-ARH/Technology/Sams-Books/SAMS-2-Way-Mobile-Radio-Handbook-Helmi-1960.pdf
- E. H. Danner Museum of Telephony, common-battery switchboard call lamps:
  https://www.angelo.edu/community/west-texas-collection/virtual-exhibits/museum-of-telephony.php
- Smithsonian National Museum of African American History and Culture, 1917
  Beacon Army belt flashlight (metal body, glass lens, leather strap, tab
  switch, 3.8 V bulb):
  https://nmaahc.si.edu/object/nmaahc_2017.111.5
- Smithsonian National Museum of American History, railroad hand-signal
  lantern with separate signal and focused flashlight bulbs:
  https://www.si.edu/object/railroad-hand-signal-lantern-1950s-70s%3Anmah_844634

This is design research, not a claim that Vantry & Co. or its apparatus existed.
The fictional set combines documented operating ideas under the project's ruled
alternate history.
