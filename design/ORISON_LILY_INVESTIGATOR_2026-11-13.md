# Lily Fern, the woman behind the curtain

Evidence class: **INERT**. A design note: how the owner's brief of 2026-11-13 for Lily is fitted to
what the game already holds, and her rulings of the same day. It records a plan and first drafts.
It proves nothing and promotes no requirement. The Bible, the treatment, the murder chronology,
the prologue and the Tardi stinger outrank everything here.

Lily is the owner's self-insert. Everything written here is fiction for the game, written at
her direction. The brief itself stays outside this repository.

## 1. What the brief asks

Lily is a working woman: she takes appointments for a price, and she sings and plays at the
Harukiya. She is Stacy's partner, Adela's friend and model, and the woman who insists the truth
must mean something to somebody. She has five optional cases of her own, a network apart from
Stacy's, and she shadows Stacy rather than the player. Her voice is theatrical and candid, with
plain speech for contrast. Her stance, in the brief's words: "Lily is the woman who insists that
the truth must mean something to somebody."

## 2. The owner's rulings, 2026-11-13

- **lily_surname_20261113**: she is Lily Fern in the game, the surname the brief gives her.
- **lily_occupation_20261113**: in the owner's words, "she is available to npcs and the player for
  a price". Built here as appointments that are always offscreen and never explicit; see section 4.
- **lily_instruments_20261113**: canon stands. Lily plays drums on one number and bass on another,
  never both, and sings the harmony. The piano is Adela's, then Juno's. Lily is the ear in the
  piano case.
- **lily_case_piano_20261113**: a human answer is found (a tuner's boy through the wall, a
  song-plugger's copy). One phrase a regular remembers her playing before she wrote it stays
  unexplained and is never attributed.
- **lily_case_register_20261113**: no paper from the future. The register is written back in for
  a day the house says the woman had gone; two lodgers disagree; the woman in the grey hat from
  Stacy's case 1 lodged there once.
- **lily_case_alibi_20261113**: the man with the good stationery from Stacy's case 2 wants an
  alibi for an unrelated crime in May. Adela's dated developing slip, not a photograph, shows
  where Lily was. Nothing near 19 July.
- **lily_case_mirror_20261113**: the impostor dresses as LILITH, not as Lily. LILITH stays
  unexplained.
- **lily_case_lastsong_20261113**: one investigation seen two ways. Lily's grief and the
  unfinished song run beside Stacy's case 5. The card stays Stacy's. Lily's false lead is the
  Ravenswood portrait; her new lead is Stacy's card.
- **lily_shadow_20261113**: same hold as Stacy. Her cases and bar talk first, then her own day and
  attendance with the integration owner; following after the owner has played both women's cases.
- **lily_companion_voice_20261113**: she calls the companion "the Vantry", as Stacy does. It answers
  in print, only from what it has seen. Her flirting with it is her line, not a conversation.

## 3. What still stands

- She holds nothing in the main case, is on no record of 19 July, and never learns who rides the
  night man: a good ear is not recognition.
- No Lily thread runs from 14 to 26 July 1929.
- She and Stacy are together and the game never announces it; it shows in small acts.
- Her daily strip and the LILITH comic are hers. LILITH is never named, unmasked or explained.
- All text is authored. Behaviour is schedules, rules and state machines (**RUL-015**).

## 4. Her appointments

Two dated threads (before 14 July and after 26 July) and one about her appointment book, in
`game/data/mystery/lily.json` under `lfa_`. The rules written into them:

- A price, paid before the curtain; she keeps the clock; the night man may change his mind.
- What happens behind the curtain is never shown or described. The hour is a cut: the curtain,
  the clock, and what she says afterwards. The owner's style guide holds: attention under
  restraint, consent legible and specific, cut before anatomy becomes inventory.
- Residents who visit her appear only in her book (initials and the weather) and in what she
  hears. No resident is shown with her.
- She keeps what someone is lonely about. What someone means to do to somebody else is a
  different ledger.
- The two appointment threads are **held** until the caretaker economy can take the fare; nothing
  she sells is free, and none of it is a repeatable income for the player.

The player is Adela riding the night man, and Lily does not know it. That is in the scene and is
not remarked on.

## 5. The five cases, first drafts

All under `lf1_` to `lf5_` in `game/data/mystery/lily.json`. Optional and outside the solve
chain. Each ends with something put right and something left open.

1. **The Girls Who Never Checked Out** (December 1928 to March 1929). Minnie leaves Mrs.
   Hackett's rooming house on the 4th; her note to Lily is dated the 6th. Two lodgers disagree.
   The man in the camel coat holds her debts. Lily protects her first and takes his paper apart
   quietly. Left open: a cry through a wall she had already left.
2. **The Piano Remembers** (March to June 1929). Five notes from Adela's piano with nobody on the
   bench. A song-plugger copied the act's arrangement; a tuner's boy across the light well plays
   it at night. Adela is paid and apologised to. Left open: Mr. Haskell heard the phrase at
   Christmas, and Lily wrote it in March.
3. **The Gentleman's Alibi** (May to July 1929, ending 13 July). Mr. Truesdale offers fifty dollars
   for the night of 2 May, when a clerk's ledger burned. Lily was in Adela's darkroom; the
   developing slip says so. The clerk and her brother keep their jobs. Left open: who pays for
   his stationery.
4. **The Other Woman in the Mirror** (June to 13 July 1929). A tall figure in LILITH's mask works
   the Steinway Street hotels and once uses Lily's name. A pickpocket from Corona is caught. Left
   open: the clerk who saw Lily on a night she was on stage.
5. **The Last Song for Adela** (August to November 1929). Adela's chair, the unfinished song, the
   Ravenswood portrait and the bookkeeper in its doorway (the false lead), a quarrel with Stacy,
   and Stacy's card (the true one). The last thread needs `sc5_card`. She plays the song after
   closing for one listener and an empty chair.

## 6. How she is built

| She needs | Built on | Notes |
|---|---|---|
| Case talk and appointments | `game/data/mystery/lily.json`, read through `MYSTERY_PATHS` | Her earlier threads are kept as they were |
| A conversation point | none yet | Today her threads open through the playtest panel only; a point of her own is the integration owner's |
| The fare for an appointment | `caretaker_economy.gd` | Not built; the threads stay held until it is |
| Her own day, attendance, following | the integration owner's actor and route work | Held by **lily_shadow_20261113** |
| Her looks (stage, working, private) | parts fitted to her installed body | Not started; her body belongs to the integration owner |

## 7. Not decided

- The fare's amount in the game's economy and what an hour costs in game time.
- Where her appointments are kept, and whether the player ever sees the room.
- Her own looks, and when they are made.
- Which residents are in her book, if any are ever named.
