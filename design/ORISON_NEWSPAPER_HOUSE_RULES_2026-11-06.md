# Newspaper house rules: Codex's May 24-26 markup, generalized to the year

Evidence class: **INERT**. Working rules, 2026-11-06. Codex marked up a 13-page proof of the *Borough Record* and the
*Loud Speaker* for 24, 25 and 26 May 1929 as the game's panel sets them, with 36 notes. Lily asked for the notes to be
applied to the whole newspaper system, not only those three days. This document turns each note into a rule, says
where the rule is enforced, and records what the year-wide sweep changed.

The proof and the markup are outside the repo at `C:/ov/reports/paper_proof_20261106/`.

## Layout rules (enforced in the typesetter and panel, so every issue gets them)

- **L1 Reading path through a split lead.** Where a lead body is cut into two columns, a rule runs between the halves
  and the halves share a top line, so the second column reads as a continuation (P01, P05, P09).
- **L2 Weather at play size.** The weather desk labels today's observation, the forecast and any earlier dispatch in
  words, and nothing on it is set smaller than 13 points or in the pale ink. Earlier dispatches are marked as
  superseded (P01, P03).
- **L3 A back-page picture sits with its story.** The woodcut band goes above a back-page feature, never between the
  feature and the columns it illustrates (P02).
- **L4 The item outweighs the shop.** In the small tradesman's card the item and its price sit beside the cut and are
  set larger than the firm's name (P06).
- **L5 Balanced Speaker columns.** On a Speaker front without a picture, stories go into the shorter column, so
  neither side leaves a long empty field under its rule (P07).
- **L6 Sunday picture grid.** Pictures in one row of the Sunday Picture Section are set to a common height, so their
  captions share a baseline (P13).

## Editorial rules (applied by the sweep; E5 is also checked by `tools/audit_newspapers.py`)

- **E1 Chronology.** Every date and relative day ("Thursday", "yesterday", "last night") points to the right date for
  the issue it is printed in. A real event keeps its real date: the first Academy Awards dinner was **Thursday 16 May
  1929**. A picture never shows an event that has not happened yet on its issue date; if it shows a rehearsal, an
  earlier year or a drawing, its caption says so (P07, P12, P13).
- **E2 Lead sentences scan in one pass.** The first sentence of a lead gives who, what, when and where, and names the
  person the story is about. Attribution and evidence lists come in the next sentence. The last reveal stays last
  (P01, P04).
- **E3 Counts stay distinct.** A headline never makes a running total read as a period's count. A comparison names
  what it is compared with ("against 1,520 the week before"). Separate counts stay separate (P05).
- **E4 Insider terms are named once.** A term the reader may not know, such as an exchange position, is named plainly
  in the deck or first paragraph of the issue before a headline jokes on it (P03).
- **E5 An advertisement states its price once.** A price that is in the display line (headline or offer) is not
  repeated in the body. Useful details are stated once, and the copy ends on its best line (P02, P04, P10).
- **E6 A caption matches its picture.** A caption describing the instant shown agrees with what the picture shows
  (P13).
- **E7 Who said what is unambiguous.** Reported speech names its speaker (P11).
- **E8 One time anchor.** A running count ("since May 7", "the eighteenth night") uses the same anchor in every place
  it appears in an issue and agrees across issues (P09).
- **E9 Two voices.** The Record keeps dates, numbers and official language. The Speaker keeps local observation and the
  last-line joke; where a Speaker item repeats the Record's procedure, the procedural sentence goes and the joke stays
  (P11).
- **E10 A back-page picture names its story** when the story is on the same page (P02).

**Keep notes.** Codex marked eleven passages to keep. The sweep's standing instruction from them: trim a setup before
cutting a joke beat, keep fourth beats and last lines, and never explain a silence.

**Not adopted as a rule.** Recurring advertisers taking the same strongest slot (P06 note 1) and the size of the
answering-cabinet face (P08 note 2) concern the edition's ad plan. Varying them needs a ruling on how often a firm may
lead, so the sweep leaves the ad plan alone. Picture retouching (P02 midtones, P08 shadows) is art work and is listed
as owed.

## The three marked days

Codex's specific lines for 24, 25 and 26 May are applied as written or as close as the copy allows. Among them:
- the Bliss lead opens on the judge and the hour;
- Position 43 is named in the Speaker's deck;
- Tobias Lull is named first;
- the licence head separates the week (283) from the total (1,344);
- the Academy dinner is dated 16 May and the Astoria supper "Thursday last";
- both bugle calls are named;
- the court clerk's recording of "Correct" is attributed.

The Sunday cartoon is captioned as Thursday's parade as the artist expects it. The parlour cabinet's "So is hers" gets its own line.

Two stills are retouched in place:
- the Fremont company still has lifted midtones;
- the middle frame of the 25 May drama, "Grandpa's Record", has lifted shadows and a tighter crop.

A rebuild of the picture cuts from source would undo both retouches, so the source cuts are owed the same treatment.

## The sweep

Six readers went through the year: five took the issues in slices, and one took the pictures, cartoons and advertisements.
They proposed 227 edits with the exact old text. Every edit was read before it was applied, and all 227 applied
cleanly. By rule:

| Rule | Edits | Rule | Edits |
|---|---|---|---|
| E1 chronology | 79 | E4 terms named | 8 |
| E8 one anchor | 65 | E7 who said it | 8 |
| E3 counts distinct | 34 | E9 two voices | 2 |
| E2 lead sentences | 20 | E6 caption to picture | 1 |
| E5 price once | 10 | | |

The largest groups:

- **Running counts that disagreed across issues.** Among them:
  - Record No. 23's three votes: 19-18, 19-19 and 14-14;
  - Party Line's five tins;
  - WORS 1610's silent nights;
  - Kehoe's second places;
  - the night-call weeks that were called the highest while March's 4,870 stood;
  - Byrd's days out of Norfolk.
- **Pictures that showed an event before it happened.** Among them:
  - the 26 May Grand Army ride and cornets, now Decoration Day 1928;
  - the 4 August Zeppelin section, now her October 1928 crossing;
  - the Record fronts of 4 March, 30 May and 29 August;
  - the 9 October Series picture, moved to Wrigley Field.
- **Relative days that pointed at the wrong day.** These fall mostly in Speaker editorials and wires.

After the sweep, nine new front headlines ran over the front's 80-character limit. They were shortened by hand. The
newspaper audit passes, and the reader gate reports no new unread fields.

## Open items: found, not fixed

Each needs a story decision or a fact the papers do not settle.

- **24 October 1929 Record** is a morning paper. It reports the same day's noon events of Black Thursday as "this
  morning". The Record never prints Wednesday 23 October's twenty-point fall.
- **5 June 1929 Record** has Ramsay MacDonald accepting the King's commission "yesterday". He kissed hands on 5 June,
  so the story belongs in the 6 June paper.
- **Zeppelin times, August 1929.** New York kept daylight time in summer 1929, so the Friedrichshafen conversions are
  an hour off. Moving them shifts the window-playback times. The papers' own times give about 51 hours from Lakehurst to
  Friedrichshafen, not 55.
- **Mr. Crane's inspectors** number eight in July and 62 from 8 August, with no hiring reported.
- **Nell and Duchess.** From 25 August, two ice-wagon mares and two ice companies are merged into one.
- **Byrd's route** to Dunedin, given as the South Atlantic, cannot be squared with the distances printed. The real
  ships went by Panama. Separately, the papers print 95 dogs and then 88 "in good order", and nobody explains the
  difference.
- **The Arcade lien notices** (10 March). Twelve screws hold three notices, two of which were reported torn down.
- **Greenpoint tone.** It is heard on three nights (13 March) against five (9 March).
- **The 8 June licence count.** "Two weeks to Friday" now covers a week with no count. The other choice is to raise
  the totals of 8 and 15 June.
- **The 6 April Speaker editorial.** "Assemblyman Barlow's amendment" and "the licence office" do not match the Record's
  account of the Act.
- **Smaller items.** These need a decision rather than a fix:
  - the doll's price and its refund;
  - the two Pells;
  - the ice-case counts;
  - Frances Perkins's years on the Industrial Commission;
  - Mrs. Dorr's quote, which reads differently in the two papers.
- **Advertisements.** The bill-style ads repeat item prices in the body. The house check does not count a price list as
  a display line. Several ads also end on the firm's slogan rather than a closer of their own.
