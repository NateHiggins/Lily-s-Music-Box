# Lily, Stacy and Adela: resident detail, first pass — November 14, 2026

Evidence class: **INERT**

Lily asked for "all the resident detail behavior" on Lily, Stacy and Adela, and for Adela to be "controlled like any
other npc" (2026-11-14). Her rulings: **cast3_homes_20261114**, Lily in the Orison and Stacy off the block; and
**cast3_adela_scope_20261114**, Adela a full resident of the year until 19 July 1929, absent after. Everything
below is a **first draft for Lily to read**. Authored text only (RUL-015).

## What this pass adds

| System | Lily (resident, 3C) | Stacy (staff) | Adela (staff, until 21:03 on 19 Jul 1929) |
|---|---|---|---|
| Schedule (`resident_schedules.json`) | new: her day, nights at the bar, two dated days | kept as it was | new: the shop, the set, her dated days |
| A life that ends on a date (`schedule_director.gd`, `lives_until`) | — | — | yes |
| Base conversation tree (`dialogue/*.json`) | new, 21 nodes | kept | new, 18 nodes |
| Weather remarks | new | new | new |
| Music tastes | new | new | new |
| House cookbook receipt | new | held | held |
| Motives (agenda) | new | held | held |
| Door key | her original for 3C; may authorise a spare | — | — |
| Household (`apartment_life_profiles.json`) | new, 3C | — | — |
| Dated opinions on the papers (`opinions/*.json`) | new, 17 | kept | new, 16, the last closing 12 July 1929 |

## Decisions made in drafting

- **Lily's flat is 3C.** It was vacant and locked. Rhea Sato, a vocal coach, lives next door in 3D, and 3C sits on
  the acoustic flue, which carries Lily's bass through the house. 2D is the other vacant flat. 5D is fire-damaged
  and 6D is the landlord's storage.
- **Adela lived over her shop.** Canon has "Miss Adela Voss lived on Jackson Avenue, not in the house" (treatment)
  and "Over this shop, since the day it opened" (Emil). So she is staff, with no flat and no key, like Stacy.
- **This pass supersedes the 1 Nov note** that Adela gets no schedule entries (`V2_ADELA_PERFORMANCE_AND_FOUND_FAMILY`,
  `V2_ADELA_SOUND_PICTURE_PLOT`). Lily's ruling of 14 Nov replaces it.
- **The murder hours stay unvisitable.** Her last block on the 19th ends at 21:03. Her dated beats follow the
  treatment: the watch at 18:05, the note to Mae, the roof at 18:25.
- **Lily's paid appointments are never scheduled.** Canon has not decided where they are kept, and they stay
  offscreen and non-explicit.
- **No invented people.** A draft line gave Adela a rival in the pun competition, a dentist in Flushing, who is in
  no canon. It was cut; she now keeps a file on "the winners".
- **Staff motives and receipts are held back.** The resident agenda moves residents by need, and Stacy is
  counter-bound by ruling. The house cookbook is "Receipts of the House, gathered for the Tenants' Association";
  neither woman is a tenant. Their drafts are kept for a Harukiya menu or a staff agenda later.

## Not done in this pass

- **Lily's haunting case and dream** (`reality_cases.json`, `dream_profiles.json`). This is a case design: a wound,
  a truth rule and a dream incarnation. It goes to Lily as a proposal.
- **Walking the building in their cast bodies.** The resident routines still spawn the old resident models. This
  needs the resident-swap work (order **w9189b10b24ac**).
- **Canon tensions found while drafting:**
  - 18 March was a Monday, when the bar is closed.
  - 2 May was a Thursday, rehearsal night, but Lily was in the darkroom.
  - 9 June was a Sunday, not a set night.
  - A loop-script draft has Stacy drumming on "Pull Up a Chair".
