# The six cases as Adela's attachments

Evidence class: **INERT**. This is a proposal for Lily's rulings, not a checkpoint. Every line in it is a first draft.

Date: 2026-11-22. Author: Claude. Source ruling: direction ruling 3 of 21 November (`design/ORISON_DIRECTION_PROPOSAL_2026-11-21.md`, sections 5 and 7.2). Work order **waf82e7d1d400**.

## 1. What the ruling asks

The six resident cases (Mina, Peter, Juno, Mae, Cal, Omar) stop being separate chapters. Each becomes one of Adela Voss's
attachments to this world. The player lets each one go during the murder year, a RELEASED slip prints, and that night's
sleep plays the case's release-print dream. The Bible's premise already says it: "the campaign year is the span of it:
that is how long it took Adela Voss to let go of her attachments to this world" (§I).

## 2. What exists

- **Releases.** `game/data/temporal/anchors.json` **arc.releases** prints a RELEASED slip when a flag is known or an item is
  held (`temporal_loop.gd` `_attend_releases`). Nine slips exist; they release the case's objects and people (THE NIGHT
  OF 19 JULY, THE SHOP, EMIL, THE WINDOW, THE NEGATIVES, PLATE 13, THE FUTURE, MRS. KESSLER, NADIA). One of them, MRS.
  KESSLER, is already a case resident.
- **Dreams.** `game/data/dream_profiles.json` has the six release prints (`mina_release_print` to `omar_release_print`,
  campaign slots 1 to 6). `CoreLoopDirector` arms one through `dream_requested(case_id, profile_id, window)`;
  `SleepPressureDirector` enters an armed dream when the night man sleeps. Today only Mina's maintenance job arms one.
- **The six residents' murder dialogue.** Each already holds a piece of the case (`game/data/mystery/<slug>.json`). None
  of them yet says what Adela left with them.

## 3. The proposal: one attachment each

Each attachment is something Adela left in that resident's keeping. The trigger is a flag the lead tree already grants,
so no new lead or gate is needed. The resident's existing theme (Bible §IV.1) is the reason the letting-go hurts.

| Resident | Theme (§IV.1) | What Adela left with them | Released by (existing flag) | Earliest | Slip |
|---|---|---|---|---|---|
| **Mina Vale** (2A) | the record displaced the thing | Being seen: Mina saw a light in the shop at 23:36 and struck out the person she wrote after it. | `m_mina_light` ("I saw light. I wrote a person.") | 23 Jul | RELEASED: THE LIGHT IN THE SHOP. |
| **Peter Wren** (4A) | his own | The deed she copied: the reversion clause nobody read but her, and him. | `m_peter_will_sign` (he will sign the petition) | 1 Aug | RELEASED: THE CLAUSE. |
| **Juno Kells** (2C) | connection needs an open channel | Her voice: the dubbed Harukiya take, four minutes eleven of a Saturday in May. | `m_heard_self` (the player plays the dub) | 3 Aug | RELEASED: THE SONG. |
| **Cal Dwyer** (5B) | presence is not preservation | The last word on his tape: "There," twenty seconds to 21:01, and the episode that went out a week early. | `m_door_match` | 24 Aug | RELEASED: THE BROADCAST. |
| **Omar Bell** (3B) | some things are not repairable | The bell she paid extra for, "now you can prove you have one". | `m_recorder_limit` | 14 May | RELEASED: THE BELL. |
| **Mae Kessler** (6C) | certainty is not memory | Her name, said aloud by the woman who would not use it. | `kept_papers` (as now) | 9 Nov | RELEASED: MRS. KESSLER. (unchanged) |

Omar's `m_recorder_limit` can be learned in May, before the murder. Releasing before 19 July would make no sense, so
his release also requires the night to have happened (`m_c_n16`, the flag behind THE NIGHT OF 19 JULY). The
alternative is `m_plate_salvaged` (23 Sep, the warped slide "A.V. 13"), but that is PLATE 13's object, already
released by its own slip.

## 4. The release dream

When one of these six slips prints, the matching release print is armed (`case_id` `attach_<slug>`, `profile_id`
`<slug>_release_print`), and the next sleep in 4B plays it. This uses the existing `dream_requested` path; no new
dream system is needed. One dream is armed at a time; a second release waits for the next night. The Bible's rule
holds: the dream is the last image of a released attachment, never a preview of the next one.

## 5. The order

The Bible orders the release prints **Mina, Peter, Juno, Mae, Cal, Omar** (§IX, amended 2026-08-20). The tree's
earliest dates give **Mina, Peter, Juno, Cal, Omar, Mae**: Mae can only come last, because her name is said on
9 November (S14). The campaign slot (1 to 6) sets each dream's difficulty. Recommended: slot by release order, so the
sixth dream is always the hardest, whichever attachment it is.

## 6. What it does not change

- No resident's behaviour, line or schedule changes. The release is the player's act; the residents don't know.
- The twelve case-less residents stay as they are.
- The maintenance job that arms Mina's dream today keeps working until the attachment path replaces it; the two must
  not arm her dream twice.
- `reality_cases.json` keeps the six case designs as the record (Bible §IV.1, "Deleting the twelve case designs").

## 7. Rulings filed

1. **attach_six_mapping_20261122**: the six attachments and triggers in section 3 (recommended), or rework them.
2. **attach_omar_trigger_20261122**: Omar's bell after the night (recommended), or the salvaged plate.
3. **attach_dream_order_20261122**: slots by release order with Mae last (recommended), or keep the Bible's order.
4. **attach_slip_text_20261122**: the five new slip lines as drafted (recommended), or she rewrites them.

## 8. Build, once ruled

1. Five rows in **arc.releases**, each with `"dream": "<slug>_release_print"`, plus `"after": "m_c_n16"` on Omar's.
2. `_attend_releases` arms the dream through `CoreLoopDirector` when a row carrying `dream` releases; one armed dream at a
   time, with the rest queued in the save.
3. A test drives each flag, checks the slip, sleeps, and checks the right profile entered.
4. The Bible's §IX order line is amended to the ruled order.

## 9. Ruled and built (2026-11-22)

Lily answered all four rulings with the recommended option. Built on this branch:

- Five rows in **arc.releases** (**attach_mina**, **attach_peter**, **attach_juno**, **attach_cal**, **attach_omar**),
  each naming its release print; Omar's carries `"after": "m_c_n16"`.
- `TemporalLoop._attend_releases` honours `after` and asks for the print; `bind_release_dreams` asks again for every
  print already released, so an older save still dreams it.
- `CoreLoopDirector` queues release prints (**core_loop.release_dreams**, **release_dreams_done**), arms one at a time after
  Mina's job dream with the slot by release order in the window, and `notify_release_wake` returns the player to the
  4B bedside without touching the job loop. Mina's print is never armed twice: whichever path reaches it first plays it.
- `DreamDirector.complete_return` reconciles a release print's wake; `DreamMazeRoot` reads the window's slot first.
- Tests: **ReleaseDreamQueueTest** (17 checks, including the interrupted-return restore Codex found) and eight new checks in **TemporalLoopTest** (263 in all).
- The Bible's section IX order line is amended.

Mae's print waits for her row: RELEASED: MRS. KESSLER is not on main, and by ruling
**mrs_kessler_release_carrier_20261122** it prints when Nadia says the name in S14. That row gets
`"dream": "mae_release_print"` when S14 is staged.

