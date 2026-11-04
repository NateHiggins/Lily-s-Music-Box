# Mystery continuity pass and daily-life flavour

Evidence class: **INERT**

Date: 2026-11-04. Branch **claude/mystery-continuity**, from main **4f16053e8**. Lily asked for "an editing pass of
our murder mystery and surrounding logic for consistency" and "flavor that connects our larger events to the
minutia of daily life". Two writers worked one at a time. Their full reports stay outside the repo, at
`C:/ov/reports/mystery_edit/CONTINUITY_2026-11-04.md` and `FLAVOUR_2026-11-04.md`.

## Rulings, 2026-11-04

Lily ruled four questions the continuity read raised. They are recorded in `~/homebrew-tools/data/rulings.json`:

| Ruling | Answer |
|---|---|
| **mystery_arcade_age** | The Arcade opened in November 1928. Emil has lived "over this shop, since the day it opened" |
| **mystery_vantry_route** | Vantry climbs from the yard by the drop ladder below F02 and never touches the roof |
| **mystery_rhea_plates** | Rhea's plates were in the middle drawer, also emptied that night. Nadia says so |
| **mystery_print_gap** | "Nothing printed from inside the gap" binds the house only. Off-site events may print |

## Continuity fixes made

The continuity read found 3 problems that break the solve, 11 that contradict canon and 9 cosmetic ones. Fixed here:
- **The white kid no longer hangs on one yard window.** Teresa's note and the Guests' "lodger" thread open from
  the patrol sheet or from the 16 July paper (**m_c_n16**). Teresa gets a matching first reply.
- **The 20 July papers put the twister at 6:08 p.m.,** as the sky schedule printed in the same issue does.
- **Rhea's dates.** She sits on 13 April and the quarrel stays on the 20th. Her chorus and dub threads close before
  each cut.
- **Canon slips:**
  - Nadia's tea line no longer gives Mae the clause's contents.
  - Adela's enlarger line no longer foreshadows.
  - Vantry no longer explains himself.
  - Malcolm no longer has Adela on his roof in November.
  - Adela's 19 July lobby thread ends at 18:25.
- **The window.** Nadia's 4 November card exists, and Evelyn's seven is in the register.
- **A memorial page is never a key.** The Wiggins page of 16 September no longer grants **m_c_boxes**. The other
  three papers carry the notice.
- **Period words, per D3 and D8,** and small time fixes for Ewald, Omar, Sacha and Lena.
- **The checker.** **check_mystery_dialogue** now holds **m_drama_disc** in its set of solve flags. The chains
  document no longer claims Ewald's letter opens in ordinary play, and lists what is owed.

Not fixed, and why:
- **Runtime carriers.** These are code work. In order: **m_trade_log**, **m_boiler_sheet**, **m_o1_print**,
  **m_receipt_seen**. The ledger box also needs its glove and note, and Ewald and the patrolman need somewhere to
  stand. All of this is recorded in **ORISON_SUSPECT_CHAINS_2026-10-31.md**.
- **Name collisions.** Raymond Orr and Hiram Voss need new names, which come to Lily under D7.
- **Schedules.** Noel's 20:40 corridor block is a schedule change, and Iris's window card needs a slot.

## Flavour added

38 items, each a physical change in somebody's routine rather than a reaction to the event:
- **16 opinions,** across 14 residents.
- **9 mail deliveries** to box 4B.
- **Two new back pages:** the Record of 25 July and the Speaker of 14 October.
- **5 schedule special days.**

The events they follow:
- the aurora
- One Short
- Not at Home
- the Moon's growth
- the heat before the murder, and the grief after it
- the oil-works fire
- the Emergence
- the crash

What the items avoid:
- placing any resident between the evening of 19 July and 22 July
- touching any carrier: the roof, the yard, keys, gloves, plates, drawers, clocks or the drama
- naming Adela

For Lily to read first:
- **Evelyn's "Wedensday" pair:** **em_op_wedensday**, **em_op_corrected** and her 3 September special day.
- **Lena cooking for twelve:** **lo_op_twelve**.

Held:
- **The 12 eclipse items.** They go with **claude/sun** (PR 153), since the eclipse exists only there.
- **The Harukiya radiator work order (M03).** It would give the night man a reason to be in the room for "The
  extra two bars", which changes how that beat is found. It is Lily's call.
- **Two field notes.** They need a producer in code.

## Verification

- **Static checks, all PASS:**
  - **check_mystery_dialogue:** 0 failures.
  - **audit_opinions:** 308 opinions, 0 failures.
  - **audit_newspapers:** 59 back pages, 0 failures.
  - **audit_data_consumption --baseline:** NEW 0.
  - **test_check_mystery_dialogue:** OK.
- **Runtime**, on the lane, with receipts in `C:/ov/reports/mystery_edit/runs/`:
  - CompileChangedScripts PASS.
  - MailBankTest PASS and WorldFlagTest 0 failures.
  - ScheduleTest PASS, including new checks of every added special day. Each is checked at its first and last
    minute and one minute past its end, its place must give a legal directive, and nothing may touch 19 to 22 July.
    **self_test** resolves at doy 0, so before this nothing exercised special days.
  - ResidentConversationTest 0 failures. Main failed it 3 times, all from **field_notes.json**: the two uniform notes
    ran past the printer's 30 columns, and the test still expected 2 notes. The lines are wrapped with their words
    unchanged, and the test now requires all four notes by id. Codex agreed this repair boundary.
  - NewspaperTest has 1 failure: the "outside click and corner are distinct visible targets" check. It also fails on
    a control run of main plus the Sun branch, so it is inherited and untouched here.
- **Receipts:** any **game/data** change expires the runtime receipts. Per D9, this lands in a planned window and
  the packets are re-earned once.
