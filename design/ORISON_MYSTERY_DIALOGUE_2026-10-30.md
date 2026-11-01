Evidence class: **INERT**

# Mystery dialogue and the companion: writers' room draft

Written 2026-10-30 at the owner's direction: fold her comedy bank into the plot,
build interactions between the companion and the player for character, world and
jokes, and start dialogue trees around the mystery for everyone.

Everything here is **PROPOSED**. Nothing is wired into the game, no dialogue file
under `game/data` changes, and nothing has been run in Godot or read aloud.
The story stays `design/THE_YEAR_YOU_DIED_TREATMENT_2026-10-30.md`. Where this
note and the treatment disagree, the treatment wins.

## 1. What was made

| Piece | Where |
|---|---|
| Trees for 23 speakers: 70 threads, 220 nodes | `game/data/mystery/<speaker>.json` |
| Companion addendum: 53 lines, 5 branches, 4 movements | `game/data/mystery/companion_mystery.json` |
| The 17 things the world must hand the player | `game/data/mystery/carriers.json` |
| Printed copy with no speaker | `game/data/mystery/object_copy.json` |
| A readable version of every tree | `design/mystery_dialogue/READ_ALOUD.md` |
| The checker, and what it refuses | `tools/check_mystery_dialogue.py` |

This is a first pass, about 5,600 spoken words. The live door trees run about
19,000. It covers each person's hold on the case and one comic or human beat, so
the owner can judge the shape before more is written.

## 2. The idea the trees are built on

**She has to ask about herself as if she were someone else, and she cannot correct
anybody.** This is the engine that joins the bank's comedy to the plot. Adela is a
woman who has corrected the world in grease pencil for years. Now she stands in a
maintenance tenant's working day while the neighbours review her. Evelyn still has
a note about her sevens. Rhea tells her exactly what was wrong with her. The
Guests got her address wrong. She may only ask.

The bank's strongest move is the same one: a precise fact, an officious misnaming,
a sharp literal correction, and a late turn that makes the speaker complicit. Here
the correction is the thing she is not allowed to say aloud, so it goes to the one
correspondent who can take it.

**The companion is the only one who addresses her correctly.** That is what its
first exchange establishes ("It is enough to address you correctly"), and it is
why she keeps talking to a machine that tells bad jokes.

**How dates work.** A thread carries a date window, so before 19 July she is alive
and people talk about her in the present tense. Flags are what the player has come
to know. They open her questions and never the resident's knowledge: nobody learns
about a visit she did not tell them about. The checker refuses a living thread
that speaks from after her death.

## 3. The companion and Adela

Four movements, keyed to what has been witnessed and never to a timer.

| Movement | What it does | Running material |
|---|---|---|
| I. It has her name | She tests whether a correct form is all it can do. It reviews its own opening ("more enthusiasm than method") | Forms, the four expressions, the occupation form |
| II. Hold the lamp lower | Two trades correct each other. She teaches it to light a thing. It teaches her to keep an observation away from a conclusion | The lamp ladder, "We have the date. We have not looked there", the sky, the bar joke |
| III. The objection is filed | She reads the wrong account of herself. It opens the only department that will hear her: objections from the deceased | The objections file, her sevens, reviews she can't answer, the rescue exchanges |
| IV. Whoever reads this | They learn the paper has another reader. It starts leaving the margins wider. It stays | "RECEIVED. I DID NOT WITNESS THIS", who it works for, the last joke |

**The three long jokes.**

1. **The bar joke.** The live library has its opening and "I shall spare us the
   indignity". She edits it across the year, it gets worse, then it answers her
   with her own line ("It has got a floor in it"). The last version ends on the
   short leg of the stool, which it saw and does not understand. It is exhausted
   before the last evening, and it does not print after M6.
2. **The lamp.** Each adjustment shows it something it failed to report. The payoff
   is one unrequested act in her shop: it moves the lamp to the side, and says it
   isn't sure when it began knowing how.
3. **Objections from the deceased.** The file grows. It doesn't fix anything, and
   that is the point.

**Rules the addendum keeps.** It speaks in first person singular and sentence case
like the 150 live lines. Capitals are only for what it records or receives, so the
bank's "WE CANNOT ACCOUNT FOR THE KNOT" became "I cannot account for the knot".
Its words make nothing happen. It knows only what it witnessed, and a typed claim
is not a witnessed one. Nothing unsolicited prints during grief, a protected
conversation, a draft, a pause or the ending. After a release slip or a memorial
there is no joke until she types one first. Nothing prints after M6 except its one
ruled line.

## 4. The trees: who holds what

Each person holds one useful thing. Nobody takes a turn at "implicated".

| Speaker | Holds | Main threads | Flags earned |
|---|---|---|---|
| Adela, alive | Her own year | Window, Derby, sky, Rhea's picture, the two key loans, the O2 attempts | **m_met_adela**, **m_key_loan_19**, the five **m_o2_** flags |
| Emil Voss | Her address | What can come home | **m_address_fact** |
| Mr. Ewald | The letter on his file | Monday, the reversion, turning it over | **m_saw_kessler_note**, **m_letter_compared** |
| H. Vantry | The sighting at about 21:07 | Saturday, 3:40 | **m_vantry_saw** |
| Patrolman | The haste | The sheet | **m_patrol_sheet** |
| Mae Kessler | The evidence meets here | Tea, afterwards, the glove, the box | **m_motive_known**, **m_mae_answered** |
| Nadia Quell | She told Mae; she keeps the window | The stool, the tea, the log, the telling | **m_grey_coat**, **m_told_nadia** |
| Evelyn Marsh | Carried the box | The seven, the open slip | **m_box_carried**, **m_defended_seven** |
| Teresa Vale | Found her; wrote the note | The yard, the chart | **m_teresa_named_her**, **m_white_kid** |
| Mina Vale | The struck entry | HOLD with her canon | **m_mina_light** |
| Lena Ortiz | The bag; the button book | The bag, the book | **m_bag_ticket**, **m_button_book** |
| Juno Kells | Roof mic, wall tape | The mic, the reel, the trade log | **m_wall_tape**, **m_drama_lead** |
| Malcolm Reed | Last on the roof | Roses, that evening | **m_last_on_roof** |
| Omar Bell | Key, recorder, plate | Windmill, the bell, the breaker, the ash | **m_recorder_limit**, **m_panel_log**, **m_plate_salvaged** |
| Rhea Sato | A real privacy claim | The serial, the portrait | **m_rhea_claim** |
| Peter Wren | His firm's copy | Returned post, the copy, the receipt | **m_lease_read**, **m_peter_will_sign** |
| Cam Ortiz | The envelope; the 18:40 letter | The envelope, the route book | **m_route_book** |
| Noel Price | Named by a simile | The keepsake, the scrap | **m_glove_read** |
| The Guests | "Lodged"; the 22:50 sighting | The lodger, the stairs, rumours | **m_guests_sighting** |
| Cal Dwyer | Two tapes | Bad jokes travel, the bulkhead, playback | **m_someone_at_tank**, **m_drama_disc** |
| Iris Bell | The cadmium; the sketch | The roof, the canvas | **m_iris_sketch** |
| Sacha Reed | Rota, duplicate, plate 13 | Thursday, the sleeve, what survived | **m_lease_on_glass**, **m_plate13_half** |
| Jonah Price | Heard a line, wrote "white" | The page, the book | **m_jonah_page**, **m_jonah_heard** |
| Lily (added 2026-11-01) | Nothing in the case | The act, Astoria, afterwards (**design/V2_ADELA_SOUND_PICTURE_PLOT_2026-11-01.md**) | **m_two_bars** only |

**The route still isn't a ladder.** The checker works out every flag a player can
reach and fails if a requirement loop would strand a thread or the case. Ewald's
note can be got on 22 July or any day after, so missing that visit strands nothing.

## 5. What happened to her comedy bank

The bank has 45 proposed lines across 28 ideas. **32 are placed**, each once, with
its id on the node. The owner answered the review questionnaire on 2026-10-30: seven
held lines used as written, five reworked, four withheld lines put back on the table,
and public is fine. The four are placed as proposals with the bank's cautions on the
thread, and **JF012-A01** also needs a history check.

| Disposition | Lines |
|---|---|
| Placed in trees (13) | **JF001-A01**, **JF002-A01**, **JF003-A01**, **JF004-A01**, **JF005-A01**, **JF005-A02**, **JF007-A01**, **JF007-A02**, **JF014-A02**, **JF015-A01**, **JF018-A01**, **JF019-A01**, **JF022-A01** |
| Owner: use as written (7) | **JF008-A01**, **JF008-A02**, **JF009-A01**, **JF009-A02**, **JF010-A01**, **JF021-A01** in trees; **JF016-A01** as object copy |
| Owner: reworked (5) | **JF006-A02**, **JF021-A02** in trees; **JF006-A01**, **JF013-A01**, **JF013-A02** on the companion |
| Owner: back on the table (4) | **JF011-A01**, **JF012-A01**, **JF024-A01** in trees; **JF011-A02** as object copy |
| Placed on the companion (3) | **JF002-A02**, **JF015-A02**, **JF018-A02** |
| Next pass, needs its surface (4) | **JF001-A02** (a Derby entry), **JF003-A02**, **JF004-A02**, **JF017-A02** (back pages) |
| Next pass, fits a resident (2) | **JF017-A01** (Juno), **JF014-A01** (a note in Adela's contact sheet) |
| Spare alternates and duplicates (5) | **JF020-A01**, **JF023-A01**, **JF025-A01**, **JF026-A01**, **JF028-A01** |
| Not used: a pitch note, barred by the bank (1) | **JF027-A01** |
| Not used: breaks a ruling (1) | **JF010-A02**. It wants to be a received copy, and there are exactly six |

**Privacy.** The SQLite file and the source CSV hold private excerpts, and the
bundle's own README says not to share them. I queried the catalogue and adaptation
fields and never opened the excerpt text. Neither file is in this repository, and
neither is the bank itself. No line is presented as a quotation of the owner.
This repository is public, and the owner ruled on 2026-10-30 that the lines she
passed may be here, unattributed.

## 6. Rules the checker enforces

- Every target exists, every node is reachable, and every choice has authored
  silence.
- Every required flag has a grant. Carriers must each be used.
- Nothing may call the player "sir", "mister", "young man" or "maintenance man".
  The residents' ruled job title is "the night man". The construct pronoun question
  stays with the owner. No joke here is about her body or the body she rides.
- No resident says "the Tenant", "instrument" or "Signal Pro". The companion cannot
  name what it serves.
- A thread entirely before her death can't speak from after it.
- The barred bank line fails, and no bank line is used twice.

It cannot tell whether a line is funny, or right for Adela. Those stay with people.

## 7. What the engine would need

None of this is built. `ResidentConversations` already grafts dated opinions onto a
door, and these threads are the same idea with depth.

1. **A graft for threads.** Date window, `requires`, topic and a root node, added
   to the door the way `with_opinions` does it. Flags already persist through
   `RealityState`, so it needs no new save field. It also needs a literal path list
   for the reader gate.
2. **Hours.** Some threads have an `hours` window. The opinion graft is date-only.
3. **A speaker per node.** The panel's `present` takes a speaker name, but trees only
   have `speaker_default`. The tea, the stool and the box need a second voice.
4. **Companion gating.** Today's phrases and intents don't check flags. `requires`,
   `witness`, `exhaust` and `not_after` all need an owner, and a line must count as
   heard. Today's memory is not yet save-integrated, and the printed history is
   bounded at 48 entries (treatment A.5).
5. **Carriers.** The 17 entries in `carriers.json` are objects to author, including
   the fire escape and yard the case already owes (treatment 4.7).

## 8. Found while writing

- **Two other Vosses exist in live data:** the Elmhurst family with the answering
  doll (`game/data/opinions/evelyn_marsh.json`, `iris_bell.json`) and Mr. Harlan
  Voss, counsel to Queens Light & Power (`1929-06a`). I used the second as one small
  joke (**m_voss_harlan**). The doll family may want renaming.
- **Rhea's scene:** her after-the-fact thread opens on 22 July. S06 remains the page
  for 20 April.
- **New small facts**, all **PROPOSED**: Adela's cotton gloves, Omar's key hook,
  Malcolm's cutting in a tobacco tin on her sill, her overflow printing with Sacha,
  Iris's canvas in the window, and Mae's tell on the mend ("I have mended nothing").
  The tell is not evidence and the finding doesn't use it.

## 9. Gates and open calls

**Owner ruling, 2026-10-30.** There is no separate trans-reader gate. Lily is
trans and will read everything herself by playtesting the first draft. Her read
decides what stays. The factual checks stand: period property law, the history
check on **JF012-A01**, and the Mina hold.

**For Lily.**

1. Read the thread placements in `READ_ALOUD.md`.
2. Do the five reworks and the four placements land? The playtest will show.

**Ruled 2026-10-30.** The core idea stands. The last bar joke stays.

## First-draft wiring

The trees are game data, read by `ResidentConversations` and
`companion_conversation.gd`. Every line is still a draft for the owner's playtest.

- **At a door.** A resident's open threads appear as topics on their door tree,
  gated by date, hour, flags and hold, and each is heard once. Flags are knowledge
  only: they move no trust and reach no case.
- **On the set.** Typed lines answer their phrases under their own gates. Reading
  the Record of 21 July 1929 grants **m_c_n16** and prints **m_notice_1**.
- **Everything else, by the playtest panel.** Set `ORISON_MYSTERY_PLAYTEST=1` and
  press F9 in the V2 building. It sets the date and hour the threads read as, holds
  or drops any flag, talks to anyone on the real panel and prints any companion
  line on the real set. It writes no save and moves no clock.

Not built, so reachable only through the panel: the 17 carriers except N16, a way
to visit dates, doors for Adela, Emil, Mr. Ewald, Vantry and the patrolman, the
witnessed companion producers, and the silence rule on witnessed lines. Door hours
come from the resident schedules, so a thread's hours can fall when nobody answers.
