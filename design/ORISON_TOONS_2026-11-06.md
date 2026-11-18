# Toons: the Fremont photograph, Slumberland and the mixed-cast picture

Evidence class: **INERT**. Working brief, 2026-11-06. Lily's three rulings are canon and live in the Bible at
**§VIII.5.q**. Everything else here is either built as marked or a proposal awaiting her read.

## The rulings, in one paragraph

Toons are real performers. A toon and a camera crew register on the same negative, and the camera records what a toon
does. Live-action pictures with toon stars are a celebrated art form, and still a splurge: sound is cheap and pictures
are dear (§VIII.4). The *1929 Fremont Street Cartoon Ensemble* photograph is real in the world. Little Nemo's Slumberland
is Toon Town, which is kept apart from the Orison Dream, the hum and Adela's case.

**Left open:** Slumberland's geography and entry rules, toon biology, and who the unconfirmed faces in the photograph
are.

## What is built

**One optional discovery at News & Cigars.** It needs no new system. The *Borough Record* for **Friday 24 May 1929**
gains a back page, sold from the stand like every other issue and read in the existing newspaper panel. It carries:

- **The film notice** (notices column). The Ditmars Photoplay shows *Mind the Teacup*, two reels from the Fremont Street
  company, from Saturday. It is a mixed-cast picture: **Mr. Bramble**, a toon, is billed above **Miss Ruth Calder**.
  The notice gives the running time (21 minutes), an added 10 a.m. matinee because the 2 p.m. sold out, the prices
  (35 cents, against the paper's 2) and "The house is cooled", since the week's heat is already in the paper. The
  notice treats the mixed cast as routine and never explains it.
- **The company portrait** (a back-page feature, halftone). Its caption: *"FREMONT STREET, 1929. Company photograph.
  The camera crew asked the tall one to step back."*
- Three ordinary columns around them (a park keeper, the Borough League, a classified), so the notice sits in a real
  back page rather than standing alone.

**The picture.** The supplied image is the private canon reference, kept outside the repo at
`C:/ov/reports/toons_20261106/fremont_street_1929_canon_reference.webp`. It shows recognisable characters, so it has not
been cleared for a distributable build, and RUL-007 keeps reference photographs out of the repo in any case. The
paper therefore prints an **original still** of the same scene, made locally (`ft_fremont_company.webp`). It is a
composite: a generated crew-and-cast plate on a western studio street, with two original ink toons cut in, a very tall
giraffe at the end of the row and a hippo in a bowler waving at the other end. The giraffe explains the caption.
SDXL couldn't draw toons into the photograph itself; asked to, it gave real giraffes. The composite's source and
`comp.py` stay outside the repo in `C:/ov/reports/toons_20261106/comp`, and its cut is recorded in
`art/data/newspaper_picture_book.json` like every other picture. Swapping in the canon photograph later means
replacing one `.webp` after clearance.

**Why 24 May.** The Academy dinner leads the Record on 16 and 17 May, and Grail's 25 May editorial is about the
borough's own studio at Astoria. So the notice arrives in a week when the papers are already talking about pictures.
That issue had no back page, no picture and no flag. The paper's normal gate keeps it out of circulation until 06:00
that day, and the rack sells it for four days.

**What it must not do.** Reading it sets no mystery, case or progression flag. Collecting the issue only adds
`record:1929-05-24` to the kept papers, as for any other issue. Nothing reads the film or the toons.

## The proposal, edited to fit the world (not built)

These are the parts of the owner's proposal that go beyond the first discovery. Each is placed where the world can
take it. None is built.

1. **The papers disagree about something specific.** The Record has printed the facts: the running time, the billing
   and the extra matinee. **Proposed:** Grail's Saturday editorial for **1 June 1929** gives Mr. Bramble top billing
   in its headline and spends the column complaining that the studio did the same. His 25 May editorial (the Astoria
   supper, and actresses paid half the actors' wage) stays as written; 1 June follows it. Saturday editorials already
   exist for every week, so this rewrites one, and it needs Lily's read.
2. **The industry made tangible through Adela's offer.** Ravenswood Sound Shorts of Astoria
   (**design/V2_ADELA_SOUND_PICTURE_PLOT_2026-11-01.md**) already keeps the negative under clause six. **Proposed:** one
   line of contract language, set against mixed-cast billing, asking who gets their name on the bill, who approves the
   publicity still and who keeps the negative. Adela already cares about all three. The test stays unmade and the
   offer unresolved. It would go in the contract text that reads from 25 March, needs Lily's read, and must not add a
   flag or a living thread past 13 July.
3. **LILITH.** Lily can borrow the timing of a mixed-cast short for a chibi gag. Her chibi drawings stay part of how she
   tells the story; the confession, the proof correction and the knot work as written. The comic is private and out of
   this repo, so this is a note for the comic, not a task here.
4. **Sound before pictures.** The public can know a toon star from an engraving, a radio interview or a review without
   having seen a picture. **Proposed:** a *Loud Speaker* interview with Mr. Bramble, or a radio spot on the house
   broadcast. Neither is built.

## Lily's daily strips at the Harukiya, a penny each (designed, waiting on two PRs)

Owner request, 2026-11-06: **Lily's daily three-panel strips are sold at the bar for a penny.** Each real day's strip
runs as the same date in the 1929 year (`C:/ov/reports/lilith_comic/library/LIBRARY.md`, "Daily strips"). In the game,
a strip goes on sale at the Harukiya from its in-world date.

**Why it isn't built yet.** Its parts are in two open pull requests:

- **The Harukiya counter** (PR 155, `claude/stacy-bartender`). On main the bar has a price list but no sale point.
- **The comic catalog, pocket and reader** (PR 164, `claude/valise-papers`). It is under admission review, and its
  open blockers are the comic sale itself: a refused payment currently still files the issue.

Building on both before they merge would edit files under review.

**The design, for after both merge:**

- **On the counter.** A short stack of the latest strips sits by Stacy's glass. The player draws one off by hand, as
  `clue_draw_prop.gd` does (RUL-013), not from a menu. The stack holds only strips whose date has come, and the bar
  sells only while it is open, 19:00 to 02:00.
- **The sale.** A `lily_strip` item at 1 cent in `harukiya.json`, settled through `ShopSales`. A refused payment
  leaves money, stock and the pocket unchanged, which is the rule Codex is enforcing in PR 164. A strip already kept
  is refused before any charge.
- **The keeping.** Strips join PR 164's comics pocket under their own series, with their in-world date as the on-sale
  date, and are re-read from the case.
- **The reading.** A strip is a picture, so the pocket's text reader needs an image view: one strip across the sheet,
  with the balloons already lettered into the art.
- **The art.** Each strip's PNG ships in the repo. Until now the strips have been private like the rest of the comic,
  so Lily's request is what moves them into the public build. Only finished strips go in; the LoRAs, prompts and
  renders stay outside.
- **Test.** Copy the shape of `HarukiyaCounterRouteTest` and the route that PR 164 still owes:
  - draw a strip on its date and none the day before;
  - check a refusal when cash is short, the exact one-cent debit and the duplicate refusal;
  - re-read the strip from the case;
  - restore from disk;
  - confirm no flag changes.

The first strip is **RADIO** (Wednesday 6 November 1929).

## What it does not touch

Slumberland gets no map, no door and no visit. The Dream (§IX), the hum (§III), WORS 1610, the Tenant and the case are
untouched. No resident gains an opinion about toons yet; that waits until Lily has read the first draft.
