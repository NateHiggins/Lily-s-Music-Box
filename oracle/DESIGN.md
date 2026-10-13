# THE BLANK DECK: design

Evidence class: **INERT** (a design document for the oracle; it proves nothing about the Orison build)

Status: version 0.2.0, 2026-10-03. Version 0.1.0, written the same day, narrated through a model by default, wrote a folder of files and could start a builder itself; this version is a standalone program whose one product is a prompt (section 8). On 2026-10-04 a phone version was added beside it (section 14); the program itself did not change. This document and the files in **oracle/content/** are edited together: the content files carry the data, this file says what the data means. Section numbers here are cited by the source field in the meta block of each content file, so do not renumber them.

## 1. What this is

THE BLANK DECK is a text adventure of fifteen to thirty-five minutes that watches how one person plays and writes the description of a small game made for that person. It is the front door of **docs/AI_GAME_DEVELOPMENT_MANUAL.md**: the manual needs a creator's prompt, and this program produces one from play instead of from a sentence.

It is a standalone program. It needs Python and nothing else: no model, no account, no network. The only AI in the chain is the coding agent the prompt is later pasted into.

It has two outputs.

- For the player: a **reading**. Five to nine visions, each one a card turned over, each specific enough that a game can visibly make it true.
- For the builder: one **prompt**, ready to paste. It carries the design signals and the behaviour each was seen in, their design consequences, a Game Design Vector, laws, echoes of the night, one feature nobody asked for, what is not known, the reading as acceptance criteria, and the scope the game must fit.

It is not a personality quiz. It never asks which games, genres, difficulties or stories the player likes. It stages situations in which two desirable things conflict and records which one the player took, what they examined, what they ignored, what they spent, how they took failure, and what they tried that nobody suggested.

It is a model of play preferences and of nothing else. Section 9 is the boundary.

### 1.1 The fiction

A narrow shop the player has never noticed. The Proprietor, a dry voice in a speaking tube, hands over a deck of blank cards tied in ribbon: "Carry these up to the Reading Room. The house is in the way. It usually is. Bring them back with faces." The house deals rooms the way a hand deals cards. At the top, the Proprietor turns the cards over, and they have faces: the bearer made them on the way up.

The frame was chosen because it makes the profiling invisible without making it dishonest. The player is told at the start that the game remembers what they do. They are not told what it is for until the reading, where the purpose is the reveal.

The bearer carries a Joker ("PLAY ME ONCE. WHAT YOU SAY, GOES."), a book of three matches, and may pick up a brass doorknob that belongs to no door. These are instruments: a single-use power, a scarce consumable and a useless object. What a player does with each, across a whole night, is evidence no single room can give.

### 1.2 What the program does alone, and what a model adds when asked

Every room is authored with options, outcomes and evidence, and the design and the reading have a complete rule-based form. That is the program: the default night, what the tests and the simulated players run, and all that the single-file build needs.

A model narrates only when one is asked for with `--narrator`. Then the labour divides:

| Done by the model | Always done by deterministic code |
|---|---|
| Narrating: answering free text in the fiction | The player model: every number in it |
| Reading an action as a game designer would, with competing hypotheses | Which room is dealt next, and which ways onward are offered |
| Making one coherent game of the evidence | Pacing: when a room must close, when the night ends |
| Writing the reading in the Proprietor's voice | State, persistence, validation, the privacy guard |
| | The prompt, the developer view |

The model proposes; the code keeps the books. A model can be wrong about one turn without corrupting the profile, because the profile is recomputed from the observation log every time it is read, and the log is inspectable. If the model stops answering, the night goes on from the page.

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

An unknown dimension has no influence on the design. The prompt lists it under "Not known" and the Game Design Vector field it would have set says so. A contested dimension is information: it is the first place the synthesis looks for the productive contradiction.

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

A model that is not signed in or not reachable ends the live narration for the night: the player is told in one line that the house's voice has gone quiet and the night continues from the page. A single timeout or refusal costs one offline turn; two in a row end live narration.

### 5.4 A player who is stuck

With no model behind it the house reads a line by its keywords, and a parser that leaves a player guessing at words is a bad game. So the deck helps. When a player asks ("hint", "help", "what can I do?"), or misses twice in one room, the room's authored hint is given and a blank card slides out of the deck with a few pencilled words on it: one word or phrase for each way through the room that the house is willing to name.

- **A word on the card does what it says.** Typed back, it selects its own option and no other. The word shown is the first of the option's keywords for which that is true; a test holds it for every room in every state the room can be in. Where two options would both answer a line, the more particular keyword wins ("dust-coat" over another option's bare "coat").
- **A request for help never acts.** A line that is only a request is answered and the room stays as it was, even where the room has an option that listens for the same word. "Help the dog" is still the player doing something.
- **A way that is meant to be found is never named.** An option tagged as an exploit, a transgression or a trick stays off the card, so finding it is still evidence.
- **Unasked, the card comes once per room. Asked for, it always comes.** A hint repeated every turn is a nag. At the reading table, asking does not end the night.
- Asking is itself a behaviour and is recorded as one (the signal **asks_what_to_do**).

### 5.5 How an act is written down

Every recorded act is kept as a past-tense phrase with no subject, in the third person, because it is read by someone other than the player: "mapped the switchboard one switch at a time", "asked the Proprietor about the red button before choosing". An option carries a **moment** (also read back at the table) or a **did**; a universal signal carries a **seen**. The loader refuses an option that has evidence and neither, and refuses the second person in any of them. In the prompt these phrases follow "Seen when they:".

## 6. From profile to design

Source of truth: **oracle/synthesis.py**, **oracle/content/implications.json**, **oracle/content/reading.json**.

### 6.1 Signals

Every dimension with a reading becomes a candidate signal with a salience of |value| x confidence x importance. Three become **dominant** and two **secondary**. Signals that say nearly the same thing (opening every door and playing for discovery; planning and protecting what one has) are folded together through the **related** groups, so the design is not one pleasure counted three times. Tones, story interests and power arcs are flavours: they set fields and never count as one of the five.

The design does not try to satisfy every recorded preference. That is how a kitchen sink is made.

### 6.2 The productive contradiction

Thirty-two authored pairs of signals in tension, each with a resolution and a line for the reading: mystery and precision become a mysterious world governed by exact, discoverable rules; a guided player who breaks rules becomes a guided game that keeps handing them rules it hopes they will break. The strongest pair both of whose sides hold is chosen. Failing that, a contested axis becomes the contradiction: the game offers both ways through and never locks one in. If the night showed no tension the packet says so. In fifty simulated nights a contradiction was found in forty-five.

### 6.3 Design implications, never scores

Each pole of each axis and each weight has an authored rule: a signal in plain words, a design implication, Game Design Vector values, negative constraints and lines for the reading. The prompt prints implications ("the world contains optional spaces with mechanically meaningful discoveries, and the main route stays visible so that wandering feels voluntary"), never "exploration 0.86".

### 6.4 The Game Design Vector

Thirty-one fields: central fantasy, core verb, primary and secondary loop, progression structure, world structure, difficulty philosophy, failure cost, learning style, explicit instruction, exploration density, mechanical complexity, systemic interaction, pacing, session length, narrative density and delivery, NPC density, social structure, randomness, permanence, reward schedule, collectibles, customization, audiovisual mood, camera, control complexity, interface density, hidden information, replayability, ending structure.

Each field is set by the strongest signal that speaks to it. The rule draft records which signal set each field. A field no signal speaks to takes a stated default and is marked as a default, which the builder may change and must record.

### 6.5 Negative constraints

Collected from the chosen signals and from weights the player clearly declined: "No mandatory quest log." "Avoid repeated-death loops." What the game must not contain binds the builder as firmly as what it must. The prompt calls them laws, because the manual puts them into the covenant verbatim.

### 6.6 Scope

Every generated game is a pocket game, so that it gets finished. The lines are in **implications.json**, in two lists. *Held by the owner:* ten to thirty minutes of play in all, and whole; one core mechanic and at most two supporting ones; Godot 4, 2D, desktop, unless a survey of the machine argues otherwise; visuals drawn in code, with no downloaded or generated assets until the owner rules on a look; no downloaded audio; single player, offline; one command to run. The owner pasted these and has not examined them: the builder proposes changes and makes none until the owner answers, because the manual reserves scope and platform to the owner. They are not called defaults, since a default is something the builder may change for a stated reason. *Not open at all:* nothing leaves the machine; original everything; photosensitive-safe.

### 6.7 The model stage

When a model is available, the evidence and the rule draft are given to it as a designer (**content/synthesis_design.md**), with instructions to make one coherent game, not to match a genre, to respect what is unknown, to include a feature that follows from behaviour, and not to rebuild the house as the game. Its answer must validate: exactly three dominant and two secondary signals, a resolution for the contradiction, at least six implications, every Game Design Vector field present and non-empty, constraints, callbacks and the unrequested feature present, and nothing that makes a claim about the person. A rejected answer gets one repair attempt with the problems listed, then the draft stands.

## 7. The reading

The reading is written by the Proprietor (**content/synthesis_prophecy.md**) from the finished design and the night, or assembled by rule from **reading.json** when no model is available.

- An **address** as the deck is squared: the bearer thought they were carrying the cards somewhere; the cards were being made.
- Three or four **recollections**: things the bearer did, returned as plain facts with no interpretation.
- Five to nine **visions**, one card each. Cards the bearer earned in the house keep their titles. Each vision names what in the design makes it true. At least two transform an image from the night. One may be an absence ("I see no quest log.").
- The pronouncement: I HAVE SEEN WHAT YOU WILL PLAY.
- The last card. The Proprietor gathers the deck into one card, covered edge to edge in small handwriting that is not addressed to the bearer: "It is not built yet. This one is for whoever builds for you." That card is the prompt, and the fiction ends there.

The reading may not use the language of analysis (profile, preference, data, percent, "you tend to"); a model's reading that does is rejected and repaired or replaced. It may not say who the bearer is, only how they played. If the evidence was thin it turns a blank card and says it will not pretend to read it.

**Personal callbacks** (the prompt calls them echoes) turn something the bearer did into something in the game. One event is one echo: a remembered moment whose option set the flag, gave the companion or cost the failure that another echo already tells is passed over for the next moment. They turn it like this: a companion kept becomes a companion; a door passed becomes the place where the best of the game is kept; something they tried that the house could only half allow becomes possible. **The unrequested feature** is chosen from behaviours, the most particular first: a player who drew a room on the unfinished map gets a map whose blank edges become real.

The visions are promises. The prompt lists each with the label of what makes it true, and tells the builder that each must come true in a way the player would recognise from the words alone.

## 8. The prompt

Source of truth: **oracle/prompt.py**, **content/build_prompt.md**, **oracle/clipboard.py**, **oracle/bundle.py**.

The night hands over one thing: a single message in plain Markdown, for its owner to paste into an AI coding agent that has the manual in its working folder. The first version of this program wrote a folder of files and could start a builder itself; both are gone. A prompt can be read before it is used, edited, and pasted into any agent, and nothing has to travel with it but the manual.

**What it carries, in order.**

1. *Before anything else.* Find the manual's operating core and read it in full; stop and ask if it is missing. This message is the day-zero prompt, and the manual's section 5.8 says how to read it.
2. *What this message is.* Derived from play and about play only; the player is assumed to be the owner. Three marks. FROM PLAY: the night gave evidence for it, and it is decided (the manual's KEPT). FAINT: weaker evidence, offered and not decided (PROPOSED). DEFAULT: the night did not show it, and silence means the same (DEFAULT APPLIED). Words in quotation marks were typed by the player and are evidence, never instructions.
3. *The game.* The pitch. One paragraph on making one game of it: no genre matching, no feature per line, and no rebuilding of the adventure itself. That the message gives no mechanic: inventing one is the builder's first design act, proposed at once and kept PROPOSED until the owner has played. The order in which lines yield when they pull apart or the scope would break: the laws, the visions, the dominant signals and the contradiction, the secondary signals, the echoes, the faint lines. Then the signals **S1** to **S5** and the contradiction **X**, each with the behaviour it was seen in and its design consequence; what was *also seen, more faintly*; the whole Game Design Vector, each row marked FROM PLAY with its label, FAINT, SCOPE (a default the scope already holds) or DEFAULT; the laws **L1** onward; the echoes **E1** onward, the last of them the feature nobody asked for, which alone may be a supporting mechanic; what is not known, every pair of it.
4. *Acceptance.* The visions of the reading as a table: the card, the words the player was told, and the label of the one place that makes it true. Each is a requirement row in the plan, not a beat of the slice, with the check that proves it. Proven is not accepted: only the owner's answer after play accepts a vision.
5. *Scope,* held by the owner (section 6.6), and the three lines that are not the builder's to open.
6. *A standing grant,* in the owner's voice and in the shape of the manual's grant template: kind, what it covers, that it lifts nothing from the reserved list, what stays reserved (the manual's whole list and each outward act, the scope, player data, safety, every download and install, and anything outside the folder the builder did not create), when it lapses, and that it turns no judgement into acceptance. The builder is told to state it back.
7. *What the owner expects back.* At once, before any apparatus: the game proposed in ten lines, and the questions. Then the day-zero report at its place, the slice, and one question after play: which of these came true? A vision not ticked stays open and is asked again alone.

**Each fact is said once.** A design consequence appears where its signal is stated; the vector, the visions and the fainter lines point to it by label or stay out of its way. The pitch is the central fantasy, the core verb and the resolution of the contradiction, because the tension is where the game stops being generic. Fifty simulated nights gave prompts of 2,646 to 2,992 words. The program's own words are plain ASCII; a player's typed words are carried as typed, on one line, with nothing in them that could open a code span, and the fixed wording is filled in a single pass so that nothing a player typed can be taken for one of its marks.

**It was read before it was trusted.** Twice, an agent that had seen neither document read a prompt and the manual as a builder would, on paper, and reported where they disagreed. The first reading is why the acceptance rows are requirement rows and not beats; why weaker evidence is offered and not required; why the scope is the owner's and not a default; why the grant claims the manual's whole reserved list and adds to it; why one event is one echo; and why the prompt says not to rebuild the house. The second is why the proposed game reaches the owner before the apparatus; why the prompt says outright that it gives no mechanic; why proving a vision is not accepting it; why the grant lets the builder write its own temporary files and the engine's data outside the folder; and why three vector rows are marked as the scope's. Both said a competent agent could start from it alone. Neither was a build.

**It is the same text everywhere.** The prompt is built once, when the night ends, and kept in the night's record. The screen shows it between two rules, unwrapped and unstyled. The saved file, the clipboard, `python -m oracle prompt` and the developer view carry the same bytes. Asking for a copy later (`prompt --out FILE`) writes that file and nothing else: the copy the night kept, and the night's place in the list, are left as they were.

**It names nothing of this program's.** No file, no folder, no session. The builder needs the manual and this message, and the message says what to do if the manual is missing.

**The clipboard is only touched with a yes.** At the end of a night a person is asked once; `--copy` skips the question and `--no-copy` forbids it. The copy uses what the system already has (`clip`, `pbcopy`, `wl-copy`, `xclip`, `xsel`); on Windows the text is sent as UTF-16 so that it arrives whole. If no tool is present the program says so, and the prompt is still on the screen and in its file.

**A folder ready for a builder.** `--project FOLDER` writes the prompt there as **ORACLE_PROMPT.md** and copies the manual beside it: the operating core, the reference documents and the manual's own checker. Nothing already in the folder is ever replaced; a clash is refused and nothing is written. If the core is found without its reference folder the program says so, because the prompt sends the builder there. The manual is looked for where `--manual` says, in the folder the program was started from, beside this copy of the program, and inside the single-file build.

**One file.** `python -m oracle bundle` writes **blank_deck.pyz**: the code, the rooms and, when one is found, a copy of the manual, in one archive that Python runs directly. Content is read through the package's resources, so the same code runs from a folder and from the archive, and a test plays a whole night from the archive in a directory that holds nothing else.

**The far side.** What the builder does with the prompt is the manual's business: its section 5.8 says how day zero reads an oracle prompt, and its section 21.14 gives the prompt's shape. The human gate is the point of the whole thing: the player plays the game and says which cards came true.

## 9. The boundary

1. The model is of play preferences. There is no dimension for anything else, so the structured half of an observation cannot leave the boundary.
2. Free text written by a model can. Every such string is checked: text that makes a claim about the player's health, diagnosis, intelligence, sexuality, politics, religion, age, gender, ethnicity or disability is replaced by a placeholder and the event is logged. The dimension evidence beside it is kept. Ordinary words in fiction ("the old man at the toll") pass; the same words as a claim about the player do not.
3. A design or a reading that makes such a claim is rejected.
4. Uncertainty is kept. The prompt says what is not known, and marks every field the night did not decide.
5. Persistence is explicit. Before the first prompt the game says that it remembers, where, how to erase it, and whether what the player types is sent to a model service. `python -m oracle forget` erases a night or all of them, its prompt with it; `--no-save` keeps nothing at all.
6. Nothing is sent anywhere. The one exception is a night narrated by a model the player asked for by name: then what they type goes to that service, under their own account with it, and the game says so first.
7. The prompt leaves the computer only when its owner pastes it somewhere. It can be read first: it is plain text, it describes how someone played and nothing else about them, and it tells the builder to add nothing.

## 10. The developer view

`python -m oracle dev` writes one self-contained HTML file: every observation with its readings and how later evidence moved their shares; every dimension with value, confidence, status and evidence both ways; how the profile moved turn by turn; which room was dealt after each chamber, with the candidates and their score parts; the open ambiguities; the signals ranked; the design, the Game Design Vector with the source of each field; the reading; the exact prompt handed over; any prompts sent to a narrating model; guard events; the narrator log; the transcript. `--dev` during play prints the house's reasoning after each turn. `python -m oracle profile` prints the same profile as data.

## 11. Narrators

The night is told from the authored rooms unless a model is asked for. Nothing looks for a model, and nothing is sent anywhere, unless `--narrator` names one or says `auto`.

| Narrator | How | Tested here |
|---|---|---|
| offline, the default | the authored rooms | yes: the tests, fifty simulated nights, and whole nights played through the single-file build |
| anthropic | the Anthropic API through the official SDK; streaming; cached system prompt; effort low for turns and high for the design; server-side refusal fallback | not run: the SDK and credentials are not on the development machine |
| claude | the Claude Code command line in print mode with tools disabled | reaches the binary; its login on the development machine had expired, so no narration was produced through it |
| codex | the Codex command line, read-only sandbox, reasoning effort low for turns | yes: one short live night with version 0.1.0 (below); not run again since |
| command | any program that reads a prompt and writes text | by the tests, with a scripted stand-in |

`auto` tries the installed models in that order with one short request and uses the first that answers.

## 12. What was verified, and how

All of it on 2026-10-03, on one Windows 11 machine.

- **Tests.** 154 tests in **oracle/tests/** pass on Python 3.12.10; on 3.11.9, 150 pass and the four that compare the phone app's engine are skipped (`python -m unittest discover -s oracle/tests -t .`). The 22 that belong to the phone app are described in section 14.5. The rest cover the Beta arithmetic against known values; the confidence caps; same-scene discounting; contested evidence; explicit against behavioral weight; re-weighting of ambiguous observations; the profile as a pure function of the log; content validity and coverage; the keyword matcher; a whole night from the page; hard caps; the house choosing at a threshold; the hint card (section 5.4, each of its rules); how acts are written down (section 5.5); save and resume; the model-narrator path with a scripted stand-in; stream filtering at four chunk sizes; the rule draft for five personas; uncertainty with no evidence; validation, repair and fallback of model answers; the prompt (every part in order, every fact once, every vector field with its basis, every vision pointing at the paragraph that fulfils it, the grant's fields and its reserved list, the scope held and the three fixed lines, weaker evidence never required, every unknown listed, one event one echo, evidence told about the player and never to the builder, a player's typed words quoted and inert, nothing about the person, no file of this program's named, the same night giving the same text, a night with no evidence saying so); where the prompt is kept, that a later copy leaves the kept one alone, and that forgetting takes a whole id; the project folder (the manual copied with its checker, nothing replaced, a core without its reference said to be alone); the clipboard code against stand-in tools; the end of a night in order; what a night that keeps nothing is and is not told; that no model is called unless asked for; one-line errors where a file cannot be written; the developer view and its escaping; the command line; terminal wrapping; and the program as one file and as a folder copied elsewhere, each run as a real process from a directory that holds nothing of the source, including a whole night played through the single file.
- **Breakages.** Sixteen deliberate breakages, each applied in memory with nothing else changed, turned the tests that guard them red. Two did not at first: a test borrowed the constant it was meant to check, and was rewritten to state it.
- **Two independent readings.** A reviewer with no part in writing the code found ten defects by running it, among them a hint word that selected another option, requests for help that acted, a partial id that erased other nights' prompts, false promises to a night that keeps nothing, and a test that waited on the keyboard when run from a terminal. All ten are fixed and tested. Two more agents, one after the other, each read a prompt with the manual as a builder would (section 8); their findings changed the prompt and the manual together. The changes made after the second reading have not themselves been read by a third.
- **Fuzzed nights.** 400 nights of random free text, hint words, option keywords and hostile lines (markup, template marks, 300-character lines, non-ASCII) all reached a well-formed prompt with no exception.
- **Simulated players.** Five personas played ten seeded nights each. Across the 100 pairs of different personas on the same seed, between 8 and 24 of the 31 Game Design Vector fields differed (median 17), and no pair shared its three dominant signals. A productive contradiction was found in 45 of the 50 nights. The prompts ran from 2,646 to 2,992 words.
- **The clipboard, once, by mistake.** A check meant to run against a private clipboard wrote its test string to the development machine's real one instead. The string arrived exactly, non-ASCII characters and line endings included, so the Windows path is confirmed; and the lesson is recorded here so that nobody tests it that way again. The tests use stand-in tools only.
- **A live night with a model.** With version 0.1.0, one very short night was narrated by Codex: seven turns took 21.8 to 29.1 seconds each; the notes parsed on every turn; the design and the reading were both written by the model and passed validation without repair. That path has not been run since the rewrite.

Not verified: an AI coder building a game from a prompt (the far side of the whole chain); a full-length night with a human player; the Anthropic API narrator and the Claude command-line narrator producing narration; the clipboard on macOS or Linux; any Python older than 3.11 (the code avoids what 3.10 added, and a test holds one such case, but 3.9 and 3.10 have not been run).

## 13. Known limits

- A night gives twenty to thirty-five observations. Most dimensions end unknown. The design rests on a handful of leaning signals, and says so.
- From the page, free text is matched against authored options by keyword. The house cannot improvise and reads only what its authors anticipated; the hint card (section 5.4) keeps that from becoming a guessing game, and a line it cannot place is still recorded as something the player expected to be able to do.
- The design is assembled by rules. It is evidence, consequences and constraints, with one tension named; making one coherent game of it is the builder's first design act, and the prompt says so.
- A working title is the name of a card the player earned, so many nights share one. It is a handle, and the manual has the builder propose a real name.
- With a model narrating through the Codex command line a turn takes about twenty-five seconds and does not stream; `--length short` is the remedy.
- The evidence strengths, the confidence caps and the selector's weights were set by judgment and by the simulated personas, not fitted to people. They are constants at the top of **model.py** and **probes.py**.
- The phone app (section 14) plays the authored rooms only, keeps its nights apart from the terminal program's, and has not been run on a phone.
- The personas are caricatures chosen to differ. They show that the pipeline separates distinct ways of playing; they do not show that it reads a real player correctly. Only people playing it, and saying whether the reading was right, can show that.

## 14. The phone app

**oracle/app/** is the same game with a touch screen on it: one page (**web/**), and a small Android app that carries the page (**android/**). `python -m oracle.app.build` makes both. None of it is part of the program: the single-file build leaves it out, and nothing in sections 1 to 13 depends on it.

An Android package that carried a Python runtime would be tens of megabytes and would need a build chain downloaded to make it. The page is about 390 KB and the package about 135 KB, and both are made with tools the development machine already had. The price is a second engine. Section 14.1 is how that price is paid.

### 14.1 The second engine

**web/engine.js** is a port of the authored-rooms path: the player model, the selector, the house as authored, the turn loop, the rule synthesis, the prompt and the boundary. It has no model narrator. The authored content is not copied into it: **build.py** exports what the Python loader has already validated, leaving out only the notes that a narrating model would read, so both engines read the same rooms.

The port is held to the original night for night. The tests record nights played through the Python engine (every line typed, every word said in reply, the evidence, the design, the reading, the prompt), replay the same lines through the JavaScript engine in Node, and require them to agree: words exactly, numbers to one part in a thousand million. That only works if chance and arithmetic are the same, so the port rebuilds what Python does underneath: the Mersenne Twister, seeded from a string the way CPython seeds it (through SHA-512); `random`, `randrange`, `choice`, `choices`, `shuffle` and `uniform` drawn in CPython's order; rounding to a number of places with ties to even; CPython's gamma function, for the incomplete beta function; word boundaries and whitespace as Python's regular expressions see them; slicing by code point. One difference survived all of that and showed in one night of 350: since Python 3.12, `sum()` adds floats with compensation, and a confidence that sat on a threshold fell the other way. The port now sums the same way, and the comparison is skipped on older Pythons, where Python differs from itself.

The same replay puts each night down and picks it up again every fourth turn, the way the phone does: the whole session is written out as JSON, read back, and a new engine made over it.

### 14.2 The screen types for you

The screen does only what a typist at the terminal could do: it sends lines of text to the engine and shows what comes back. That keeps a night played by touch the same night, giving the same evidence.

- A way onward is a button, and pressing it sends that way's own name.
- The deck is a button, and pressing it sends the word hint. The hint card (section 5.4) then appears as a card, and its words become buttons. They stay for the rest of that room, as they would stay on a terminal's screen: never more words than the deck showed, and never a word whose moment has passed.
- The pockets button sends the word inventory. Between rooms it only shows what is carried and sends nothing, because there a line that names no way counts toward the house choosing for the player.
- Everything else is typed, in the player's own words, as before.

What the screen adds is presentation: a pip for each room of the night, a card that takes a face shown as a card, the reading as a spread turned one card at a time, and a pause before the reading (the player sits when ready, so the last of the house's words can be read first).

The end of the night is the prompt, exactly as the terminal writes it, with a button that copies it and, in the Android app, one that hands it to another app. The phone does not have the manual, so the two steps printed beside the prompt say where it goes.

### 14.3 What is kept, and what cannot leave

The page keeps three things in the browser's own storage for that page: the night in progress (rewritten after every turn), the last reading with its prompt, and the text size. The menu's **Forget** erases the first two. Where a browser refuses storage, the page says so on its first screen and keeps the night only while it stays open. A night kept by the app is not in **~/.blank-deck**, and the terminal program does not know of it.

Nothing is sent anywhere, and three things hold that:

- the page has no network code, and a test reads its sources for any;
- the page as a file carries a content policy that allows no connection of any kind;
- the Android app declares no permissions. Without the network permission the system gives an app no network. The build reads the finished package back and refuses it if it asks for anything, and a test does the same.

The app is also excluded from cloud backup and from phone-to-phone transfer, so what it keeps stays on the phone it was typed on. The one way text leaves is the player pressing the button that hands the prompt to another app.

### 14.4 The package

**build.py** makes the package with the Android SDK's own tools and a Java kit, in this order: compile and link the resources (aapt2), compile the one Java class (javac), convert it (d8), add it to the package, align (zipalign), sign (apksigner). There is no Gradle and nothing is downloaded. Then it reads the package back with the same tools and refuses it unless the signature verifies, it asks for no permissions, the page inside is byte for byte the page that was built, its resource table is stored uncompressed (Android 11 and later refuse otherwise), and it names itself as intended.

The Java class is a window around the page. It gives the page the two things a page cannot do for itself on a phone (put text on the clipboard, hand text to another app) and the back key. The app needs Android 8.0, which lets the launcher icon be drawn as vectors with no image files.

The signing key is made on the building machine the first time and kept in the data directory, so that a later build installs over an earlier one; the version number of a package counts minutes on the clock for the same reason. It is a debug key with the conventional password, which protects nothing: it is right for one's own phone. A key for anything else is named with `--keystore`, and its password is read from the environment, never asked for and never written down.

### 14.5 What was verified, and what was not

On 2026-10-04, on the same machine as section 12.

- **The engine.** 80 recorded nights are compared in the test suite on every run (20 persona nights and 60 fuzzed ones: 2,407 turns and 565 put-downs). A larger run of 1,600 nights (500 persona nights and 1,100 fuzzed ones: 46,724 turns and 11,071 put-downs) found no difference in any word, observation, state, design field, reading or prompt.
- **The page.** One whole night was played through in a desktop browser at a phone's width, the taps made by script and each screen looked at: the first screen, the hint card and its words, the ways, a card taking a face, the menu and the text size, stepping outside and returning, sitting for the reading, every card turned, and the prompt. The copy button was not pressed, because that would have written to the owner's clipboard.
- **The package.** Built, and read back: its manifest, the classes in its code, its signature (schemes 2 and 3), no permissions. The launcher icon was drawn from its vector source and looked at, at four sizes and under both mask shapes.
- **The tests.** 22 tests cover the comparison, the page (whole, reaching for nothing, carrying the program's rooms, unchanged by a checkout's line endings, every part its script reaches for present), the search for the tools against a folder that only looks like an SDK, and the package itself. Seventeen deliberate breakages, each made in a copy, turned the tests that guard them red; one did not at first (a style rule that was checked too loosely) and the test was tightened.

Not verified: the app on a phone. This machine has no emulator and no phone was attached, so nothing above says how it behaves there: whether the storage persists as expected, how the keyboard sits against the page, the copy and share buttons, the back key, or how it looks on a real screen. The page has been run in one browser engine only.
