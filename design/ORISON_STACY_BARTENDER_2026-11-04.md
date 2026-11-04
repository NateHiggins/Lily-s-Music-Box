# Stacy, behind the bar at the Harukiya

Evidence class: **INERT**. Character and dialogue note for the Harukiya's bartender, landed
2026-11-04. It records what the data says and which owner rulings it answers. It proves nothing
and promotes no requirement.

Stacy appears with her own consent, and her likeness in the game is the owner's explicit ruling
of 2026-11-04. Everything written below is fiction for the game; no real biography is used. The
writers' draft, the reference set and the likeness model pipeline stay outside this repository.

## What landed

| File | What it is |
|---|---|
| `game/data/dialogue/stacy.json` | 29 nodes, 5 entries, 20 authored silences. Case-less, undated |
| `game/data/opinions/stacy.json` | 16 dated opinions, each hung on a printed item in `game/data/newspapers/` |
| `game/scripts/game/resident_conversations.gd` | Her tree and opinions added to `TREE_PATHS` and `OPINION_PATHS` |
| `tools/audit_opinions.py` | Prefix `stacy` to `st` |
| `tools/audit_data_consumption.py` | Her two files registered as id-keyed maps, like the other speakers' |
| `design/ORISON_SONGBOOK_MUSIC_BIBLE.md` | The proposal's unnamed "barman" is now Stacy (she/her), eight places |

She is not a resident: no unit, no key, no routine, no case and no mystery thread. Her slug and
speaker id are `stacy`, her node and flag prefix is `st_`, and her opinion prefix is `st_op_`.

## Who she is

Staff at the Harukiya, which belongs to an unnamed family kept offstage until the Songbook's
cultural consultation. She came north from New Orleans, which is named in her own lines only.
Early to mid thirties, a dark shingled bob with one henna streak, oxblood lips, a bar apron and
sleeve garters, a small jet pendant. Under the counter are Judge, the fourteen-year-old tan dog,
and **Lafitte**, the orange-and-white cat, named for the pirate because he steals. The jar by the
till is decoupaged in black lace and pressed magnolia; it is the tips, and it is carfare, soup and
once a dentist for anyone who comes up short.

Her comic engine is that she invents a house rule on the spot and enforces it as though it had
always been law, and every rule is cover for a kindness. Her one written law is the posted
NO BANANAS BEFORE 10 PM. Prohibition is near beer on the board, cold tea in the pot, and the
precinct man drinking the tea on Thursdays.

She never calls the player a man, never says "okay", never talks therapy, never praises her own
generosity, and never makes fun of whoever is in trouble.

She is together with the player's self-insert and the game never says so. It shows in small acts
only: the second cup carried down to the bass case on Thursdays (**st_rt_quiet**, seen once), one
umbrella between two (**st_op_thaw**), and one of them waiting at closing for the other.

## Her opinions

| Id | Window | Topic |
|---|---|---|
| **st_op_snow** | 1928-11-25 to 1928-12-20 | 'Audibly still.' |
| **st_op_party_line** | 1928-12-15 to 1928-12-29 | The exchange cat gets a saucer. |
| **st_op_thaw** | 1928-12-23 to 1929-01-12 | The ice men sent home for Christmas. |
| **st_op_brownie** | 1928-12-27 to 1929-01-25 | The burglar who said good night to the dog. |
| **st_op_jackson** | 1929-01-15 to 1929-02-10 | A pup named for the Avenue. |
| **st_op_valentines** | 1929-02-14 to 1929-03-12 | Two hundred and fourteen second takes. |
| **st_op_exhibit** | 1929-03-30 to 1929-04-28 | The exhibit 'not produced.' |
| **st_op_dawn_wedding** | 1929-04-18 to 1929-05-04 | The Babe marries at half past five. |
| **st_op_major** | 1929-05-05 to 1929-06-02 | The ice horse who walked back to work. |
| **st_op_one_dish** | 1929-06-28 to 1929-07-13 | One dish of ice cream a customer. |
| **st_op_ninety_three** | 1929-08-05 to 1929-08-31 | Ninety-three, and three down in the street. |
| **st_op_nell** | 1929-09-03 to 1929-09-27 | Nell's harness comes off at King Park. |
| **st_op_danko** | 1929-09-28 to 1929-10-11 | 'Danko, dog,' present. |
| **st_op_chairs** | 1929-10-13 to 1929-11-05 | Sixty-one folding chairs and a stepladder. |
| **st_op_margin_call** | 1929-10-29 to 1929-11-09 | 'Exactly and at an even pace.' |
| **st_op_the_book** | 1929-11-03 to 1929-11-09 | 'Asked to see the book and went away.' |

No window covers 14 to 26 July, and none answers an item about the Hum, the lease, Barclay 4420,
Position 43, the Moon, the night tone or One Short's half past ten. The clinic-raid item of 16 and
20 April was passed over on purpose: its follow-up returns the records under a spider seal, and a
gothic bartender standing beside that would read as a suspect.

## Owner rulings this answers

All from 2026-11-04: her name as written with no surname; the bob with one dyed streak; together
with the self-insert, never announced; the owning family unnamed with Stacy as staff; both animals;
New Orleans named; sixteen opinions rather than eleven; no moons or keys on the jar; **Lafitte**
after the pirate; the Songbook's "barman" becomes Stacy at its next revision; and the Thursday
second cup kept in her dialogue where the player sees it once.

## What she never touches

She holds no `m_` flag and carries no case. Nothing of hers names the May take, Juno's pocket
recorder, the piano bench, Astoria, Teresa's glass, 19 July or Mae Kessler, and she offers no
theory about the uncanny ("It's large"). No handwriting of Adela's stays on view at the bar,
because the handwriting comparison is evidence.

## Held open

1. **Her schedule.** `game/data/resident_schedules.json` has only a `residents` map, read by the
   key-ring, the presence ledger and the schedule director. A non-resident with no unit does not
   belong in it without a decision, so her blocks are not landed. The drafted shape is Tuesday to
   Sunday, 16:00 to closing, Monday off, and it needs a `harukiya_bar_counter` service place that
   `game/data/orison_v2/bar_resident_places.json` does not have.
2. **A conversation point at the counter.** She has no door, so until a counter interaction exists
   her tree and opinions are reachable only the way the player reaches the self-insert's.
3. **Her model.** The owner builds it in Meshy from a turnaround sheet; ingest follows
   `art/blender/scripts/ingest_adela_character.py`. Nothing of it is in this change.
4. **Judge and Lafitte** have no placement: the dog wants the boiler board under the counter, the
   cat a shelf and a back room.

## Verification

Python only; no Godot run. `tools/audit_opinions.py stacy` passes at 16 opinions, and the whole set
passes at 308 for 18 speakers. `tools/audit_authored_voice.py` passes her tree at 29 nodes, all
reachable. `tools/check_mystery_dialogue.py` passes the whole set at 25 speakers and 0 failures,
which covers her lines for misaddress, forbidden names, modern terms and after-death wording.
`tools/audit_data_consumption.py --baseline` reports NEW 0. `tools/audit_period_dates.py` passes.
`tools/tests/test_data_consumption.py`, `test_check_mystery_dialogue.py` and
`test_campaign_weather.py` pass, 47 tests. The GDScript edit adds two literal paths and was not
compiled: the Godot lane was held for another agent's camera diagnostic.
