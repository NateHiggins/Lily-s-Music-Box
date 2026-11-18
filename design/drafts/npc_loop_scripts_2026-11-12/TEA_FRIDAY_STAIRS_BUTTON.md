# Four early leads: playable performance draft

Evidence class: **INERT**.

**All new writing and staging below is PROPOSED.** Quoted SOURCE lines retain
their existing draft status; quoting them is not approval. No runtime edits,
voice generation, capture, implementation or artistic acceptance is claimed.
Lily dialogue: **OWNER-REVIEW PLACEHOLDER ONLY; no new lines supplied**.
Mina's held **mv_struck** is untouched. **WR-03 remains held**.

Authority: **game/data/temporal/anchors.json**; the four named speaker files in
**game/data/mystery/** and **game/data/dialogue/**; **resident_motives.json**;
**design/ORISON_BIBLE.md** VIII.2, VIII.5.c/o, RUL-015/016;
**design/NPC_LOOP_PERFORMANCE_PLAN_2026-11-12.md**. Direction follows the updated
machinima **directorial-ruleset.md** and **interactive-presentation.md**.
These are four proposed encounter packages, not replacement JSON schemas.

Common contract: retain player view/look/movement and existing interaction and
choice controls. No forced camera, new input lock, compulsory speech, slow time,
reward, clue method or property. Hands approach real props and release before
locomotion; blocked reach waits or cancels rather than clipping or teleporting.
Listening is an unfinished practical action, never another talking idle.

**ResidentConversations.with_mystery/_graft_thread_nodes** marks **mt:** heard at
thread-root entry, not voice completion. Preserve that even if interrupted;
already-heard topics cannot be made universally replayable by this draft. Node
flags remain their current owner's grants, separate from physical **loop:** clues.
**TemporalLoop** owns steps, taking, visit/rerun/expiry and retained evidence;
**orison_v2_loop_stage.gd** owns the modelled carrier interaction. Acting consumes
those results only. At expiry cancel presentation and release owned contacts;
let the existing visit owner rerun/return. Do not extend its hours. Repetition
restores dated NPC knowledge, not a resident memory of the player's earlier trip.

### PROPOSED sustained visit rhythm and movement

The opening exchange is a small part of each visit, not its entire population
simulation. The following intervals are writing coverage inside the source
windows, **not additional eligibility gates**. Source ambiguities below remain
unresolved. Between beats residents work, listen, eat or rest; no actor patrols
merely to look alive. Earlier-period knowledge does not inherit a later confession.

| Visit | Beginning | Middle | End / safe departure |
|---|---|---|---|
| **tea** | 16:20–16:30: Mae occupies her own room; service access and the existing tray action remain visible. No early **mk_tea**. | 16:30–17:15: eligible exchange, then appraisal/tea business. Nadia is a visitor only if her attendance owner supports arrival; she is not made to wait forever for the player. | 17:15–17:30: finish the current safe placement; Mae returns attention to her room. Nadia's departure needs an actual doorway path and an arrival/exit interval, never an offscreen disappearance. |
| **friday** | 18:20–18:40: Cam is on his round. Keep his room's quiet physical search distinct from a conversation with a missing actor. | 18:40–19:40: owner-supported arrival, jersey/route business, food or ordinary rest only when his schedule permits. One moving foot is enough; he need not circle the table. | 19:40–20:00: conversational attention gives way to the next legitimate task. Leave the egress clear; the player can continue the permitted carrier action without holding Cam hostage. |
| **stairs** | 03:02 onward: after the blackout, urgency belongs to Teresa's yard task. Do not invent access to an already written future note. | After the existing owner establishes note time/custody: room-carrier action and a possible return are separate from yard testimony. No new fixed minute is decided here. | Before 03:40: Teresa completes a safe hand action or remains at essential care; she does not abandon the yard to perform an exit. Visit expiry clears only presentation, not the care task. |
| **button** | 05:00 onward: Lena's quiet work and reachable existing carriers; no retrospective 06:00 speech yet. | A valid post-arrival **lo_book** opportunity, once the owner reconciles the source times; practical conversation between work actions. | Through 06:20: complete a knot/placement or set the work down. Do not rush a needle gesture to finish a line. The player may leave without a social penalty. |

**Travel and contact policy, PROPOSED.** Actor marks must be places reachable by
their actual path, not cinematic coordinates. Before an optional exchange, allow
the existing route its measured door/stair/corridor travel plus settling and
release time. If that margin would consume a hard appointment, omit the exchange;
do not speed-walk, slide, stretch the visit or hold an endpoint until the player
arrives. Arrival is observable: clear the threshold, stop with weight supported,
then turn eyes/head toward the speaker. A departing actor looks to the path,
releases a reserved surface, and walks out under navigation. No fixed travel
seconds are claimed without route measurement.

For an interrupted tray/parcel move, the interaction owner retains the player's
held object; an actor never takes a duplicate to finish the gesture. An interrupted
NPC action releases only its own prop after a safe supported placement, or stays
in the current safe hold until its owner can release it. Voice stops when attention
ends; a gesture already touching something finishes safely without speaking on
at a departing player. On return, use current work state, not the earlier tableau.

**Optional PROPOSED connective lines** — each may be omitted for silence; none
explains evidence or creates a new branch:

- **TEA-P02 MAE**, after a genuine service interruption: “One moment. That was where I had it.”
  She compares the real table space with her intended placement, then handles only
  an unheld ordinary item. Her certainty is local, not a disguised confession.
- **FRIDAY-P02 CAM**, if still legitimately present after answering: “You can look. I'm eating.”
  If no existing food/meal is available, omit both line and eating gesture. A
  route book can matter while the courier also needs his supper.
- **STAIRS-P02 TERESA**, only during a supported pause in care: “You can stand there. Just leave me the way through.”
  She waits for a clear path rather than physically pushing the player. No joke,
  diagnosis, new command objective or clue is attached.
- **BUTTON-P02 LENA**, after an ordinary work item has been safely set down: “There. Now your hands are your own.”
  Let her notice the hands remain tense and choose not to ask. Do not award trust,
  mend the player's clothing or assume they helped if they did not.

## TEA — a room already being used

**Source-derived contract.** **tea**, “The radiator in 6C,” 1929-06-13,
16:20–17:30 (70 minutes), tier 1, no prerequisites; first call free. Steps:
**in_6c** (at 6C), then **lift_6c_tea_tray** (shift **6C_tea_tray**,
axis [0,1,0], reach 0.18). Physical clue **order_slip**, resting at
**6C_tea_tray**: “A Photo Supplies order slip.” Its exact text is:
“PHOTO SUPPLIES. THURS. 13 JUNE. MRS. K., 6C. THE DEED NEGATIVES, ALL OF THEM. ACROSS IT IN ANOTHER HAND: NOT FOR SALE. A.V.”

**Intention / PROPOSED staging.** Mae wants a service visit to remain a service
visit; Nadia refuses the way Mae reduces a person to a counter. The player is
useful enough to be overlooked. Keep the open window, cold radiator and sweating
iced-tea glasses legible together. Mae's first look is at the player's hand near
the walnut, then at the hand's owner. Nadia listens without nervously decorating
the silence. No approving smile or score treats Mae's bigotry as charm or evidence.

At 16:20 the player can work the room; the source **mk_tea** conversation is
available only 16:30–17:30. Do not start it early to fill the gap. Optional
PROPOSED **TEA-P01**, Mae, if the tray is obstructing the player's existing reach:
“The glasses are full.” She stops arranging the table and watches the tray clear
the surface, a small assertion of jurisdiction rather than a new puzzle hint.
No new pickup, spill simulation or trust consequence follows.

**SOURCE delivery** from **mae_kessler.json**, **mk_tea → mk_t1**:
“The valve is behind the walnut, not on it. The person from the counter can leave the copies there.”
Keep the player-facing choice **“Stay at the valve.”** and existing silence route
to **mk_t2**, Nadia: “Miss Voss.” Nadia's gaze reaches Mae before her chin turns.
Mae looks at Nadia only after the name; **mk_t3**: “I know who you mean.” Let her
hand remain still for the answer. Its **m_tea_seen** grant remains node-owned.
**mk_t4**, including **m_motive_known**, is an existing Nadia continuation, not
new connective dialogue; its deed-clause material needs the existing WR-03 review.
Do not silently rewrite, truncate or approve that node in implementation.

**Agency / handoff.** Silence already follows the authored choices; looking away
does not grant the slip. Leaving ends owned delivery; Mae returns attention to
her room, not a pursuit. On interruption, preserve heard-at-entry and committed
node flags; do not restart the thread for a second performance. A repeated visit
does not make Mae recognize the traveller. The tray/step and actual clue-taking
result, never Nadia's last syllable, govern **order_slip**. Missing the window or
expiry uses the common visit contract. Owner boundary: physical evidence remains
TemporalLoop/stage; reviewed text and presentation remain separate deliverables.

## FRIDAY — the book is work, not revelation

**Source-derived contract.** **friday**, “Friday's errand,” 1929-07-19,
18:20–20:00 (100 minutes), tier 2; prerequisite **order_slip**. Steps:
**after_1840** (after 18:40), **in_4c** (at 4C), then **lift_4c_jersey**
(shift **4C_jersey**, axis [0,1,0], reach 0.25). Clue **route_leaf**,
rest **4C_jersey**, “A leaf from Cam's route book”:
“FRI. 19 JUL., 6.40 P.M. 6C TO MR. EWALD. HOLD. FIRST RUN SAT. THE FLAP IS MARKED ACROSS IN HIS PENCIL.”

**Intention / PROPOSED staging.** Cam wants the next action stated plainly, and
he is better at a round than a rest. The player wants the outgoing errand, not
proof that Cam understands its contents. Low yellow sun, open windows and the
jersey where he came in establish a recently interrupted working day. Before
18:40, follow the anchor's wait instruction; do not produce a second Cam waiting
in 4C. On his supported arrival, give him a clear exit. His foot starts another
step before his attention settles on the player. Listening costs him movement,
not an automatic joke. No bicycle, held envelope or rack prop is newly promised.

Optional PROPOSED **FRIDAY-P01**, Cam, on player obstruction at the threshold:
“Room for one more.” He waits for space instead of shoulder-checking the player.
Once clear, he finishes his movement before answering; no route or trust flag.

**SOURCE choice chain**, **cam_ortiz.json**: **co_envelope → co_e1**:
“Ten past six. Six C. In her hand.” If the player selects **“Did she read it?”**,
**co_e2**: “I deliver envelopes. Nobody's offered a rate for thoughts.” That node
owns **m_envelope_delivered**. Cam looks at the player here, refusing an inference,
then releases his gaze. **co_route** requires that flag; possessing **order_slip**
alone must not be treated as meeting it. At **co_r1**, preserve the choice
**“Friday the nineteenth. After six.”** and **co_r2** exactly:
“Book says. "Fri. 19 Jul., 6.40 p.m., 6C to Mr. Ewald, hold, first run Sat." She gave it me at the door. I put it on the rack, pencil across the flap, C.O., six-forty, so nobody can say I opened it. She does it about once a month, it's an estate, they love a Saturday. First run, down the road, eight-fifty. Done.”
Give each timing its weight without adding ominous foreknowledge. **m_route_book**
is that node's grant; it is not the physical leaf.

**Agency / handoff.** A silent player can follow existing **co_e1s/co_r1s**
routes; do not add a second silence punchline. Leave/interruption releases Cam
to his valid agenda, preserving entry-heard flags and existing grants. Returning
is not permission to replay heard topics or infer an opened envelope. The jersey
action remains playable without a mandatory dramatic performance. Expiry stays
20:00; this scene cannot drift toward the murder. No advance enters July 19
21:01–July 20 03:02. Physical leaf, wall prerequisite and dialogue knowledge remain
with their separate existing owners; no animation grants or confession.

## STAIRS — practical care after the unrecorded hours

**Source-derived contract.** **stairs**, “The stairs before light,” 1929-07-20,
03:02–03:40 (38 minutes), tier 2; prerequisite **order_slip**. Steps:
**in_1d** (at 1D), **lift_1d_flask** (shift **1D_flask**, [0,1,0], 0.16),
then **lift_1d_fob_watch** (shift **1D_fob_watch**, [0,1,0], 0.12).
Clue **nurse_note**, rest **1D_fob_watch**, “Teresa Vale's note”:
“3.05 A.M. ADELA VOSS. REAR YARD. RIGHT HAND: SHREDS OF WHITE KID LEATHER UNDER THE NAILS. T.V.”

**Intention / PROPOSED staging.** Teresa wants useful help and an accurate record,
not an audience for distress. The player can know the victim is herself; Teresa
addresses the maintenance stranger, never that hidden identity. Wet sills,
darkened landing and the one candle in 1D carry the aftermath without a flashback.
Start at the first legal recorded instant. No voice, silhouette or reverse shot
supplies the missing murder. Do not make death the setup for a joke.

There are two source locations, not one solved blocking plan. **tv_yard** is dated
03:02–03:40 and explicitly places Teresa kneeling in the rear yard. The anchor
carrier is in **1D**. Do not teleport her into the flat or play yard lines over
a room-bound actor. SOURCE **teresa_vale.json**, **tv_yard → tv_y1**:
“Adela. Get a blanket.” If that yard encounter is reachable under the attendance
owner, show her checking the available helper's attention before returning to
her task. Silence already goes to **tv_y2**:
“Not that. Off the line, that's wet. Inside. And tell Omar to stop looking at his breaker and come out here. Some six hours, in this. I'll tell him myself.”
Her instruction leads her look toward the interior, not a forced player-camera
turn. **m_teresa_named_her** remains that node's grant. No new blanket-fetch quest,
inventory reward or compulsory body inspection is introduced.

For a later, owner-supported return to 1D, optional PROPOSED **STAIRS-P01**, Teresa:
“Put it where it's dry.” She watches the existing lifted object reach a safe
rest, then looks away. Hands do not hold flask and watch simultaneously while
also writing. Do not stage the finished 03:05 note being written at 03:02.
The later **tv_note/tv_n2** exchange is unavailable before July 21, so it is not
reused here to manufacture a clue explanation.

**Agency / handoff.** Silence is help not yet given, not consent to take anything.
Walking away leaves Teresa's practical task intact; no reproach bark follows.
Interrupted entry preserves **mt:tv_yard** even if the blanket line never finishes.
Rerun cannot restore an already-heard topic by presentation fiat. Watch/flask
steps and actual taking own the note, independently of speech. Expiry cancels
owned gestures without extending the 38 minutes. The 03:05 carrier time versus
03:02 availability, later 03:10 dialogue wording and yard-to-room attendance need
an owner reconciliation before integration; this script adds no hidden time gate.

## BUTTON — a record made by someone who has work to do

**Source-derived contract.** **button**, “The mending basket,” 1929-07-20,
05:00–06:20 (80 minutes), tier 3; prerequisite **nurse_note**. Steps:
**in_2b** (at 2B), **lift_2b_finished_parcel** (shift **2B_finished_parcel**,
[0,1,0], 0.20), **lift_2b_tape_measure** (shift **2B_tape_measure**,
[0,1,0], 0.12), **lift_2b_story_notions** (shift **2B_story_notions**,
[0,1,0], 0.18). Clue **button_leaf**, rest **2B_story_notions**,
“A leaf from Lena's button book”:
“20 JULY. ONE PEARL. 6C, FOR A GLOVE. WRITTEN THAT MORNING.”

**Intention / PROPOSED staging.** Lena makes space for people by making practical
demands on them. Her record is ordinary work, not something she surrenders only
after a grief performance. First grey light, indoor washing and blown-in grit
establish morning after the storm. Keep her doorway passable. She finishes the
current small movement before looking up; a waiting hand, not perpetual sewing,
shows attention. Do not assign a real needle to an unqualified grip animation.
The player handles the existing parcel/tape/notions in the listed sequence;
Lena's body and offered help never obscure the carrier.

Optional PROPOSED **BUTTON-P01**, Lena, when the player pauses with a moved item:
“There's room beside it. You needn't balance the whole morning.” Her glance goes
to the resting place, then the person's hands. It is an offer to finish the
movement, without a new prop slot, consequence or explanatory clue. With silence,
she waits through one breath and returns attention to her own work.

**SOURCE delivery**, **lena_ortiz.json**, **lo_book → lo_k1**:
“Every button that comes through that door, with who, since before you'd believe. People think it's thrift. It's so that when somebody tells me they never had a thing, I can tell them what colour.”
She looks directly at the player only on “what colour”; no knowing glance toward
6C and no assertion that she knows a murderer. Existing choice **“Anything on the twentieth of July?”**
leads to **lo_k2**: “Six in the morning, before I'd got my shoes on. You'd be surprised who can't wait.”
Its silence route reaches **lo_k3**:
“Six C. For a glove. I wrote it down that morning. One pearl, and she wanted it matched by nine, and I had one near enough. It's the book I use.”
Preserve **m_button_book** at that node and the **m_glove_scrap** requirement on
the explicit “Pearl?” choice. **nurse_note** does not replace that requirement.

**Agency / handoff.** The source **lo_k1s** already offers sheet-holding if the
player says nothing; do not turn it into a mandatory minigame. Leave/interruption
returns Lena to her work and keeps already-committed heard/node flags. Returning
does not unlock a fresh speech replay or demand a bereavement topic. The physical
leaf remains independently collectible under its owner, not awarded by a smile.
Expiry/rerun follows TemporalLoop and cannot extend past 06:20 for a speech.
Source **lo_k2** describes a 06:00 arrival inside a visit beginning 05:00: before
then it would be future testimony. Resolve eligibility with the current owner
before integration; neither silently move the date nor invent a runtime gate.

## Integration questions and evidence custody

These are source ambiguities, not decisions made by this draft:

- Tea starts 16:20; **mk_tea** starts 16:30. Preserve both. Nadia's attendance
  must be supported rather than cloned. **mk_t4** deed-clause wording stays
  under WR-03. The anchor/choice says “bleed” a cold radiator; Bible VIII.5.c
  specifies one-pipe steam. No hydronic bleed procedure or false summer heat
  is staged here. The repair owner must reconcile terminology.
- Friday's **order_slip** wall prerequisite, **m_envelope_delivered** dialogue
  prerequisite, **m_route_book** grant and **route_leaf** are different facts.
- Stairs: the 03:05 note, later **tv_n2** “Three-ten by my watch,” earliest
  03:02 carrier readiness and Teresa's yard/1D placement need reconciliation.
  No body discovery or carried note can be fabricated to bridge them.
- Button's 06:00 testimony cannot be delivered retrospectively at 05:00.
  The current physical steps do not themselves establish the speaker's time
  eligibility. Preserve the original behavior in the audit; make an explicit
  reviewed integration change, not an invisible writing fix.

Codex integrates after Fable's qualified body/wardrobe and actual attendance
contract. Text review precedes voice selection; native proof must then exercise
normal entry, silence, leave, interrupted root entry, reload, expiry and rerun.
Verify no doubled grants, new prerequisites, future recognition or blackout entry.
Faces, palms, listener reactions and object clearance require actual interactive
review, not private film telemetry. This draft's state is **drafted only**;
text-reviewed, voiced, integrated, technically verified, played and artistically
accepted remain distinct and unclaimed.
