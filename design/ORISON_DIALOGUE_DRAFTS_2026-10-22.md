# Dialogue drafts for every resident — the mystery web and its rules

Evidence class: **INERT**. Design drafts in data shape. Nothing here is wired
to the runtime, promotes a requirement, or changes a case's status.

*Written 2026-10-22 at the owner's direction, after the editorial pass
(`design/ORISON_EDITORIAL_PASS_2026-10-22.md`): "dialogue trees for everyone
drafted and gamified; reward empathy, intuition and inferring things from
context; a myriad of interconnected mysteries for anyone paying attention."*

The seventeen trees live in `game/data/dialogue/*.json`, in the schema of
`game/data/case01_dialogue.json` plus four draft fields (section 3). They
were drafted under `design/` and moved into the game the same evening, when
`game/scripts/game/resident_conversations.gd` began reading them: every
neighbour's entry door now carries a knock, and whoever the timetable says
is home answers through the redesigned `CaseDialoguePanel`. Mina's canon
tree is not redrafted; her knot references are listed in section 5 for the
case owner.

---

## 1. What a tree is for

Bible §IV.1 still governs: six residents carry cases, two are sanctioned
expansion, and the other ten are tenants without a chapter. These drafts
do not promote anyone. The six case trees are built on their case records
(work order, manifestation, resolution flags, portal rule). The eleven
others are **threshold conversations**: a resident met at their door, on
the landing, at the bar, who will say more each time the player has
noticed more. They have no resolution flags and close no case. What they
have is the other half of every mystery.

The owner's three rewards, as the trees implement them:

- **Empathy** is not agreement. The obviously compassionate line costs
  trust (Bible law 6; the Mina precedent `comfort_offered -1`). Empathy that
  pays is accuracy about the other person: naming the evasion without
  attacking it, letting a silence stand, declining to fix.
- **Intuition** is reading the room. Choices marked `evidence` cite a
  physical fact in the flat the player can see (the hero object and the
  contradiction in `apartment_life_profiles.json`, the schedule's tells).
  They are available only in that room, and they land because the resident
  did not say the thing; the player saw it.
- **Inference** is carrying one apartment into another. Choices marked
  `requires` appear only when the player holds a flag earned in a different
  tree. They are the web made playable: Peter's wallet stubs mean nothing
  until Mina has said "four seconds"; Cal's high shelf means nothing until
  Peter has said "the gap". An inference can be wrong (`infer: true` with a
  trust cost): a player who guesses gets corrected in the resident's voice.

## 2. The knots (what is connected to what)

From `design/ORISON_RELATIONSHIP_WEB.md`, every thread tentative, plus
four building threads already seeded in data. A knot is traversable when
a flag earned on one side unlocks a choice on the other.

| Knot | Residents | Flags that cross | What the player can come to hold |
|---|---|---|---|
| The Conviction | Mina, Peter, Teresa, Cal, Noel, Jonah; Leon on the desk line | `price_named`, `peter_gap_found`, `cal_reel_named`, `teresa_alarm_not_hers`, `noel_father_tried`, `jonah_verdict_unwritten`, `mina_four_seconds` (canon tree) | that seven people in one building touched one trial and none of them knows the others did. Nobody ever hears the four seconds. |
| The Estate and the Architect | Mae, Nadia; the player's letter | `estate_is_kessler`, `nadia_signed_silence`, `mae_ledger_unopened` | the player works for one side of a war between floors five and six |
| The Bells | Omar, Iris | `bells_married`, `omar_notes_to_himself`, `iris_anniversary_note` | two flats, one marriage, maintained like a boiler |
| The Vales | Teresa, Mina | `vales_hours_do_not_overlap`, `teresa_daughter_notes` | a child who wrote everything down for a mother on the opposite shift |
| The Ortiz thread | Lena, Cam | `lena_locked_doors`, `cam_strap_restitched` | why stillness frightens the courier |
| The Red Pencil | Evelyn, Peter | `see_me_note`, `evelyn_register_name` | the teacher and the homework, still ungraded |
| Take 18 | Rhea, Juno | `rhea_take_eighteen`, `juno_archive_open` | the deleted take that survived one floor down |
| The Cutting | Malcolm, Sacha | `malcolm_auggie`, `sacha_photo_date` | the proof a family never had is a plant on floor three |
| The first tenants | the Guests, everyone | `guests_remember` | the pair who have always been checking in remember every arrival and will not say so twice |
| **Building threads (seeded in data)** | | | |
| 3C, H. Vantry | Mae, Omar, the dead letters | `vantry_in_3c` | a Vantry lived here until spring and left no address |
| 5D, Dorothy Ash | Jonah, Teresa, the minutes | `dorothy_card` | the association minutes stop in 1924; her birthday card still comes |
| WORS 1610 | Cal, Omar, Juno | `station_went_quiet` | the transmitter was never found because it walks |
| The sixteen years | anyone | none | a resident may wonder aloud. **Nobody answers.** No tree does. |

The desk cases are the other layer and are not redrafted: Leon Price is
caller "L. PRICE" (4482) and stays on the line.

## 3. The schema, and the three draft fields

Each file is a `case01_dialogue.json`-shaped tree: `meta`, `entries`,
`nodes`. Nodes carry `line`, optional `role`, `choices[]`, optional
`silence_goto`, `silence_flag`, `silence_trust`, `action`. Choices carry
`label`, optional `goto`, `flag`, `trust`. The structural auditor
(`tools/audit_authored_voice.py`) passes every file.

Three fields extend the runtime contract and are honoured by
`CaseDialoguePanel` through the `available` callable that
`ResidentConversations` supplies:

- `"requires": ["flag", ...]` on a choice: shown only if every flag is held.
  Flags are campaign-wide, in `RealityState.data.knowledge_flags`; a case
  resident whose case is enabled and in play also has the flag recorded on
  the case through `RealityCases.record_conversation`.
- `"evidence": "hero object or contradiction"` on a choice: shown only
  while the player stands inside the resident's own flat (the V2 root
  answers which unit the player is in by its room grammar).
- `"infer": true` on a choice: the player is asserting something the
  resident did not say. Right inferences carry `trust +1`; plausible wrong
  ones carry `trust -1` and a correction node.

A fourth draft field, `"flag"` on a **node**, means "granted on reaching
this node" (the canon schema grants flags only on choices and on silence).
It is used where the resident volunteers the fact, so that every route into
the node earns it.

Trust is the same bookkeeping as Mina's: it opens later entries and
changes which `entries` key the director picks. No tree has a hidden
morality score. Silence is a first-class choice on most nodes; what it
means is decided by the resident's wound, not by the player's intent.

**Counts at this draft:** 17 trees, 481 nodes (every one reachable), about
19,200 spoken words, 24 evidence choices, 97 inference choices, 162 flags
granted, 39 flags required. Every required flag is granted by a tree
except the six **world flags** below, which the building grants when the
player reads or operates something:

| World flag | Granted by | Required in |
|---|---|---|
| `mina_four_seconds` | Mina's canon tree reaching `rt_blank` or `res_open` (`MinaCaseGameplay.NODE_KNOWLEDGE`; the tree itself is unedited) | Peter, Cal |
| `minutes_read` | the association minutes spread opened past 0.6 rad in the readable library (`v2_readable_book.gd`, `SPREAD_KNOWLEDGE`) | Noel, Jonah |
| `otis_sixth_deaf` | the car refusing the first call to the sixth (`otis.gd`, the `deaf` quirk) | the Guests |
| `station_went_quiet` | Omar's blackout node `ob_blackout`, which carries `flags: ["station_went_quiet"]` beside its own flag; or the WORS 1610 programme card posted to box 4B after two conversations (`mail_catalog.json`, `knowledge`). The laundry room has no station legend in V2; when one is authored it should grant the same flag | Cal |
| `vales_hours_do_not_overlap` | witnessing either Vale on the hour they miss each other: Teresa's 22:20 lobby transit or Mina's 23:30 late run. The schedule block carries `knowledge`; `ScheduleDirector` passes it in the directive and `ResidentRoutines` grants it within 4 m of the resident | Teresa |
| `vantry_in_3c` | the misdelivered final demand for H. Vantry, 3C, posted to box 4B after one conversation (`mail_catalog.json`, `knowledge`); or, in V1, filing the Vantry letter in the dead-letter tray (`dead_letters.json` `gone[].knowledge`). The V2 mail bank's empty 3C slot itself has no control yet | Mae, Omar |

A mail delivery may carry `knowledge` (granted when taken) and a `when`
condition `min_conversations`, the player's knocks-and-talks counted across
every resident, so the post arrives once the building has started talking.

A node may grant more than one flag on arrival: `flag` (one name) and
`flags` (a list) are both honoured by the panel and validated at load.
`WorldFlagTest` drives all six grants headless and checks that the replies
requiring them become offerable through the director's own `requires` check.

## 4. Period and knowledge rules kept

- 10 November 1928, Queens. Residents speak as 1928 people; the Rule of
  Signal licenses recording and telephony; nobody says "email".
- Both true. No resident explains the building, the hum, the colour
  cabinets or the sixteen years. A resident may wonder; the tree moves on.
- Knowledge limits. The Price knot residents do not know one another's
  part. A `requires` choice lets the *player* know; the resident reacts to
  being read, never to being told the whole picture. Nobody plays the reel.
- The Tenant never speaks here. These are people.
- Anachronistic memory (Cal's thirty-seven years, Evelyn's register,
  Omar's blackout) stays as ruled: spoken rarely, never dated aloud.

## 5. Mina's canon tree: knot hooks for the case owner

Her lines are not edited. Two of the three hooks are now in her tree as
`requires` replies, so they exist only for a player who learnt the thing
elsewhere: `rt_court_door` offers "Someone else in this building found a gap
in a record. Yours isn't the only one." (`requires: ["peter_gap_found"]`,
trust 1, bookkeeping flag `heard_of_another_gap`); `rt_blank` offers "The
record is not the only copy." (`requires: ["cal_reel_named"]`, trust -1,
bookkeeping flag `named_the_other_copy`), because it is the cruellest true
thing. `MinaCaseGameplay.choice_available` honours `requires` against the
knowledge store. The third hook needs no edit: reaching `rt_blank` or
`res_open` grants `mina_four_seconds` (`NODE_KNOWLEDGE`).

## 6. The seventeen trees, one line each

| File | Resident | Entry pressure | The thing they will not say | What noticing earns |
|---|---|---|---|---|
| `peter_wren.json` | 4A, case | the forms are breeding; the player is asked to countersign | he found the gap and let the deadline pass | the appeal, the stubs, a note in red ink |
| `juno_kells.json` | 2C, case | feedback has gone solid; she wants a channel left open | the archive has someone else's take in it | her theft and the theft of her, in that order |
| `cal_dwyer.json` | 5B, case | the set receives expired moments; he wants it perfect | the high shelf; the reel he dusts and never plays | what the station was, and who carried it |
| `omar_bell.json` | 3B, case | every repair returns another impossible fault | the notes are to himself; the marriage is a boiler | the one word he cannot write on a tag |
| `mae_kessler.json` | 6C, case | two provenances on one object, both signed by her | the ledger on the bottom shelf; the name on every lease | whose building this is |
| `rhea_sato.json` | 3D, expansion | a captive note in the booth; she performs the complaint | take eighteen was the honest one and she deleted it | a flaw chosen on purpose |
| `nadia_quell.json` | 5A, expansion | the plans are overwriting the flat | the certificate; the flat was the price | what Management is |
| `evelyn_marsh.json` | 1A | the papers grade themselves overnight | one name in the register is upstairs | good enough, said once |
| `teresa_vale.json` | 1D | the bell rings with the breaker out | the alarm that was not hers | one alarm left unanswered |
| `lena_ortiz.json` | 2B | the west wall is coming unstitched; the round is her job too | the doors, 1911; her own hem | being helped without earning it |
| `malcolm_reed.json` | 3A | the cuttings have started repeating a goodbye | Auggie; the one plant with no descendant | letting it finish |
| `cam_ortiz.json` | 4C | the flat tilts when he stops | why stopping feels like falling | staying past the handoff |
| `noel_price.json` | 4C | the family things are under glass | whose chair; what the trial was | one cup back in use |
| `transient_guests.json` | 4D | the hallway repeats 4D; checkout is always eleven | they have always been here; they remember everyone | a departure that is a decision |
| `iris_bell.json` | 5C | the paintings repaint the flat for an audience | the audience was one man, two floors down | work for no one |
| `sacha_reed.json` | 6A | rooms arrive seven seconds late on the camera | the family box; the photograph with a date on the back | experience before proof |
| `jonah_price.json` | 6B | sentences nest behind the baseboards | the verdict he cannot write in his own hand | an ending, badly, and let it end |

## 7. Proposed canon (not installed)

These drafts imply four small things the Bible and web do not yet say.
Each is written so a "no" removes one node, not a tree.

1. **The brass key on the third landing** (legacy lobby notice "FOUND") is
   the extra, familiar key in Mae's bowl. Mae's tree lets the player say so.
2. **The chair the Association keeps** (readable minutes, "until its owner
   can be found") is the chair Noel confirms by sight each morning. Noel's
   tree lets a player who has read the spread recognise it.
3. **The second hospital reminder** addressed to C. Ortiz (dead letters)
   is from Teresa's ward. Teresa's tree notices the name; Cam's refuses it.
4. **H. Vantry of 3C** was Mae's last appraisal before the spring. Mae
   says the name once and will not again.

## 8. What done looks like, and what is not done

Done: seventeen trees in the shared schema, auditor PASS on each, every
`requires` flag granted somewhere, every knot traversable in at least one
direction, no node explaining what the Bible keeps silent. Played: the
trees load through `ResidentConversations`, which validates every field at
startup; apartment entry doors carry a knock control; trust and visits
select the entry; knowledge flags, trust and visits persist on the campaign
document (save version unchanged, additive keys). The panel is a
lower-third scrim with the building's serif, numbered plain replies and no
button chrome; `ResidentConversationTest` drives it headless.

Not done, by design: no case is promoted and no door activates one; Mina's
lines are unedited (two `requires` replies were added to existing nodes and
her gameplay grants one world flag by node id). Still unwired in V2: the
laundry room's station legend (no such fitting exists yet) and the mail
bank's empty 3C slot; both flags now also arrive by post; the knock has no
answering animation or voice. Cases are still reviewed one at a time with
the owner before any of the five case trees is promoted to case gameplay.
