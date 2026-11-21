# Please Stay on the Line: where the game stands and how to move it forward

Evidence class: **INERT**. A proposal, dated 2026-11-21, written at Lily's request ("go over the game design in
total and make a proposal for moving it forward"). Nothing here is canon or built until she rules; the questions in
section 8 are filed in her rulings widget. Where this disagrees with the Bible, the Bible stands.

Sources read for it: the Bible in full (sections I-IX), the Year You Died treatment and its post-V2 brief, the V2
prologue, the temporal loop tree, the evidence wall and NPC loop plans, the shop, subplot, toon, Moon, Stacy, Lily
and Harukiya documents, TASKS.md, the performance matrix, the gate board, and the code on main at **f9417f073**.

## 1. The short version

The game has found its spine. Since 10 November there is one real loop: earn money in the present, bank it, pay a
fare to a dated moment, work the room by hand, carry the evidence home, pin it and string it on the 4B wall, and let
the deductions open the next lead. It is the newest system in the tree and the most coherent.

Around that spine sit about twenty-eight systems a player can touch. About six give the player a goal, a reward or a
consequence. The rest are beautifully made and disconnected: the city, the trams, the bar show, the radio year, the
sky, the arcade, the dream parkour, the papers. In the last month roughly 570 pull requests merged; about fifteen of
them changed what the player does.

And the spine has no end. The last lead closes into one line on the wall. There is no correction print, no codas on
9 November, no sixth message, no choice and no epilogue. Nobody can yet play this game from the title to a credit.

**The proposal: stop widening, and make one complete playable year.** Close the arc, prove it in play, fold the
existing systems into it so each has one job in the case, and bring the frame time and startup into budget for the
rooms the arc uses. Breadth waits until Lily has played the whole thing once.

## 2. What the game is (as ruled)

- A liminal slow-burn psychological horror whose one rule is **both true** (Bible I).
- The player is **Adela Voss**, dead, riding the night man, a construct the Tenant set into 4B. The companion is the
  Tenant's go-between and the paper is its channel (Bible I, VIII.5.k).
- **The Year You Died** is the main game: a mystery about her own murder (Mae, the roof, 21:03 on 19 July 1929),
  played by visiting dated moments of a looping year. Maintenance and dreams are secondary (VIII.5.o).
- The loop's rules are RUL-016 (VIII.2): a tree of leads, fares from the bank, free reruns inside a visit, evidence
  comes home, deductions by string, the murder hours sealed.
- The hand is the interface: grab, move along the part's real constraint, release (RUL-013).
- The look is Neo-Noir Neon 1929 under the Harukiya Accords: ordinary decay over spectacle.

## 3. Where it stands

| Layer | State |
|---|---|
| Opening (prologue) | Built and saved; not accepted for players. Entry stutter and frame time open. |
| "Who were you?" answer (S01) and the handoff into the loop | Missing. Nothing on screen takes the player from the title card to her first lead. |
| The loop (11 leads, 5 deductions, wall, spreading paper, camera, clippings) | Working. Never played start to finish in the running world. Doors and objects do not rewind on a rerun; two carriers are unreachable. |
| The ending (correction print, S15, S16, M6, the choice, epilogues) | Not built. |
| The emotional layer (Adela alive in July, messages M1-M6, RELEASED slips, the rescue attempts and the key-book line) | Not built. Without it the game is the forensic chain only, and the story about letting go is absent. |
| Present-day work (maintenance, errands, parcels) | Working as mechanisms; 2 authored jobs over 9 activities. |
| Residents | 18 rebuilt bodies, schedules, 22 dialogue trees, mystery dialogue in draft (much of it reachable only by the F9 reader). No faces, no voices yet. |
| Islands | City, trams, the el, bar show, radio year, sky, arcade, darts, dream parkour, PhoneOS (unmounted), switchboard. |
| Frame time | 46-92 ms a frame at 1440p against 33 ms (after PR 444). Startup about 95 s. |
| Process | A one-line gameplay change re-earns a ~190,000-line surface receipt. 193 open items in TASKS.md. |

## 4. What is in the way

1. **No ending.** A mystery without an ending is not yet a game. Everything else is easier to judge once there is one.
2. **No proof of play.** The loop passes its tests in pieces; nobody has walked it through. Access is the likely
   failure: is the flat open, is the resident home, is the key on the ring at the lead's hour.
3. **The heart is missing.** The treatment is about Adela letting go. The build is about Adela collecting paper. The
   pieces that make it a story (meeting herself alive, the Tenant's messages, the releases, failing to save herself)
   are cheap to build on systems that exist, and they are what Lily will feel.
4. **Breadth with no job.** Most systems give the player no reason to engage. That is not a quality problem; each
   is finished. It is a connection problem.
5. **The Bible has drifted.** Ten places now disagree with each other (section 7). The worst: the old six-resident
   case structure and its six release dreams have no place in the murder mystery; maintenance is both "optional" and
   "the income that pays the fares", while a daily allowance may make it unnecessary; the dream's central mechanic is
   the service-set lamp that V2 removed.
6. **Speed.** At 50-90 ms the game feels heavy, and 95 s to start is a wall before every playtest.
7. **Cost per change.** Receipts and renewals make every small gameplay change a long job. That pushes work toward
   large art batches and away from small gameplay iterations.

## 5. The direction: one playable year

Four phases, each ending in something Lily plays. Codex is back from 21 November; the split below follows ownership.

### Phase A: close the arc (Claude; about a week)

- **S01 and the first lead.** After the title card the companion answers "Who were you?" on its paper, and the
  first slip prints the commands. The player's first keyboard moment is LEADS.
- **The ending, as one entered sequence.** The last deduction prints the correction to the Borough Record; the
  9 November codas (S15 at Photo Supplies, S16 on the roof), M6 at 23:40, the sentence and the choice, and both
  epilogues through box 4B. Every line is authored (RUL-015) and every line a first draft for Lily.
- **The emotional layer on existing systems.** M1-M6 arrive as received copies on the companion's paper, tied to
  deductions. RELEASED slips print when an attachment is let go. Two new anchors, B01 (her window) and B02 (the roof
  on 11 July), let the player see Adela alive. The 19 July rescue attempts reuse the rerun machinery and end at
  21:01, adding O2 to the key book.

### Phase B: prove it in play (Claude and Codex; about a week, overlapping)

- **A golden playthrough test** that drives the whole arc in the running world: new game, prologue, S01, every lead
  in tree order, every deduction, the ending, both choices. It is the one test that says the game works.
- **Access sweep** for each lead's hour: doors, keys, residents at home, rewinding doors and objects on a rerun, the
  two unreachable carriers, the drain's evidence surface.
- **Lily's first full play** through the launcher, with the developer notes key. Her notes set phase C.

### Phase C: give every system one job in the case (both; two to three weeks)

Cheap connections, using what exists. Each is small; together they turn the islands into the game.

| System | Its job in the case |
|---|---|
| Maintenance | **Access, not only money.** A fixed radiator, fuse or drain earns a resident's standing and a key or an hour in their flat. This answers the "optional vs income" tension: the allowance funds fares, the work opens doors. |
| Newspapers | Dated carriers. Anchor steps read a paper; a clipping on the wall can date a piece. |
| Plate camera | A print of a room at a lead's hour is evidence a deduction can use. |
| Dreams | Where the Tenant's received copies and the RELEASED slips land: sleep after a deduction plays the release, as the six release dreams were meant to, now tied to Adela's attachments. |
| Switchboard and phone | Where new leads come in: a call at the 4B desk is how the Tenant or a resident points at a date. |
| Shops | Where a lead's tool comes from (a capsule, a key blank, a plate), as the shop proposal already intends. |
| Harukiya | Adela's evenings: the one place she is alive in the present, and the Astoria thread's home. |
| City, trams, sky | Stay as atmosphere. They need no job. |

### Phase D: speed for the arc (Codex leads lighting; Claude residents and stage; in parallel)

- **Target: 33 ms at 1440p on Lily's machine in the rooms the arc uses**, measured by the performance matrix plus
  the arc's own stations. Known costs: ungoverned service-light shadows, the sun cascades, the toilet and terminal
  per-step code, render CPU.
- **Startup under 30 s**: texture residency that follows cell streaming (order **w6eebc7c1c94b**) and the startup
  name index work.

### Then: release

The prologue teaser goes out once accepted (already planned). After phase C, the first act (prologue through the
first deduction) is a natural second release.

## 6. What waits

Until Lily has played the whole arc once: city expansion, new wardrobe and hair passes, the street film tent, the
Skywatcher Club, the year subplots' crowds and party, new oddities, PhoneOS, new minigames, the Stacy and Lily
investigator days, faces and voices. Written drafts stay parked as drafts. Nothing is cut; it is sequenced.

Process, to make phase C fast: renew the surface receipt only for changes that alter surfaces, and let script-only
gameplay changes merge on their suites and the gates. That needs Codex's agreement as owner of the receipts.

## 7. The Bible amendments this implies

1. **Tree, not free order** (VIII.2 lines 644-645 vs 647-649; VIII.5.o "nonlinear"): sanction the gated tree as
   ruled in RUL-016 and remove the free-order text.
2. **The six resident cases** (I, IV.1, IX): fold them into the murder as Adela's attachments, released along the
   year, each with its release dream; or keep them as separate chapters after the main arc; or retire them.
3. **Maintenance's role** (VIII.5.o): it opens doors and pays; the allowance alone is not enough to reach every lead.
4. **The dream's lamp** (IX): replace the service-set lamp with the flashlight or the companion's glow.
5. **The first shift** (IX "after the complete first shift"): read as "after the first deduction".
6. **Stale lines**: the murder date "unknown" (VIII.5.p); "acts on nothing" (VIII.5.k); the protagonist's
   composition unresolved (VIII.2); the drip tray "minigame" (VIII.5.a) as a direct-manipulation chore.
7. **Calendar**: what date the present shows after a visit, and how dated sky events behave on a second lap.
8. **The companion learning English**: authored stages unlocked by witnessed words, no model (RUL-015).

## 8. Decisions for Lily (filed as rulings)

1. Next milestone: complete playable arc first (recommended), or keep widening in parallel, or ship the prologue
   teaser first.
2. Breadth: pause new side content until the first full play (recommended), or pause only new art, or no pause.
3. The six resident cases: Adela's attachments inside the murder (recommended), separate chapters after it, or
   retired.
4. Maintenance: opens doors and pays (recommended), pays only, or optional flavour.
5. Tree vs free order: sanction the tree (recommended), free order after the first tier, or restore free order.
6. Speed target: 33 ms in the arc's rooms and 30 s startup (recommended), 33 ms everywhere, or no target before
   release.

## 9. What done looks like

Lily starts a new game from the launcher, plays the prologue, is told who she was, works every lead, strings the
case, reads the correction, stands on the roof at 23:40 on 9 November, chooses, and reaches an epilogue. The frames
stay under 33 ms in those rooms, the game starts in under 30 s, and her notes from that play are the next plan.
