# K0-PHONE — the house has lines, not generic phones

Status: approved attention-multiplier project. Build in measured vertical
slices. This brief is the product and ownership authority for Orison's 1928
telephone ecology.

## Promise

The Orison should feel connected before it feels haunted. Calls must travel
through understandable physical instruments—bells, lamps, cords, jacks,
switches, trunks and message slips—so a busy, crossed, unanswered or impossible
line is evidence rather than generic horror audio.

Do not place one identical telephone in every apartment. Private service is an
authored fact about occupation, means and dependence. Residents without a set
use the lobby board, public booth, workplace, neighbor or written message. The
absences create the network.

## Existing production truth

The audit on 2026-08-26 found:

- `CallInterface`, `CaseLibrary`, `WorkOrders`, `ServiceRoundDirector` and the
  case directors already own call, report, job and case progression.
- The player carries a no-screen Vantry service radiophone. It receives the
  first service-round call and must remain a distinct maintenance instrument.
- `domestic_anomaly_props.json` places a carbon telephone in Rhea's 3D and a
  telephone-shaped home relay in player apartment 4B. They are anomaly/inspection
  props, not ordinary subscriber network endpoints.
- Mina's 2A object is an intercom, not an outside telephone.
- The street generator includes a metal-and-glass phone-booth shell with no
  modeled working instrument.
- Cases repeatedly refer to open and unanswered lines, but no physical owner
  currently explains ordinary ringing, busy state, routing or message custody.

The project must connect these truths rather than author a second call system.

## Historical foundation

Documented mechanisms and practices:

- Bell Telephone News, April 1920, “Machine Switching”: a manual operator
  throws a listening key, answers “Number, please?”, receives the subscriber's
  **order**, passes it toward an incoming **B operator**, and uses trunks,
  plugs, jacks, ringing and the subscriber **multiple**. Automatic equipment
  gives corresponding work to **senders** and **selectors**.
  <https://telephonecollectors.info/index.php/browse/document-repository/catalogs-manuals/western-electric-bell-system/publications-and-educational-documents-by-date/13034-20apr-bell-tel-news-cleveland-tel-vol-ix-apr20-machine-switching/file>
- A New York message bureau advertised in 1928 that unanswered subscriber
  calls could be redirected and recorded for later delivery. This is the
  period-correct ancestor for the player's message service—not a domestic
  answering machine.
  <https://www.newyorker.com/magazine/1928/04/07/a-system>
  <https://time.com/archive/6656705/message-bureau/>
- The 1928 Brooklyn/Queens/Staten Island telephone directory provides the
  actual regional texture for exchange names, dialing instructions, party-line
  practice, ringing and busy signals.
  <https://ldsgenealogy.com/NY/Brooklyn-Queens-Staten-Island-New-York-City-Telephone-Directory-1928.htm>
- A 1922 Brooklyn-made DeVeau “suite set” is a candidate apartment-house
  vestibule/intercom language, pending a primary catalog scan before replica
  claims are made.
  <https://www.demajo.net/museum/page3.htm>

Documented history, Orison-specific inference and alternate-history behavior
must remain separate in code comments, data and render notes.

## Telephone census

### Required endpoints

1. **F01 lobby house board** — the physical presentation hub. A compact
   apartment-house switchboard/porter position with answering lamps, paired
   cords, apartment drops, an outside trunk, listening/ringing keys, message
   rack and night-service state.
2. **4B player suite set** — ordinary desk or apartment set. Rename/retire the
   “answering machine” fiction without discarding its existing anomaly relay.
   Unanswered calls may produce message-bureau slips at the lobby owner.
3. **3D Rhea subscriber set** — make the existing carbon telephone reliable
   and ordinary before its open-line anomaly. Her ear for room tone and circuit
   occupancy is character evidence.
4. **Street public booth** — complete the existing shell with coin box,
   transmitter/receiver, bell, directory shelf and bounded interaction.

### Candidate private subscribers, subject to placement audit

- 4A Peter: professional deadline and office calls.
- 5A Nadia: contractors, permits and project coordination.
- 5B Cal: older instrument retained as technical/collector biography.

Do not exceed these initial candidates without proving a resident need. Mina's
intercom remains a different network. Residents without subscriber sets are
deliberately served through shared facilities.

## Ownership and data contract

Create one neutral `HouseTelephoneNetwork` presentation/router service. It may
own only transient physical line state:

- registered endpoint identity and extension;
- on-hook/off-hook;
- idle/ringing/connected/busy/open/fault indication;
- which physical cord or trunk currently carries a connection;
- bounded bell and line audio;
- neutral signals such as `endpoint_answered`, `endpoint_unanswered`,
  `line_connected`, `line_released`, and `message_slip_presented`.

It must not issue or close jobs, advance cases, author dialogue, decide who
calls, mutate access, or invent save facts. Existing directors request a
physical presentation and remain sole lifecycle owners. If persistence is
eventually necessary, a separate owner decision and migration proof is required;
the first slice is reconstructible/transient.

Semantic endpoint data belongs in one authored catalog, proposed as
`game/data/house_telephones.json`, containing endpoint, owner/unit, instrument
family, exchange/extension, access class, placement anchor, ordinary use,
source IDs and anomaly binding. No unit-name conditional chain in the prop.

## Ordinary operation before horror

Every endpoint must demonstrate a trustworthy baseline:

- a call request produces exactly one indication;
- a bell is audible only within a measured radius and through the existing
  acoustic model;
- lifting the receiver answers once;
- busy means physically occupied;
- hanging up releases both ends and any cord/trunk indication;
- an unanswered call times out without pretending it was answered;
- message custody transfers through a visible slip, not invisible UI state;
- the public booth requires its documented operating action and returns to
  idle cleanly.

Only after players can read those states may cases introduce a ringing booth
with no incoming number, a connected voice with no B operator, an open handset,
two appearances for one subscriber in the multiple, or a message claiming the
player answered personally.

## House English teaching sequence

Bind to `design/HOUSE_ENGLISH_LANGUAGE_STRATEGY.md` and artifact appendix A04–A06.
The first telephone lesson teaches through mechanism, in this order:

1. **line** — a wire/circuit capable of carrying a call;
2. **asking** — an endpoint requests attention and its lamp answers visibly;
3. **order** — the destination requested by the subscriber;
4. **carrying** — a cord/trunk presently holds the connection;
5. **busy** — physically occupied, not merely unavailable prose;
6. **A / B** — two operator positions/hands in a manual chain;
7. **unanswered** — rung but not taken;
8. **line-says** — an indication, not proof of who spoke.

Proposed first impossible sentence:

> A answered. B did not. Two-B still carries.

Plain-language and parallel-subtitle modes must express the same semantic facts.
Safety, apartment numbers and operating labels remain immediately legible.

## Opening-shift vertical slice

Build only the lobby board, 4B suite set and one existing resident endpoint
first. Player journey:

1. A lobby answering lamp falls for 2B.
2. The player operates the real board or acknowledges it through the existing
   first-shift ritual.
3. The physical action presents the already-owned report; it does not issue a
   duplicate.
4. One ordinary call completes and releases, teaching the baseline.
5. A later call violates exactly one learned fact: the outside operator asks
   “Number, please?” on an incoming resident line while the B indication never
   appears.
6. The player may inspect, ignore or record the contradiction; observation is
   optional unless the existing case owner explicitly consumes the neutral fact.

Do not require the public booth or all candidate subscriber sets to validate
this slice.

## Interaction and accessibility

- Every handset, key, plug and message slip must have a reachable physical
  interaction target without adding movement-blocking collision.
- A simplified operate action may complete the correct cord sequence, while an
  optional detailed mode exposes plug, listening key, ringing key and release.
- Ring patterns need visual lamp equivalents and subtitle/haptic descriptions.
- Color is never the sole distinction between busy, ringing and fault.
- Plain-language interpretation remains available under the House English
  accessibility contract.
- Calls cannot trap the player in modal dialogue; hanging up, walking away and
  timeout behavior must be explicit and recoverable.

## Art and sound budget

Use low-cost, high-readability components: dark finished wood or painted metal,
black hard-rubber/Bakelite forms, nickel/brass hardware, cloth cords, paper
labels, warm low-energy lamps and separate receiver poses. Static cases should
batch; only cords, drops, keys, lamps and receivers remain movable.

Sound set: bounded mechanical bell, receiver lift/set-down, plug insertion,
key action, line bed/sidetone, busy cadence, ringback and paper movement. No
always-playing loop per endpoint. Centralize reusable beds and cap concurrent
telephone voices/bells.

Initial budget:

- lobby board: no more than two dynamic lights, preferably emissive lamps;
- domestic endpoint: no dynamic light and one bounded player only when active;
- public booth: reuse street lighting; no private shadow light;
- no new full-screen viewport, camera, physics body or per-frame tree scan;
- establish a production performance A/B at lobby, 4B and street stations.

## Required tests

### Focused

- catalog schema, unique endpoint/extension and valid source/placement IDs;
- closed line-state transition table and refusal of illegal double answer,
  double connect, connection without indication and release by a stranger;
- one call produces one neutral signal in deterministic order;
- House English/plain render equivalence from the same semantic record;
- source scan proves no job/case/save/access mutation.

### Production-live

- board, 4B, 3D and later booth resolve against real architecture;
- all interaction areas are reachable and add no blocking body;
- ordinary call rings, answers, connects and releases physically;
- ignored call remains unanswered and returns to a clean line;
- one already-owned opening report is presented exactly once;
- no duplicate job, case, objective, dialogue or persistence record;
- abort/snapshot restores apparatus while published consumer facts remain with
  their rightful owner;
- unrelated doors, lights, schedules, acoustic graph, radios, watch network,
  Dream and save state remain unchanged;
- InteractionInventory and WalkTest baseline attribution;
- performance A/B at each affected station under the shipping renderer.

## Render proof

Each slice requires an attractive, production-context sequence:

- ordinary idle board and frozen A/A;
- answering lamp and physical cord path;
- receiver answered versus still ringing;
- message slip absent/present;
- ordinary completed call returned to idle;
- impossible A-without-B state against the ordinary control;
- 4B phone in its lived-in room;
- public booth interior when that phase lands;
- declared crops, quantitative differences and honest temporal-noise floors.

No photograph may rely on captions to explain which mechanism moved. Tune by
the rule of cool after physical truth is legible.

## Delivery phases

1. **PHONE-A — census and ordinary line:** catalog, router contract, lobby board
   and deterministic focused proof.
2. **PHONE-B — first report through iron:** connect the existing opening report
   owner to the physical board without duplicate issuance; production-live and
   opening-shift proof.
3. **PHONE-C — home line and message bureau:** 4B suite set, message custody,
   period-correct unanswered service and first House English learning beat.
4. **PHONE-D — Rhea's trustworthy/open line:** ordinary 3D operation followed by
   the existing anomaly through the same receiver.
5. **PHONE-E — public booth:** complete the street shell, coin/public operation,
   performance proof and impossible incoming ring.
6. **PHONE-F — authored subscribers:** audit and add only justified 4A/5A/5B
   instruments; close census and cross-class render sheet.

Each phase is independently shippable and must preserve the ownership contract.

## Explicit refusals

- No telephone in every apartment for completeness.
- No domestic answering machine in literal 1928; use message-bureau custody.
- No second case, job, objective or dialogue owner.
- No magical call before ordinary operation is demonstrated.
- No modern keypad/smartphone interaction language on period instruments.
- No ring audible through the whole building merely as a navigation hack.
- No historical replica claim without a primary object/catalog source.
- No “immigrant operator voice” assembled from phonetic caricature.

## Completion gate

K0-PHONE is complete only when a new player can explain, from visible and
audible mechanism, who is asking, which line carries the call, whether it was
answered, why a message exists, and exactly what is impossible about the first
broken chain—while tests prove the telephone system itself authored none of the
story facts it presents.
