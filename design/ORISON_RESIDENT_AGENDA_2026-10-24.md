# The residents' agenda: timetables with motives

Evidence class: **INERT - DESIGN NOTE**

*Owner direction 2026-10-24: "create a timetable of places to go, activities
and motivations for all of our npcs informed by the weather, time of year,
personalities, story beats, time of day, needs, and PC behavior. Have them
pursue their goals with simulated behavior."*

## 1. What was there

`resident_schedules.json`, transcribed from `design/ORISON_ARCHETYPE_SCHEDULES.md`,
gives all eighteen residents a timetable for every day shape, plus their
anniversaries. `ScheduleDirector.resolve()` answers where each one should be.
In V2, only Mina's body walks that timetable. Everyone else exists as an
answer to "is she home?": the knock, the observation ledger, window
treatments and the shop counters.

## 2. What the agenda adds

`ResidentAgenda` (`game/scripts/characters/resident_agenda.gd`) sits over
the timetable and decides where each resident actually goes, and why. Its
data is `game/data/resident_motives.json`.

Every ten campaign minutes it scores each resident's candidates and keeps the
best:

- **The timetable block** is the obligation. It scores 0.25 plus the
  resident's *routine* trait times 0.6, or times 0.35 once their story beat is
  resolved. Sleep, work, transit and ritual add 2.0, so they always hold.
- **Needs**: rest, food, hygiene, company, purpose, air and warmth decay by the
  hour. Each candidate's activity, place and authored effect restore some of
  them. Score is the sum of weight × urgency × gain, where urgency rises with
  the square of the shortfall.
  - Company weighs more for the sociable. Air weighs more for those who are
    not homebodies.
  - Asleep, nobody gets lonely and hunger slows.
- **Generic options**:
  - cook at home
  - eat at the bodega counter
  - the Luncheonette
  - nap
  - wash
  - linger in the lobby
  - air on the roof or in the light court (daylight only, except for night
    people)
  - a walk
  - the Harukiya
  - the warm laundry room in the cold
  - their own work
  - calling on a friend who is at home and awake
- **Their own compulsion and change**: each resident's shadow option from the
  archetype doc and their growth option from its rule.
  - Examples: Teresa's patrol for an alarm nobody raised; Evelyn's
    red-pencilling of the noticeboard; Cal never going down to B1.
  - Story beats come from each resident's two `resolution_flags` in
    `reality_cases.json`. While neither is known, the compulsion pulls hard.
    Once the first ("named") is known, it pulls less. Once the second is known,
    the compulsion stops and the growth option opens: Teresa lets an hour go
    undefended, Cal goes down to the laundry, Jonah knocks on 4C.
- **Weather**: exposed places (roof, light court, street, shops across the way)
  lose score with rain, snow, cold, heat and wind, scaled by how *hardy* the
  resident is. Cold costs warmth out of doors. Heat makes air run out faster.
  Day length follows the day of year.
- **People**:
  - Friends in the same shared room add to the score.
  - People a resident avoids there take it away: Juno and Rhea, Peter and
    Evelyn at the mail bank, Omar and Iris, Jonah outside 4C.
- **The player**:
  - **Trust 2 or more:** the resident comes to wherever the night man is, if
    that is a shared room or their own floor's corridor.
  - **Trust -1 or less:** the resident stays out of the room he is in, even
    when the timetable sends them there; hard blocks still hold.
  - The player's place comes from the room he stands in (`player_agenda_place`).
- **Commitment**: a choice made for a need is seen through until its time is
  up, unless a hard block starts. A small stickiness keeps the current choice
  otherwise.
- **The kitchen**: shopping, cooking, eating leftovers and washing up compete
  like everything else (`design/ORISON_KITCHENS_2026-10-24.md`).

Every answer has the timetable block's shape (`place`, `activity`,
`start_min`, `end_min`) and adds `source`, `why`, `motive` and `deviation`,
so a consumer can say why someone is not where the timetable put them.

## 3. Determinism and loading

Live state steps forward on the campaign clock. A load, a jump or a new day
rebuilds the last six hours from the authored starting needs, using the
current weather and no player; this takes about 130 ms. Midnight carries the
building's state over to the next day. The same campaign minute always gives
the same answer.

## 4. Who listens

- **Presence** (`resident_is_home`): the knock, conversations and the
  observation ledger.
- **Window treatments**: a sleeper's blind is drawn.
- **Mina's body**: her route graph limits her to the places it reaches, and
  errands elsewhere become trips off the map.
- **The household kitchens**: all of them.

## 5. Sample lived days

See §7, filled from the test's `AGENDA_REPORT` dump of four sample days: a
sleety winter Tuesday, a fair spring Sunday, a hot summer Saturday and a wet
autumn Thursday.

## 6. Not done

- Only Mina has a body in V2. The other seventeen are simulated, but no one
  sees them walk.
- The shop counters still count only timetable visits, not agenda trips.
- An unanswered knock does not change anyone's plans yet.
## 7. Sample lived days

From the test's `AGENDA_REPORT` dump at the merged tree. Only the choices
that departed from each resident's timetable are listed: everything else
was the timetable kept. The source of each choice is in brackets.

### Winter Tuesday, sleet

- **cal_dwyer**: 09:40-10:30 luncheonette, eating (need): a plate and company at the luncheonette; 15:30-15:50 unit:bathroom, shower (need): washes; 17:30-18:20 unit, radio (shadow): pulls distant stations out of the air and stops every reel short
- **cam_ortiz**: 02:00-02:30 bodega, eating (need): hungry; across to the bodega counter; 18:00-18:50 luncheonette, eating (need): a plate and company at the luncheonette
- **evelyn_marsh**: 10:00-12:00 lobby, rounds (shadow): red-pencils the noticeboard and the posted notices
- **iris_bell**: 11:40-12:30 luncheonette, eating (need): a plate and company at the luncheonette; 13:00-13:20 unit:bathroom, shower (need): washes; 13:20-14:00 unit, hobby (shadow): re-hangs the studio wall for viewers who are not coming; 18:00-18:40 visit:5A, socializing (friend): calls on a friend
- **jonah_price**: 02:30-03:00 bodega, eating (need): hungry; across to the bodega counter; 03:00-03:30 unit:desk, hobby (shadow): starts the book again; 07:30-07:50 unit:bathroom, shower (need): washes; 11:00-11:30 visit:6A, socializing (friend): calls on a friend; 17:50-18:10 unit:bathroom, shower (need): washes (and 1 more)
- **juno_kells**: 02:00-02:30 bodega, eating (need): hungry; across to the bodega counter; 03:30-04:30 unit:bedroom, rest (need): worn out; lies down; 18:00-18:10 visit:1D, socializing (friend): calls on a friend; 18:10-18:40 unit:bathroom, shower (need): washes; 22:30-23:00 bodega, eating (need): hungry; across to the bodega counter
- **lena_ortiz**: 12:10-12:50 visit:1A, socializing (friend): calls on a friend; 17:00-17:20 unit:bathroom, shower (need): washes; 17:20-18:10 luncheonette, eating (need): a plate and company at the luncheonette
- **mae_kessler**: 08:30-09:00 unit, hobby (need): restless; turns to their own work
- **malcolm_reed**: 16:30-17:00 visit:2B, socializing (friend): calls on a friend
- **mina_vale**: 11:40-12:30 luncheonette, eating (need): a plate and company at the luncheonette; 13:00-13:20 unit:bathroom, shower (need): washes; 13:20-13:50 unit:desk, work (shadow): re-checks the day's captions against the record
- **nadia_quell**: 07:20-08:10 luncheonette, eating (need): a plate and company at the luncheonette; 17:00-17:30 unit:bathroom, shower (need): washes
- **noel_price**: 17:30-18:10 unit:kitchen, cooking (need): hungry; cooks something; 18:10-18:30 unit:bathroom, shower (need): washes
- **omar_bell**: 07:10-08:00 luncheonette, eating (need): a plate and company at the luncheonette; 17:30-17:50 unit:bathroom, shower (need): washes
- **peter_wren**: kept the timetable all day.
- **rhea_sato**: 10:00-10:50 luncheonette, eating (need): a plate and company at the luncheonette; 18:30-18:50 unit:bathroom, shower (need): washes; 18:50-19:40 unit, hobby (shadow): sings the piece again and stops at the first waver
- **sacha_reed**: 02:00-02:30 bodega, eating (need): hungry; across to the bodega counter; 18:30-19:10 visit:6B, socializing (friend): calls on a friend
- **teresa_vale**: 07:40-08:30 luncheonette, eating (need): a plate and company at the luncheonette; 08:30-08:50 unit:bathroom, shower (need): washes
- **transient_guests**: 09:00-12:00 lobby, rest (shadow): waits in the lobby for a car that does not come; 18:10-19:00 luncheonette, eating (need): a plate and company at the luncheonette; 19:00-19:50 unit:bathroom, shower (need): washes

### Spring Sunday, fair

- **cal_dwyer**: 08:30-09:20 luncheonette, eating (need): a plate and company at the luncheonette; 09:20-09:40 unit:bathroom, shower (need): washes
- **cam_ortiz**: 01:30-02:00 bodega, eating (need): hungry; across to the bodega counter; 14:50-15:40 luncheonette, eating (need): a plate and company at the luncheonette; 22:40-23:10 bodega, eating (need): hungry; across to the bodega counter
- **evelyn_marsh**: 05:50-06:20 bodega, eating (need): hungry; across to the bodega counter
- **iris_bell**: 12:00-12:50 luncheonette, eating (need): a plate and company at the luncheonette; 12:50-13:10 unit:bathroom, shower (need): washes
- **jonah_price**: 01:20-01:30 bodega, eating (need): hungry; across to the bodega counter; 07:30-07:50 unit:bathroom, shower (need): washes
- **juno_kells**: 01:40-02:10 bodega, eating (need): hungry; across to the bodega counter; 18:10-18:30 unit:bathroom, shower (need): washes; 18:30-19:00 roof, hobby (shadow): records the city from the roof without asking; 23:30-24:00 bodega, eating (need): hungry; across to the bodega counter
- **lena_ortiz**: 05:00-05:30 bodega, eating (need): hungry; across to the bodega counter; 12:10-12:50 visit:4C, socializing (friend): calls on a friend; 17:00-17:50 luncheonette, eating (need): a plate and company at the luncheonette; 17:50-18:10 unit:bathroom, shower (need): washes
- **mae_kessler**: 07:00-07:50 luncheonette, eating (need): a plate and company at the luncheonette
- **malcolm_reed**: 05:00-05:30 bodega, eating (need): hungry; across to the bodega counter; 14:00-14:50 luncheonette, eating (need): a plate and company at the luncheonette
- **mina_vale**: 03:20-03:50 bodega, eating (need): hungry; across to the bodega counter
- **nadia_quell**: 08:30-09:20 luncheonette, eating (need): a plate and company at the luncheonette; 09:20-09:40 unit:bathroom, shower (need): washes
- **noel_price**: 06:50-07:20 bodega, eating (need): hungry; across to the bodega counter; 15:20-16:10 luncheonette, eating (need): a plate and company at the luncheonette
- **omar_bell**: 07:10-08:00 luncheonette, eating (need): a plate and company at the luncheonette; 17:30-18:20 luncheonette, eating (need): a plate and company at the luncheonette
- **peter_wren**: 06:50-07:20 bodega, eating (need): hungry; across to the bodega counter; 14:40-15:30 luncheonette, eating (need): a plate and company at the luncheonette
- **rhea_sato**: 00:00-00:30 bodega, eating (need): hungry; across to the bodega counter; 00:30-00:50 unit, hobby (shadow): sings the piece again and stops at the first waver; 10:00-10:20 unit:bathroom, shower (need): washes; 20:50-21:00 visit:5C, socializing (friend): calls on a friend
- **sacha_reed**: 01:20-01:50 bodega, eating (need): hungry; across to the bodega counter; 09:00-09:20 unit:bathroom, shower (need): washes; 11:40-12:30 luncheonette, eating (need): a plate and company at the luncheonette
- **teresa_vale**: 02:40-03:10 bodega, eating (need): hungry; across to the bodega counter; 14:00-14:20 unit:bathroom, shower (need): washes; 14:20-14:50 corridor, patrol (shadow): patrols for an alarm nobody raised: the boiler knock, the loose tread; 14:50-15:40 luncheonette, eating (need): a plate and company at the luncheonette
- **transient_guests**: 07:00-07:30 luncheonette, eating (need): a plate and company at the luncheonette; 15:20-16:10 luncheonette, eating (need): a plate and company at the luncheonette

### Summer Saturday, hot and clear

- **cal_dwyer**: 09:30-10:20 luncheonette, eating (need): a plate and company at the luncheonette; 10:20-10:40 unit:bathroom, shower (need): washes
- **cam_ortiz**: 02:00-02:30 bodega, eating (need): hungry; across to the bodega counter; 16:00-16:50 luncheonette, eating (need): a plate and company at the luncheonette; 22:00-23:00 harukiya_bar, socializing (need): company downstairs at the Harukiya; 23:50-24:00 bodega, eating (need): hungry; across to the bodega counter
- **evelyn_marsh**: kept the timetable all day.
- **iris_bell**: 12:00-12:50 luncheonette, eating (need): a plate and company at the luncheonette; 12:50-13:10 unit:bathroom, shower (need): washes
- **jonah_price**: 07:30-07:50 unit:bathroom, shower (need): washes; 17:50-18:30 roof, rest (need): needs air; up to the roof
- **juno_kells**: 01:40-02:00 bodega, eating (need): hungry; across to the bodega counter; 03:30-04:20 roof, hobby (shadow): records the city from the roof without asking; 18:10-19:00 roof, hobby (shadow): records the city from the roof without asking; 21:00-21:30 bodega, eating (need): hungry; across to the bodega counter
- **lena_ortiz**: 05:00-05:30 bodega, eating (need): hungry; across to the bodega counter; 13:50-14:00 luncheonette, eating (need): a plate and company at the luncheonette; 17:00-17:20 unit:bathroom, shower (need): washes; 17:20-18:10 luncheonette, eating (need): a plate and company at the luncheonette
- **mae_kessler**: 07:00-07:50 luncheonette, eating (need): a plate and company at the luncheonette; 16:40-17:30 luncheonette, eating (need): a plate and company at the luncheonette
- **malcolm_reed**: 05:00-05:30 bodega, eating (need): hungry; across to the bodega counter; 16:30-17:00 luncheonette, eating (need): a plate and company at the luncheonette
- **mina_vale**: 03:30-04:00 bodega, eating (need): hungry; across to the bodega counter
- **nadia_quell**: 07:10-08:00 luncheonette, eating (need): a plate and company at the luncheonette; 15:20-16:10 luncheonette, eating (need): a plate and company at the luncheonette; 16:10-16:30 unit:bathroom, shower (need): washes
- **noel_price**: 14:50-15:40 luncheonette, eating (need): a plate and company at the luncheonette
- **omar_bell**: 07:10-08:00 luncheonette, eating (need): a plate and company at the luncheonette
- **peter_wren**: 07:00-07:50 luncheonette, eating (need): a plate and company at the luncheonette
- **rhea_sato**: 03:00-03:30 bodega, eating (need): hungry; across to the bodega counter; 10:00-10:20 unit:bathroom, shower (need): washes; 20:00-20:40 visit:5C, socializing (friend): calls on a friend; 22:30-22:50 unit:bathroom, shower (need): washes; 22:50-24:00 unit, hobby (shadow): sings the piece again and stops at the first waver
- **sacha_reed**: 03:00-03:30 bodega, eating (need): hungry; across to the bodega counter; 11:30-11:50 unit:bathroom, shower (need): washes; 14:40-15:30 luncheonette, eating (need): a plate and company at the luncheonette; 18:20-19:00 roof, rest (need): needs air; up to the roof
- **teresa_vale**: 02:50-03:20 bodega, eating (need): hungry; across to the bodega counter; 14:00-14:30 corridor, patrol (shadow): patrols for an alarm nobody raised: the boiler knock, the loose tread; 15:00-15:50 luncheonette, eating (need): a plate and company at the luncheonette; 20:20-20:40 unit:bathroom, shower (need): washes; 23:00-23:30 corridor, patrol (shadow): patrols for an alarm nobody raised: the boiler knock, the loose tread (and 1 more)
- **transient_guests**: 07:00-07:30 luncheonette, eating (need): a plate and company at the luncheonette; 15:10-16:00 luncheonette, eating (need): a plate and company at the luncheonette; 22:00-22:20 unit:bathroom, shower (need): washes

### Autumn Thursday, steady rain

- **cal_dwyer**: 09:40-10:30 luncheonette, eating (need): a plate and company at the luncheonette; 15:30-15:50 unit:bathroom, shower (need): washes
- **cam_ortiz**: 02:00-02:30 bodega, eating (need): hungry; across to the bodega counter; 18:00-18:50 luncheonette, eating (need): a plate and company at the luncheonette
- **evelyn_marsh**: kept the timetable all day.
- **iris_bell**: 09:00-09:50 luncheonette, eating (need): a plate and company at the luncheonette; 09:50-10:10 unit:bathroom, shower (need): washes
- **jonah_price**: 02:30-03:00 bodega, eating (need): hungry; across to the bodega counter; 07:30-07:50 unit:bathroom, shower (need): washes
- **juno_kells**: 02:00-02:30 bodega, eating (need): hungry; across to the bodega counter; 18:00-18:10 visit:1D, socializing (friend): calls on a friend; 18:10-18:30 unit:bathroom, shower (need): washes; 18:30-19:00 luncheonette, eating (need): a plate and company at the luncheonette
- **lena_ortiz**: 12:10-12:50 visit:1A, socializing (friend): calls on a friend; 17:00-17:20 unit:bathroom, shower (need): washes; 17:20-18:10 luncheonette, eating (need): a plate and company at the luncheonette
- **mae_kessler**: kept the timetable all day.
- **malcolm_reed**: 16:30-17:00 luncheonette, eating (need): a plate and company at the luncheonette; 19:30-20:10 visit:2B, socializing (friend): calls on a friend
- **mina_vale**: 11:40-12:30 luncheonette, eating (need): a plate and company at the luncheonette; 13:00-13:20 unit:bathroom, shower (need): washes
- **nadia_quell**: 07:10-08:00 luncheonette, eating (need): a plate and company at the luncheonette; 16:00-16:20 unit:bathroom, shower (need): washes
- **noel_price**: 17:30-18:20 luncheonette, eating (need): a plate and company at the luncheonette
- **omar_bell**: 07:10-08:00 luncheonette, eating (need): a plate and company at the luncheonette; 17:30-17:50 unit:bathroom, shower (need): washes
- **peter_wren**: 17:30-18:20 luncheonette, eating (need): a plate and company at the luncheonette
- **rhea_sato**: 10:00-10:50 luncheonette, eating (need): a plate and company at the luncheonette; 18:30-18:50 unit:bathroom, shower (need): washes
- **sacha_reed**: 02:00-02:30 bodega, eating (need): hungry; across to the bodega counter; 19:00-19:50 luncheonette, eating (need): a plate and company at the luncheonette
- **teresa_vale**: 07:40-08:30 luncheonette, eating (need): a plate and company at the luncheonette; 08:30-08:50 unit:bathroom, shower (need): washes
- **transient_guests**: 17:10-18:00 luncheonette, eating (need): a plate and company at the luncheonette; 19:00-19:20 unit:bathroom, shower (need): washes

### The kitchens, first morning of the four-day run

- day 100 02:00, 2C juno_kells: shopped potatoes, eggs, garlic at the bodega, 68 cents
- day 100 02:00, 6A sacha_reed: shopped potatoes, cabbage, onions, butter, cheddar at the bodega, 116 cents
- day 100 02:10, 2C juno_kells: cooked Bramboráky at Three in the Morning
- day 100 02:10, 6A sacha_reed: cooked Rumbledethumps, Unphotographed
- day 100 02:20, 2C juno_kells: shopped flour, lard at the bodega, 41 cents
- day 100 02:30, 6B jonah_price: shopped cheddar, lager, butter, white_bread at the bodega, 101 cents
- day 100 03:00, 3D rhea_sato: shopped beef_chuck, potatoes, onions, carrots, ginger at the bodega, 68 cents
- day 100 03:00, 6A sacha_reed: washed up 3 pieces
- day 100 03:00, 4D transient_guests: shopped rye_bread, dill_pickles at the bodega, 25 cents
- day 100 03:20, 2A mina_vale: shopped milk, lemons, eggs at the bodega, 69 cents
- day 100 03:30, 2A mina_vale: cooked Arroz Doce with the Date in Cinnamon
- day 100 03:40, 2A mina_vale: shopped rice, milk, sugar at the bodega, 43 cents
- day 100 04:00, 2C juno_kells: washed up 2 pieces
- day 100 07:00, 1A evelyn_marsh: shopped onions, buttermilk at the bodega, 18 cents
- day 100 07:00, 6C mae_kessler: shopped beef_bottom_round, onions, dill_pickles at the bodega, 59 cents
- day 100 07:10, 6C mae_kessler: shopped gingersnaps at the Luncheonette, 10 cents
- day 100 07:10, 5A nadia_quell: shopped sauerkraut, cabbage, smoked_sausage, bacon at the bodega, 90 cents
- day 100 07:20, 6C mae_kessler: cooked Sauerbraten, Certified
- day 100 07:20, 6C mae_kessler: ate Sauerbraten, Certified
- day 100 07:20, 4C noel_price: shopped lamb_neck, leeks, potatoes, carrots, turnips at the bodega, 64 cents
- day 100 07:20, 4A peter_wren: shopped pork_sausages, eggs, milk at the bodega, 92 cents
- day 100 07:30, 6C mae_kessler: shopped beef_bottom_round, vinegar, lard at the bodega, 60 cents
- day 100 07:30, 4C noel_price: cooked Cawl on the Daily Set
- day 100 07:30, 4C noel_price: ate Cawl on the Daily Set
