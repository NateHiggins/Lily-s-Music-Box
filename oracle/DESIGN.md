# THE BLANK DECK: design

Evidence class: **INERT** (a design document for the oracle; it proves nothing about the Orison build)

Status: version 0.1.0, written 2026-10-03. This document and the files in **oracle/content/** are edited together: the content files carry the data, this file says what the data means. Section numbers here are cited by the source field in the meta block of each content file, so do not renumber them.

## 1. What this is

THE BLANK DECK is a text adventure of fifteen to thirty-five minutes that watches how one person plays and writes the description of a small game made for that person. It is the front door of **docs/AI_GAME_DEVELOPMENT_MANUAL.md**: the manual needs a creator's prompt, and this program produces one from play instead of from a sentence.

It has two outputs.

- For the player: a **reading**. Five to nine visions, each one a card turned over, each specific enough that a game can visibly make it true.
- For the builder: an **oracle packet**. A game description with design signals and their evidence, design implications, a Game Design Vector, negative constraints, personal callbacks, one feature nobody asked for, what is not known, and the scope the game must fit.

It is not a personality quiz. It never asks which games, genres, difficulties or stories the player likes. It stages situations in which two desirable things conflict and records which one the player took, what they examined, what they ignored, what they spent, how they took failure, and what they tried that nobody suggested.

It is a model of play preferences and of nothing else. Section 9 is the boundary.

### 1.1 The fiction

A narrow shop the player has never noticed. The Proprietor, a dry voice in a speaking tube, hands over a deck of blank cards tied in ribbon: "Carry these up to the Reading Room. The house is in the way. It usually is. Bring them back with faces." The house deals rooms the way a hand deals cards. At the top, the Proprietor turns the cards over, and they have faces: the bearer made them on the way up.

The frame was chosen because it makes the profiling invisible without making it dishonest. The player is told at the start that the game remembers what they do. They are not told what it is for until the reading, where the purpose is the reveal.

The bearer carries a Joker ("PLAY ME ONCE. WHAT YOU SAY, GOES."), a book of three matches, and may pick up a brass doorknob that belongs to no door. These are instruments: a single-use power, a scarce consumable and a useless object. What a player does with each, across a whole night, is evidence no single room can give.

### 1.2 Division of labour

| Done by a language model | Done by deterministic code |
|---|---|
| Narrating: answering free text in the fiction | The player model: every number in it |
| Reading an action as a game designer would, with competing hypotheses | Which room is dealt next, and which ways onward are offered |
| Making one coherent game of the evidence | Pacing: when a room must close, when the night ends |
| Writing the reading in the Proprietor's voice | State, persistence, validation, the privacy guard |
| | The packet, the builder hand-off, the developer view |

The model proposes; the code keeps the books. A model can be wrong about one turn without corrupting the profile, because the profile is recomputed from the observation log every time it is read, and the log is inspectable.

With no model at all the program still runs: every room is authored with options, outcomes and evidence, and the design and the reading have a complete rule-based form. That offline mode is what the tests and the simulated players use, and where a live night lands if the model stops answering.

## 2. The player model

Source of truth: **oracle/model.py** and **oracle/content/dimensions.json**.

### 2.1 Dimensions

Eighty-six dimensions in nine families.

Seventeen two-poled **axes**. The value runs from -1 (the first pole) to +1 (the second).

| Axis | -1 | +1 |
|---|---|---|
| agency | guided | self directed |
| discovery mastery | discovery | mastery |
| planning | deliberative | improvisational |
| risk | preservation | experimentation |
| failure | failure averse | failure as information |
| friction | low friction | high friction |
| complexity | minimal | systemic |
| explicitness | clarity | mystery |
| optimization expression | efficiency | expression |
| narrative | systems first | narrative first |
| pacing | contemplative | relentless |
| session rhythm | bite sized | long form |
| exploration | goal route | exhaustive |
| control | vulnerability | power |
| consequence | reversible | permanent |
| legibility | opaque emergent | transparent calculable |
| social | solo | populated |

Nine two-poled **aesthetic axes**: organic or mechanical, clean or decayed, familiar or alien, bright or dark, maximalist or minimal, cute or severe, natural or architectural, grounded or surreal, orderly or chaotic.

Seven families of independent **weights**, where +1 means drawn to it and -1 means declined when it was cheaply offered:

- reward (14): mastery, discovery, collection, power, expression, revelation, humor, spectacle, completion, creation, competition, cooperation, surprise, transgression
- problem solving (10): spatial, execution, pattern, deduction, resource, linguistic, experimentation, social, optimization, lateral
- conflict (6): avoidance, negotiation, manipulation, direct, tactical, chaotic
- social texture (8): companions, rivalries, recurring characters, factions, simulation, crowds, competition, cooperation
- tone (13): cozy, funny, absurd, mysterious, melancholy, eerie, frightening, heroic, romantic, intimate, contemplative, chaotic, triumphant
- story interest (4): character, world, plot, emergent
- power arc (5): weak to powerful, capable to overwhelmed, stable power, wild escalation, strange

Each dimension has an importance between 0 and 1 that says how much it should shape a design: the axes are 0.8 to 1.0 except session rhythm at 0.6, reward weights 0.9, problem solving and tone 0.8, conflict 0.7, social texture and story 0.6, aesthetics 0.5, power arc 0.4.

### 2.2 Evidence and belief

An **observation** is one thing the player did, with: the turn, the scene, the frame (the kind of room), whether it was behavioral or an explicit statement, a strength, the action in words, what was in tension, and one or more **hypotheses**. A hypothesis is a dimension, a direction and a share of the observation.

Each dimension is a Beta belief over "leans toward the +1 pole":

    alpha = 1 + (mass of evidence toward +1)
    beta  = 1 + (mass of evidence toward -1)
    value = 2 * alpha / (alpha + beta) - 1
    confidence = 2 * |P(p > 0.5) - 0.5|, then capped

The mass a hypothesis contributes is

    strength (weak 0.3, moderate 0.6, strong 1.0)
    x kind (behavioral 1.0, explicit 0.7)
    x share
    x 0.5 ^ k        k = earlier observations of the same dimension and direction in the same scene

Four rules follow from the brief and are enforced in code, not left to the model's judgment:

1. **One choice is never definitive.** Confidence is capped at 0.35 while the evidence comes from one scene and at 0.70 from two. Only from three independent scenes can it rise to 0.97.
2. **Repeating a behaviour in one room is one behaviour.** The second same-direction observation in a scene counts half, the third a quarter.
3. **What players say is useful and not privileged.** An explicit statement is recorded as such and weighs 0.7 of the same thing done.
4. **Evidence both ways is kept.** Supporting and contradicting observation ids are stored per dimension. Nothing is averaged away.

For every dimension the model stores: value, confidence, status, the two evidence masses, the number of observations, the number of independent scenes, the number of different frames, the last turn it was seen (recency), how many observations were explicit and how many behavioral, and the supporting and contradicting observation ids.

### 2.3 Statuses, and "we do not know"

| Status | Meaning |
|---|---|
| unknown | total mass below 0.15: there is nothing to say |
| faint | some evidence, confidence below 0.3 |
| leaning | confidence at least 0.3 |
| established | confidence at least 0.6 from at least three independent scenes |
| contested | at least 0.6 of mass on each side, the smaller at least half the larger: the player went both ways |

An unknown dimension has no influence on the design. The packet lists it under "What is not known" and the Game Design Vector field it would have set says so. A contested dimension is information: it is the first place the synthesis looks for the productive contradiction.

In fifty simulated nights (five personas, ten seeds) a standard night ended with 19 to 32 of the 86 dimensions carrying any reading, 1 to 10 leaning and 0 to 2 established. That is the honest size of what twenty-odd choices can show, and the reason the design is built on a few signals rather than on all of them.

### 2.4 Behavioural signals

**oracle/content/signals.json** lists twenty-nine things a player can do in any room, each with its usual reading: asking a question before acting, asking what to do, examining unprompted, waiting, trying to go back, taking stock, hurrying, joking, trying something the scene did not suggest, testing the narrator, obeying promptly, looking for an exploit, retrying after failure, changing strategy after failure, avoiding after failure, hoarding, spending freely, asking for information before an irreversible act, roleplaying, protecting a character, attaching to a character, testing how the house works, inventing a goal, asking for numbers, seeking undo, relishing permanence, following curiosity at the expense of progress, prolonging a situation, and stating a preference outright.

The narrator model is shown the list with ids and may tag an observation with one. Offline, signals with detection phrases are matched in the player's line when no authored option fits.

How the player treats the interface is evidence too, with one deliberate exception: see 2.6.

### 2.5 Competing readings

Actions are read the way a game designer would read them, never literally. A player who attacks a harmless creature may be testing what the simulation allows, enjoying consequences, making a dark joke, wanting freedom, optimising, or mistyping. The narrator is instructed to record the competing readings as separate hypotheses and split the share between them.

The model then does two things with an ambiguous observation (two or more dimensions, no share above 0.6):

- **It lets later scenes settle it.** On every recomputation, each reading's share is re-weighted by how much independent support that reading has since gathered in other scenes: new share is proportional to share x (0.5 + support elsewhere, capped at 2.0), renormalised so the observation's total weight is unchanged. Both the original and the adjusted shares are kept and shown in the developer view.
- **It asks the house to settle it.** An observation whose leading reading still holds under 55 percent of the weight, with the runner-up close behind, is an open ambiguity. The next room is chosen partly for its power to tell those readings apart (section 3.2).

### 2.6 Recorded but not used

The time between a prompt and the player's reply is not measured and not used. Reading speed, typing speed and hesitation are facts about a person, not preferences about play, and a model that used them would be measuring the wrong thing. The **session rhythm** axis is inferred only from in-fiction investment (carrying the seedling, staying in the quiet room), never from the clock.

Not using something is weak evidence. A Joker still unplayed at the end of the night is also what forgetting about it looks like, so the end-of-night observation for it is weak; a refusal made in a room where spending it would have helped is recorded in that room at its proper strength.

## 3. Encounter seeds

Source of truth: **oracle/content/seeds_core.json**, **seeds_more.json**, **seeds_last.json**. Thirty-three rooms: the counter (always first), the Reading Room (always last), thirty ordinary rooms and one callback room.

### 3.1 What a room is

A room is one situation in which desirable things conflict. Each is authored as:

- a **premise** for the narrator, saying what is there and what the tension is;
- an **intro**, shown as written when the house is offline and adapted to the threshold's manner when a model narrates;
- **targets**: the dimensions the room can show, each with a power from 0 to 1;
- **separates**: pairs of signed readings that this room's options tell apart;
- **reads**: cues for the narrator's notes ("steps onto the planks at once: risk toward experimentation, planning toward improvisational");
- **options**: what a player might do, each with match phrases, an outcome, evidence triples, a strength, whether it closes the room, effects on the world, and sometimes a remembered **moment** and a **card**;
- a hint, a fallback, a nudge and a closing line, so that a player who types nonsense is never stuck.

A room's kind (hazard, choice, social, puzzle, skill, explore, quiet, pursuit, make, chance, mystery, expression, resource, plan, spectacle, plot, power, collect, comic, long, route, system) is its frame. The model counts frames, because the brief asks for repeated patterns across differently framed situations.

The loader (**oracle/content.py**) refuses a room with an unknown dimension, a malformed evidence triple, an option with no way to match it, or evidence shares totalling more than 1.6. The tests add: every room has a way out that is open before any flag is set; every flag an option waits on is one the room can set; no room's text asks about games or taste.

### 3.2 Which room is dealt next

Decided when a room closes, in **oracle/probes.py**, and recorded with its score parts.

    need(dimension) = importance x (1 - confidence)
                      x 1.5 if a signal has been seen in fewer than three scenes   (confirm it)
                      x 1.3 if contested                                             (look again)
                      = 0   if confidence >= 0.75 from three scenes                  (known: stop testing)

    score(room) = sum(power x need) / sqrt(number of targets)
                + disambiguation: 0.6 per open ambiguity whose readings the room separates (0.3 if only
                  the dimensions match), at most 1.2
                + variety: -0.5 same kind as the last room, -0.25 a kind used in the last three,
                  +0.2 a kind not yet used, -0.2 the same intensity twice running
                + timing: the callback room is held back until the last two chambers
                + a small seeded jitter

The room is then drawn from the five best candidates with probability proportional to exp(score / 0.3), so two nights do not open with the same rooms and a strong candidate is still much the likeliest.

This is the adaptive probing the brief asks for: dimensions that are known stop attracting rooms, a faint signal attracts a second look in a different frame, and an action with two readings attracts the room that separates them.

### 3.3 The callback room

"What the House Kept" is eligible only when the bearer has left something unresolved and only late. It brings one such thing back in a mirror, once, under the opposite conditions. Taking it shows the earlier refusal was circumstance; declining again shows it was preference. It is how a single ambiguous choice gets its second, differently framed observation.

## 4. Thresholds

Source of truth: **oracle/content/skins.json**. Fourteen ways onward (a brass hatch, a doorway grown over with roots, a small yellow door, a white arch, and so on), each with a description, a manner that dresses the next room, aesthetic directions and tones.

Between rooms the house offers three. They are chosen to disagree with each other on the aesthetic axes and tones the model knows least about, so that taking one is a comparison. Which quality of the way drew the bearer is not known, so the pick is recorded as competing hypotheses: every axis of the way taken gets a share, larger where the rejected ways pointed the other way. Aesthetic evidence is moderate, tone evidence weak. If the bearer does not choose and the house chooses for them, nothing is recorded.

This is the only place aesthetics are probed directly, and it never asks a question.

## 5. The night

Source of truth: **oracle/engine.py**, **oracle/narrator.py**, **oracle/offline.py**.

    the counter -> threshold -> room -> threshold -> ... -> the Reading Room -> the reading

- Length: short is four rooms between the counter and the Reading Room, standard six, long eight.
- A room has a soft cap of three player turns (the narrator is told to make finishing easy) and a hard cap of five (the room closes). The Reading Room has a hard cap of two. A player cannot die or become stuck.
- At a threshold, a second line that does not choose a way lets the house choose.

### 5.1 The narrator's contract

One model call per turn. The system prompt (**content/narrator_system.md**) carries the fiction, the rules of narration, the rules of the notes, the dimension list and the signal list; it is identical all night, so it is cached where the backend supports caching. The turn prompt carries the state of the night, a directive for this scene (premise, cues, pacing, and what to do when the room closes), the last few exchanges, and the player's line.

The reply is two blocks: the narration the player reads, and the Reader's notes as JSON (scene status, state changes, observations with hypotheses, things engaged with or passed over, something attempted that the fiction could only half honour, a card, a moment). Only the narration is shown, as it streams.

The reply is read tolerantly. Missing tags, code fences and trailing commas are repaired. If the notes cannot be read at all, the player still gets the narration, the turn is logged as unread, and the authored reading of the nearest option is used when the line clearly meant one. If the model forgets to describe the ways onward, the engine supplies them from the page. If the model is told the room must close and does not close it, the engine closes it.

### 5.2 What the narration may never contain

Any question about which games, genres, difficulty or stories the player likes, or about their life. Any mention of notes, profiles, preferences, measurement or tests. Out-of-character remarks. A card growing warm in a coat pocket is the most the house admits. The guard logs any narration that breaks this for the developer view.

### 5.3 When the model fails

A backend that is not signed in or not reachable ends the live narration for the night: the player is told in one line that the house's voice has gone quiet and the night continues from the page. A single timeout or refusal costs one offline turn; two in a row end live narration.

## 6. From profile to design

Source of truth: **oracle/synthesis.py**, **oracle/content/implications.json**, **oracle/content/reading.json**.

### 6.1 Signals

Every dimension with a reading becomes a candidate signal with a salience of |value| x confidence x importance. Three become **dominant** and two **secondary**. Signals that say nearly the same thing (opening every door and playing for discovery; planning and protecting what one has) are folded together through the **related** groups, so the design is not one pleasure counted three times. Tones, story interests and power arcs are flavours: they set fields and never count as one of the five.

The design does not try to satisfy every recorded preference. That is how a kitchen sink is made.

### 6.2 The productive contradiction

Thirty-two authored pairs of signals in tension, each with a resolution and a line for the reading: mystery and precision become a mysterious world governed by exact, discoverable rules; a guided player who breaks rules becomes a guided game that keeps handing them rules it hopes they will break. The strongest pair both of whose sides hold is chosen. Failing that, a contested axis becomes the contradiction: the game offers both ways through and never locks one in. If the night showed no tension the packet says so. In fifty simulated nights a contradiction was found in forty-five.

### 6.3 Design implications, never scores

Each pole of each axis and each weight has an authored rule: a signal in plain words, a design implication, Game Design Vector values, negative constraints and lines for the reading. The packet prints implications ("the world contains optional spaces with mechanically meaningful discoveries, and the main route stays visible so that wandering feels voluntary"), never "exploration 0.86".

### 6.4 The Game Design Vector

Thirty-one fields: central fantasy, core verb, primary and secondary loop, progression structure, world structure, difficulty philosophy, failure cost, learning style, explicit instruction, exploration density, mechanical complexity, systemic interaction, pacing, session length, narrative density and delivery, NPC density, social structure, randomness, permanence, reward schedule, collectibles, customization, audiovisual mood, camera, control complexity, interface density, hidden information, replayability, ending structure.

Each field is set by the strongest signal that speaks to it. The rule draft records which signal set each field. A field no signal speaks to takes a stated default and is marked as a default, which the builder may change and must record.

### 6.5 Negative constraints

Collected from the chosen signals and from weights the player clearly declined: "No mandatory quest log." "Avoid repeated-death loops." What the game must not contain binds the builder as firmly as what it must.

### 6.6 Scope

Every generated game is a pocket game, because one agent must build it alone: Godot 4.x following the manual in its scaled-down form; ten to thirty minutes long; one core mechanic and at most two supporting ones; visuals drawn in code; no downloaded assets; single player, offline; nothing leaves the machine; one command to run and an automated smoke test. The scope constraints are in **implications.json** and are printed into the packet and the builder's prompt.

### 6.7 The model stage

When a model is available, the evidence and the rule draft are given to it as a designer (**content/synthesis_design.md**), with instructions to make one coherent game, not to match a genre, to respect what is unknown, to include a feature that follows from behaviour, and not to rebuild the house as the game. Its answer must validate: exactly three dominant and two secondary signals, a resolution for the contradiction, at least six implications, every Game Design Vector field present and non-empty, constraints, callbacks and the unrequested feature present, and nothing that makes a claim about the person. A rejected answer gets one repair attempt with the problems listed, then the draft stands.

## 7. The reading

The reading is written by the Proprietor (**content/synthesis_prophecy.md**) from the finished design and the night, or assembled by rule from **reading.json** when no model is available.

- An **address** as the deck is squared: the bearer thought they were carrying the cards somewhere; the cards were being made.
- Three or four **recollections**: things the bearer did, returned as plain facts with no interpretation.
- Five to nine **visions**, one card each. Cards the bearer earned in the house keep their titles. Each vision names what in the design makes it true. At least two transform an image from the night. One may be an absence ("I see no quest log.").
- The pronouncement: I HAVE SEEN WHAT YOU WILL PLAY.
- A last line. When a game has been built it is the Proprietor's own. When it has not, the line says so: "It is not built yet. Take the deck to whoever builds for you."

The reading may not use the language of analysis (profile, preference, data, percent, "you tend to"); a model's reading that does is rejected and repaired or replaced. It may not say who the bearer is, only how they played. If the evidence was thin it turns a blank card and says it will not pretend to read it.

**Personal callbacks** turn something the bearer did into something in the game: a companion kept becomes a companion; a door passed becomes the place where the best of the game is kept; something they tried that the house could only half allow becomes possible. **The unrequested feature** is chosen from behaviours, the most particular first: a player who drew a room on the unfinished map gets a map whose blank edges become real.

The visions are promises. The packet lists each with what makes it true, and the builder is told that each must be visibly true in the finished game.

## 8. The packet and the builder

Source of truth: **oracle/packet.py**, **oracle/builder.py**, **content/builder_prompt.md**.

The packet is a folder: the game description, the design profile as data, the reading, the builder's prompt, the transcript, and a copy of the process manual (its operating core and its reference files) when one is found beside the program. The game description carries the repository's document-class header so that it can be committed as a brief without being mistaken for proof.

A build is never started unless the player asks. When they do, a builder (Codex, Claude Code or any command) is started in a fresh project directory containing the packet, with the builder's prompt on its standard input.

**Build progress is reported truthfully or not at all.** The builder is asked to append one JSON line to an events file each time something has actually happened. The oracle shows one line of the fiction per event and shows nothing on a timer.

| Event | Shown as | Withheld unless |
|---|---|---|
| packet read | OTHER HANDS HAVE TAKEN UP THE CARDS. | |
| covenant written | ITS LAWS ARE BEING WRITTEN. | the named file exists |
| project created | A WORLD IS FORMING. | the named file exists |
| first run | THE WORLD HAS OPENED ITS EYES. | the named file exists |
| core verb playable | THE CREATURES HAVE LEARNED HOW TO MOVE. | |
| loop complete | ONE WHOLE DAY HAS PASSED IN IT. | |
| test failed | THE WORLD HAS DIED. | |
| fixed | THE WORLD IS BEING BORN AGAIN. | a failure was reported first |
| tests passing | THE FUTURE NOW RUNS WITHOUT ERROR. | the named file exists |
| vision fulfilled | A CARD HAS COME TRUE. | the card is one that was dealt |
| done | IT IS FINISHED. | the result file exists |

A proof path must lie inside the project. Events without a required proof, unknown events and repeats are withheld and listed in the developer view with the reason. What the builder reports without proof is shown on the builder's word, and the build log is kept so that word can be checked. A builder that exits without a result file, or does not finish in time, is reported as failed in plain words.

The finished game is never launched without the player saying yes to the exact command.

## 9. The boundary

1. The model is of play preferences. There is no dimension for anything else, so the structured half of an observation cannot leave the boundary.
2. Free text written by a model can. Every such string is checked: text that makes a claim about the player's health, diagnosis, intelligence, sexuality, politics, religion, age, gender, ethnicity or disability is replaced by a placeholder and the event is logged. The dimension evidence beside it is kept. Ordinary words in fiction ("the old man at the toll") pass; the same words as a claim about the player do not.
3. A design or a reading that makes such a claim is rejected.
4. Uncertainty is kept. The packet says what is not known.
5. Persistence is explicit. Before the first prompt the game says that it remembers, where, how to erase it, and whether what the player types is sent to a model service. `python -m oracle forget` erases a night or all of them; `--no-save` keeps nothing but the packet.
6. Nothing is sent anywhere except to the narrator backend the player chose, under their own account with it.

## 10. The developer view

`python -m oracle dev` writes one self-contained HTML file: every observation with its readings and how later evidence moved their shares; every dimension with value, confidence, status and evidence both ways; how the profile moved turn by turn; which room was dealt after each chamber, with the candidates and their score parts; the open ambiguities; the signals ranked; the design, the Game Design Vector with the source of each field; the reading; the exact prompts sent to the models and to the builder; the build events shown and withheld; guard events; the backend log; the transcript. `--dev` during play prints the house's reasoning after each turn.

## 11. Backends

| Backend | How | Tested here |
|---|---|---|
| anthropic | the Anthropic API through the official SDK; streaming; cached system prompt; effort low for turns and high for the design; server-side refusal fallback | not run: the SDK and credentials are not on the development machine |
| claude | the Claude Code command line in print mode with tools disabled | reaches the binary; its login on the development machine had expired, so no narration was produced through it |
| codex | the Codex command line, read-only sandbox, reasoning effort low for turns | yes: a live night (below) |
| command | any program that reads a prompt and writes text | by the tests, with a scripted stand-in |
| offline | the authored rooms | yes: the tests and fifty simulated nights |

`auto` tries the installed backends in that order with one short request and uses the first that answers.

## 12. What was verified, and how

- **Tests.** 81 tests in **oracle/tests/** pass (`python -m unittest discover -s oracle/tests -t .`). They cover the Beta arithmetic against known values; the confidence caps; same-scene discounting; contested evidence; explicit against behavioral weight; re-weighting of ambiguous observations; the profile as a pure function of the log; content validity and coverage; the offline matcher; a whole offline night; hard caps; the house choosing at a threshold; save and resume; the live narrator path with a scripted stand-in (state, evidence, cards, thresholds, unreadable notes, a failed backend, the guard); stream filtering at four chunk sizes; the rule draft for five personas; uncertainty with no evidence; validation, repair and fallback of model answers; the packet; the developer view and its escaping; the event reader's judgments; a build run against a fake builder; time-out of a builder; the command line; and terminal wrapping of streamed text.
- **Simulated players.** Five personas played ten seeded nights each. Across the 100 pairs of different personas on the same seed, between 8 and 24 of the 31 Game Design Vector fields differed, and no two personas shared the same three dominant signals.
- **A live night.** One very short night (the counter, one room, the Reading Room) was narrated by Codex on 2026-10-03: seven turns took 21.8 to 29.1 seconds each; the notes parsed on every turn; an invented action (drawing a fifth switch in chalk) was honoured and recorded; the design and the reading were both written by the model and passed validation without repair, in 219.5 seconds together.

Not verified: the Anthropic API backend and the Claude command-line backend producing narration; a real builder completing a game from a packet (only the hand-off and the event reader are tested, against a fake builder); a full-length night with a human player.

## 13. Known limits

- A night gives twenty to thirty-five observations. Most dimensions end unknown. The design rests on a handful of leaning signals, and says so.
- Offline, free text is matched against authored options by keyword. It cannot improvise and it reads only what the authors anticipated.
- Through the Codex command line a turn takes about twenty-five seconds and does not stream. A standard night is then closer to thirty-five minutes than to twenty-five; `--length short` is the remedy.
- The evidence strengths, the confidence caps and the selector's weights were set by judgment and by the simulated personas, not fitted to people. They are constants at the top of **model.py** and **probes.py**.
- The personas are caricatures chosen to differ. They show that the pipeline separates distinct ways of playing; they do not show that it reads a real player correctly. Only people playing it, and saying whether the reading was right, can show that.
