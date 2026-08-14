# THE ORISON SONGBOOK — PHRASE DUELS AND LYRIC BOOKS

**OWNER DIRECTION — DESIGN BRIEF, 2026-08-14. No runtime data or code is
authorized by this document.** This sits beneath `ORISON_BIBLE.md` III.2 and
must be reconciled into `ORISON_SONGBOOK_MUSIC_BIBLE.md` when that proposal is
revised.

## 1. The idea in one sentence

Players learn period idioms by hearing people use them, then build a lyric book
from those remembered phrases through multiple-choice calls and retorts — the
verbal-learning pleasure of *The Secret of Monkey Island* sword fights, used as
an interaction shape rather than copied dialogue.

The result is a communal folk process rather than a censorship box:

1. somebody says a memorable thing in ordinary dialogue;
2. the player understands it from context and keeps its phrase card;
3. a later conversation presents a call that one learned phrase can answer;
4. that matched couplet becomes available to the Songbook;
5. the player assembles verses and choruses from the cards they have actually
   encountered;
6. the selected phrase ids, not arbitrary typed lyrics, form the written lyric
   book attached to a recorded community version.

No one asks the player to write like a person from 1928 without first teaching
them how people in this particular building speak.

## 2. What this is and is not

### It is

- a memory of dialogue made mechanically useful;
- a multiple-choice songwriting toy with enough combinations to produce
  authorship rather than one correct song;
- call-and-response comedy, where a literal-minded retort can turn an idiom
  inside out;
- a controlled text vocabulary that can be localized, tested and moderated;
- a reason to listen to residents outside case-critical conversations;
- a genealogy: covering another player's song can teach one phrase card used
  in that version.

### It is not

- a free-text lyric editor for public content;
- a trivia test about 1920s slang;
- a rhythm or pitch score;
- a single "historically authentic" voice applied to all residents;
- a flapper-costume gag in which everybody says `bee's knees` every minute;
- permission to reproduce period slurs because a source printed them;
- protection against inappropriate words deliberately sung into a microphone.

That last distinction is a release boundary, not fine print. Phrase ids make
the lyric **text** safe by construction. A microphone remains arbitrary user
audio. See §12.

## 3. Source rule

The seed bank below is grounded in George H. Maines and Bruce Grant's
*Wise-crack Dictionary*, published at 100 Gold Street, New York, in 1926. The
book says it collected current expressions from 10,000 communications and
other sources across many American social registers. The public-domain text is
available from [Project Gutenberg](https://www.gutenberg.org/ebooks/77369).

That source is evidence that a kernel was available, not proof that every
Queens resident used it. It is comic, sensational, contradictory and contains
racist, sexist, ableist and criminalizing language. **The rejected material is
not atmosphere. It stays rejected.** Every shipping phrase needs:

- an attestation no later than 1928;
- a plain-language gloss;
- a register and plausible speaker/context;
- a meter audit in its complete newly written line;
- a modern harm review independent of historical accuracy;
- a second source when the phrase is identity-coded or its meaning is unclear.

`WCD26` below means the 1926 dictionary attests the **period kernel** in that
row. Surrounding lyric wording is newly written for the game and must not be
presented as a historical quotation.

## 4. The unit: a phrase card

Proposed human-readable schema:

```json
{
  "id": "static_tune_station",
  "line_key": "songbook.phrase.static_tune_station",
  "display_line": "Then tune off that station",
  "plain_gloss": "If you dislike what I say, stop listening.",
  "period_kernel": "Tune off that station",
  "attestation": {"source_id": "WCD26", "year": 1926},
  "registers": ["radio", "quarrel", "barroom"],
  "functions": ["retort", "dismissal"],
  "syllables": 6,
  "stress_shape": "x / x x / x",
  "rhyme_tail": "ation",
  "answers": ["static_full_of_static"],
  "exposure_tags": ["juno_radio_argument", "cal_shop_banter"],
  "safety": "green"
}
```

Runtime data must store localization keys and ids, not English as authority.
The display line is shown here so the writing can be judged before any schema
is promoted into `game/data`.

## 5. Exposure: how a player learns a card

An authored dialogue line may carry one phrase id. When that line is heard to
completion, the dialogue owner emits one narrow fact:

```text
idiom_exposed(phrase_id, speaker_id, dialogue_line_id, context_id)
```

The persistent fact needs only first source, first time and exposure count.
The dialogue system still owns dialogue; the Songbook lexicon owns learned
phrases; neither advances a case.

Rules:

- Twelve plain cards are available from the start so a new player can finish a
  first lyric book without grinding.
- A resident uses only cards that fit their existing voice. Do not distribute
  phrases evenly for spreadsheet neatness.
- Important cards have at least two repeatable exposure sites. A missed bark
  cannot permanently remove a lyric possibility.
- Signs, letters, radio patter and shop talk may expose cards, but reading a
  glossary never does. The phrase must first live in a scene.
- Hearing another player's published version can expose at most one unknown
  card from it. This makes covering social without turning the catalogue into
  a vocabulary loot box.
- The phrase shelf remembers where the player first heard it: `heard from
  Juno, by the service lift`, not an encyclopedia date.

## 6. The duel: call, retort, resonance

A phrase duel is a short dialogue beat, not combat and not a fail gate.

1. An NPC delivers a **call**.
2. The player gets three learned response cards plus `LET IT PASS`.
3. Every response continues the conversation safely.
4. One or more responses are marked **resonant** because they answer the call's
   image, meaning or rhythm particularly well.
5. A resonant answer unlocks the call/retort as a coupled lyric card and may
   earn a laugh, table knock, instrumental pickup or later NPC callback.
6. A non-resonant answer is not failure. Its awkwardness is valid songwriting
   material and may be funnier.

This preserves the Monkey Island pleasure — knowledge acquired in one exchange
becomes wit in another — without requiring one canonically insulting answer or
punishing a player who reads tone differently.

Seed call/retort relationships:

| Call | Resonant retort | Why it connects |
|---|---|---|
| `You're full of static.` | `Then tune off that station.` | one radio image |
| `That story's all wet.` | `It'll come out in the wash.` | water turned from dismissal to patience |
| `You don't know your onions.` | `Then why'd you spill the beans?` | produce-counter nonsense becomes accusation |
| `Nothing cooking.` | `Go cook a radish.` | refusal answered with an impossible errand |
| `Keep your shirt on.` | `I'm hot in the socks tonight.` | calm answered by dance energy |
| `You're out of the picture.` | `See you in the funny sheet.` | one printed image replaces another |
| `Fishhooks in your pockets.` | `Act like a ferryboat — come across.` | stinginess answered by payment |
| `Stop bending my ear.` | `Your ears don't lap over.` | the body image is taken literally |
| `You're between salaries.` | `I'm well-heeled for one night.` | fact answered by temporary bravado |
| `Tell it to the judge.` | `I'm from Missouri.` | two period forms of disbelief |
| `You're a wet blanket.` | `I'm hot in the socks tonight.` | dampening answered by heat |
| `No soap.` | `Then write it on the ice.` | refusal answered with deliberate impermanence |

`Then why'd you spill the beans?` and `It'll come out in the wash` are newly
written bridges around attested kernels. They require the same meter and safety
review as every other complete line.

## 7. The composer: multiple choice, not fill-in typing

Each base song defines phrase slots by musical need, not by fixed words:

```json
{
  "slot_id": "chorus_reply_1",
  "functions": ["retort", "promise"],
  "syllables": {"min": 5, "max": 7},
  "stress_shapes": ["x / x x / x", "/ x / x /"],
  "rhyme_targets": ["ation", "ight"],
  "required_answer_to": "chorus_call_1"
}
```

At a slot, the terminal offers three to five learned cards that fit the meter.
The player can:

- hear each line spoken against the phrase guide;
- see its plain gloss and first-heard memory;
- choose a resonant reply or deliberately choose an odd one;
- swap lines until recording begins;
- save the lyric book as phrase ids and slot order.

No word chips may be rearranged inside a line. Whole curated lines prevent
players from using safe fragments as phonetic building blocks for a slur, keep
meter testable and preserve localization.

Locked cards are shown only as a source hint — `something heard on the sardine
bus` — when their absence would make exploration inviting. They are never sold,
randomized or attached to limited-time events.

## 8. Seed phrase bank — eight decks, 64 complete lines

These are writing seeds, not approved runtime data. Syllable counts use the
intended ordinary American reading and must be verified in recorded speech.

### A. ON THE UP-AND-UP — confidence, praise, dance

| id | complete line | syllables | WCD26 kernel |
|---|---|---:|---|
| `up_on_the_up` | I'm on the up-and-up | 6 | on the up-and-up |
| `up_hot_socks` | Hot in the socks tonight | 6 | hot in the socks |
| `up_strut_stuff` | Let me strut my stuff | 5 | strut your stuff |
| `up_jake_tonight` | It's Jake with me tonight | 6 | it's Jake with me |
| `up_joint_wow` | The whole joint is a wow | 6 | it's a wow |
| `up_cats_pajamas` | I'm the cat's pajamas | 6 | cat's pajamas |
| `up_know_onions` | You know your onions, dear | 6 | knows his onions |
| `up_no_maybe` | And I don't mean maybe | 6 | and I don't mean maybe |

### B. FULL OF STATIC — quarrel, radio, attention

| id | complete line | syllables | WCD26 kernel |
|---|---|---:|---|
| `static_full` | You say I'm full of static | 7 | full of static |
| `static_tune_station` | Then tune off that station | 6 | tune off that station |
| `static_bend_ear` | Stop bending my ear | 5 | stop bending my ear |
| `static_ears_lap` | Your ears don't lap over | 6 | your ears don't lap over |
| `static_air_dear` | Come up for air, my dear | 6 | come up for air |
| `static_loudspeaker` | Shut off the loudspeaker | 6 | shut off the loud speaker |
| `static_break_lips` | Break your lips and tell me | 6 | break your lips |
| `static_tell_world` | Tell the world — I heard you | 6 | tell the world |

### C. SHOE-LEATHER EXPRESS — leaving, transit, return

| id | complete line | syllables | WCD26 kernel |
|---|---|---:|---|
| `travel_lets_blouse` | Let's blouse before the rain | 6 | let's blouse |
| `travel_shoe_express` | We'll go by shoe-leather express | 8 | shoe leather express |
| `travel_shake_step` | Shake a leg and step on it | 7 | shake a leg; step on it |
| `travel_story_walking` | Tell your story walking | 6 | tell your story walking |
| `travel_tree_leave` | Imitate a tree and leave | 7 | imitate a tree |
| `travel_funny_sheet` | I'll see you in the funny sheet | 8 | see you in the funny sheet |
| `travel_sunday_week` | Some Sunday during the week | 7 | see you some Sunday during the week |
| `travel_hello` | If I don't see you, hello | 7 | if I don't see you again, hello |

### D. BETWEEN SALARIES — work, rent, money, nerve

| id | complete line | syllables | WCD26 kernel |
|---|---|---:|---|
| `money_between` | I'm between salaries | 6 | between salaries |
| `money_on_cuff` | Put it on the cuff | 5 | on the cuff |
| `money_on_tick` | We're living on tick | 5 | on tick |
| `money_well_heeled` | Well-heeled for one night | 5 | well-heeled |
| `money_fishhooks` | Fishhooks in your pockets | 6 | fish hooks in his pockets |
| `money_mad_shoe` | Mad money in my shoe | 6 | mad money |
| `money_bacon` | Bring home the bacon, dear | 6 | brought home the bacon |
| `money_ferry` | Act like a ferryboat — come across | 9 | act like a ferry boat — come across |

### E. SPILL THE BEANS — gossip, truth, secrets

| id | complete line | syllables | WCD26 kernel |
|---|---|---:|---|
| `truth_beans_dawn` | Spill the beans before dawn | 6 | spill the beans |
| `truth_sling_dope` | Sling the dope and tell all | 6 | sling the dope |
| `truth_in_know` | Put me in the know | 5 | put in the know |
| `truth_cough_up` | Cough it up, don't whisper | 6 | cough it up |
| `truth_chin_wall` | Chin music through the wall | 6 | chin music |
| `truth_office_cat` | The office cat knows all | 6 | office cat |
| `truth_grain_salt` | Take it with a grain of salt | 7 | take with a grain of salt |
| `truth_on_ice` | Write it on the ice | 5 | write it on the ice |

### F. THE OLD PUMP — affection, luck, heartbreak

| id | complete line | syllables | WCD26 kernel |
|---|---|---:|---|
| `heart_old_pump` | My old pump missed a beat | 6 | old pump |
| `heart_main_squeeze` | You're still my main squeeze | 5 | main squeeze |
| `heart_iceberg` | Come melt the iceberg, dear | 6 | melt the iceberg |
| `heart_sample` | Take a sample, leave a kiss | 7 | take a sample |
| `heart_breaks` | The breaks brought you to me | 6 | the breaks |
| `heart_in_deep` | I'm in the deep tonight | 6 | in the deep |
| `heart_in_wash` | We came out in the wash | 6 | come out in the wash |
| `heart_wrong_number` | You got the wrong number | 6 | getting the wrong number |

### G. THE YOWL BOX — city-night objects and places

| id | complete line | syllables | WCD26 kernel |
|---|---|---:|---|
| `city_face_wall` | My face is on the wall | 6 | face on the wall |
| `city_yowl_night` | The yowl box sings all night | 6 | yowl box |
| `city_sardine_midnight` | Sardine bus at midnight | 6 | sardine bus |
| `city_indoor_aviator` | Indoor aviator, rise | 7 | indoor aviator |
| `city_flying_omelet` | Flying omelet, take me home | 8 | flying omelet |
| `city_tintypes` | Jumping tintypes glow | 5 | jumping tintypes |
| `city_evening_sticks` | Evening sticks are bright | 5 | evening sticks |
| `city_douse_glim` | Douse the glim before dawn | 6 | douse the glim |

### H. STOP THE CLOCK — pacing, rest, restraint

| id | complete line | syllables | WCD26 kernel |
|---|---|---:|---|
| `pace_horses` | Hold your horses, dear | 5 | hold your horses |
| `pace_fan_four` | Fan yourself and count four | 6 | fan yourself |
| `pace_shirt_tonight` | Keep your shirt on tonight | 6 | keeping your shirt on |
| `pace_clock_time` | Stop the clock and take time | 6 | stop the clock |
| `pace_snap_heart` | Snap into it, my heart | 6 | snap into it |
| `pace_tongue_holiday` | Give your tongue a holiday | 7 | give your tongue a holiday |
| `pace_park_dogs` | Park your dogs awhile | 5 | park your dogs awhile |
| `pace_hit_hay` | Hit the hay when we're done | 6 | hit the hay |

## 9. Example lyric book assembled from exposure

Assume the player has heard Juno use `full of static`, learned `tune off that
station` from radio-shop banter, heard Mina say `put me in the know`, and picked
up `shoe-leather express` from a porter. A six-line book could be:

```text
You say I'm full of static
Then tune off that station
Put me in the know
Spill the beans before dawn
We'll go by shoe-leather express
And I don't mean maybe
```

Another player with the same base song but a different social history may write
a money-and-heartbreak version. The backing is shared; the lyric book is a map
of whom the singer listened to.

## 10. Community genealogy

A community version stores:

- base song id;
- immutable version and parent ids;
- phrase id per musical slot;
- first-heard provenance as private/local memory, not uploaded biography;
- recorded vocal stem locally, under the audio rules in §12;
- immutable reconstruction ratio from `ORISON_BIBLE.md` III.2;
- publication scope and moderation state.

When another player covers it, they inherit the **selection**, not ownership of
its wording. Their cover gets a new version id and parent pointer. If it contains
one phrase they have not learned, completing the cover may expose that card with
source `community_cover:<parent_version_id>`. This is how slang travels.

## 11. Text safety, composition safety and localization

- Public lyric text is rendered exclusively from approved phrase ids.
- No free text, custom spelling, Unicode substitution, punctuation field,
  acrostic title or user-reordered word chips enter the sung lyric data.
- Whole-line cards are audited alone and at every allowed adjacent line seam.
- Display names are never interpolated into lyrics. Name moderation remains a
  separate platform problem.
- Phrase cards carry localization keys; translators may replace the idiom with
  a period-plausible target-language equivalent instead of translating the
  vegetable literally.
- Rhyme and meter are per-locale data. English syllable counts cannot silently
  constrain another language.
- Historical slurs and demeaning body/gender labels remain excluded even when
  attested. Period accuracy is a floor for inclusion, never a defense against a
  harm review.

## 12. Public microphone audio — hard launch gate

The phrase system **reduces inappropriate written lyrics but cannot prevent a
player from singing different words into the microphone.** Pitching the result
up does not make abusive speech safe and is reversible enough that it must never
be treated as moderation.

Therefore:

1. `PRIVATE` recording may ship with local storage and deletion controls.
2. `FRIENDS` sharing requires explicit sender and receiver controls, mute/block,
   report and deletion paths.
3. `COMMUNITY` microphone publication stays disabled until the project owns an
   audio-safety design covering consent, pre-transform analysis of the clean
   vocal, reporting, blocking, takedown, appeals, retention and age/platform
   requirements.
4. Moderation must inspect the clean local stem before nightcore reconstruction;
   the public artifact is not a usable safety oracle.
5. If that infrastructure is out of scope, public versions may share only phrase
   ids and a locally reconstructed non-user vocal. Do not imply that curated
   multiple choice solved arbitrary voice UGC.

This is not a rejection of the owner's community recording idea. It is the
proof burden for shipping it responsibly.

## 13. Proof gates before implementation

### Writing proof

- At least 96 green phrase cards: 12 in each of eight registers.
- At least 24 call/retort relationships, with no more than one third relying on
  radio/electrical metaphors.
- Every resident has a reviewed personal exposure list; nobody becomes a slang
  vending machine.
- Every kernel has a source, year, gloss and harm review.
- Six complete sample lyric books read aloud over two contrasting backing
  styles without meter collapse.

### Interaction proof

- One graybox conversation teaches a phrase without a tutorial panel.
- A later duel recognizes it and offers three valid responses.
- The composer filters by learned state, meter and function.
- Missing a first exposure does not block completing a song.
- A cover can teach exactly one unknown approved phrase.

### Data and persistence proof

- Phrase ids, not display strings, persist and cross the network boundary.
- Save/load preserves exposures, lyric selections and parent genealogy.
- Unknown, retired or unsafe phrase ids fail closed with a visible replacement
  marker; they never render raw remote text.
- The full rendered lyric book passes adjacency and localization checks.

### Audio proof

- The normal backing used during composition remains native-speed.
- The published whole take uses one stored too-fast ratio for voice and backing.
- Every recipient reconstructs the same version deterministically.
- Public microphone sharing remains unavailable until §12 is satisfied.

## 14. Recommended first prototype

Use the existing `LAST TRAIN HOME` phrase slots without changing its audio:

1. seed twelve common cards from decks C, E, F and H;
2. annotate one existing Juno or Cal line with `full of static` only after voice
   review;
3. add one repeatable radio-shop exchange whose resonant reply is `Then tune
   off that station`;
4. replace free typing for the prototype with three whole-line choices per slot;
5. save only phrase ids;
6. render two deliberately different lyric books from the same exposure set;
7. keep recording `PRIVATE` while the public-audio gate is unresolved.

If selecting the lines is not funny before recording, do not build the network.
