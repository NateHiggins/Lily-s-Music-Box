# Character animation prompts

Text-to-animation prompts for the eighteen residents. One reference sheet:
seven clips everybody needs, then three that only they could perform.

## How to use this

**Prompt conventions.** These are written for text-to-motion tools (Meshy,
Cascadeur AI, Motorica and similar), which respond to body-level description
and ignore everything else. So:

- Describe **what the body does**, never what the camera sees, the room
  contains, or the character feels. "Shoulders climb toward the ears" works;
  "anxious" does not.
- Name the **limb, the direction, and the tempo**. Tools resolve "raises the
  left hand slowly to chest height" and guess at "gestures".
- Say **loop** or **one-shot** explicitly. Anything a character does while
  you are standing there watching has to loop invisibly.
- Keep one clip to **one idea**. Two ideas produce a blend of both, badly.
- Everything here is **standing or seated on the spot**. Root motion fights
  the navigation, and the existing rig contract has walk as a cyclic
  in-place loop with IK feet.

**Lengths are in seconds**, because that is what text-to-motion tools ask
for. They still match the rig contract in
`game/docs/resident_character_cast.md`, which is authored in frames at
30 fps — idles 2.7 s (80 frames), the walk cycle 1.1 s (32 frames). Loops
below run 2.7–3.3 s and one-shots 1.5–4 s.

Treat these as targets rather than exact figures: what a loop actually needs
is to close cleanly on itself, and a generator that returns 3.1 s of
seamless idle has done the job better than one that returns 2.7 s with a
visible seam. The frame count is what has to line up on import, not the
duration.

**Every shared clip is performed in that character's motion signature.** The
signature is already parameterised per resident in
`game/data/resident_animation_profiles.json` (sway, glance, hand amplitude,
posture, stride, foot lift, bounce, arm counter-swing). Where a prompt says
*[signature]*, paste that resident's one-line trait from the table below —
it is what stops eighteen people sharing one performance.

**Where the unique clips come from.** Each resident's three are derived from
their case in `game/data/reality_cases.json` — the manifestation, the
resolution flags, the portal rule — and from the poltergeist built on that
wound in `game/scripts/reality/poltergeist_library.gd`. They are not
decoration. `occupation` is what their hands do for a living, `compulsion`
is the wound running unattended, and `break` is the moment it shows. The
game reaches for `compulsion` when a case is active or reopened and for
`break` at the recognition beat.

---

## The shared set

Seven clips, eighteen times, each inflected by *[signature]*.

| id | length | prompt |
|---|---|---|
| `idle` | 2.7 s loop | A person standing at rest, weight settled on one hip, breathing evenly, with small involuntary weight shifts. *[signature]* Seamless loop. |
| `walk` | 1.1 s cyclic | A person walking forward at an unhurried domestic pace, arms counter-swinging naturally. *[signature]* Cyclic in place, feet planting cleanly. |
| `notice` | 1.5 s one-shot | A person turns their head toward something to one side, then brings their shoulders around to follow it, settling into a squared, attentive stance. *[signature]* |
| `converse` | 2.7 s loop | A person listening while standing, weight shifting occasionally between feet, head tilting slightly, one hand rising to a small unemphatic gesture and lowering again. *[signature]* Seamless loop. |
| `strained` | 2.7 s loop | A person standing while holding themselves too still, shoulders raised toward the ears, breathing shallow and high in the chest, one hand closing and opening at their side. *[signature]* Seamless loop. |
| `recognition` | 3 s one-shot | A person stops moving entirely for a beat, then their shoulders drop, their head comes up, and they exhale fully for the first time. One hand opens, palm loosening. |
| `settled` | 2.7 s loop | A person standing at genuine ease, shoulders low and level, breathing slow and deep into the belly, occasionally looking around without scanning. *[signature]* Seamless loop. |

---

## Per resident

### Evelyn Marsh — 1A
*Signature:* corrects invisible papers; walks with controlled teacherly precision.
*Wound:* care and control became the same reflex, and it never switches off.

| id | length | prompt |
|---|---|---|
| `marking` | 3.3 s loop | A seated person holds an invisible sheet of paper in the left hand and makes short decisive correction strokes across it with the right, pausing to square the page against their knee before each stroke. Seamless loop. |
| `straightening` | 2.7 s loop | A standing person repeatedly reaches out to adjust something in front of them by a fraction, withdraws the hand, then reaches back to adjust it again the other way, never satisfied. Small movements, wrist-led. Seamless loop. |
| `enough` | 3.7 s one-shot | A person raises a hand to make one more correction, stops it halfway, holds the hand still in the air for a long beat, then lowers it deliberately to their side and leaves it there. |

### Teresa Vale — 1D
*Signature:* exhausted triage posture; careful steps anticipating another alarm.
*Wound:* she rested once, and someone died, and the bell never stopped.

| id | length | prompt |
|---|---|---|
| `bracing` | 2.7 s loop | A standing person with weight forward on the balls of the feet, head angled as if listening past the room, one hand resting on the opposite forearm ready to move. Seamless loop. |
| `false_alarm` | 2.3 s one-shot | A person snaps upright from stillness, takes two fast half-steps toward something, then stops abruptly, shoulders dropping as the urgency drains out of them. |
| `sitting_down` | 4 s one-shot | A person lowers themselves to sit, stops halfway with the hands still braced on their thighs, holds there in the unfinished position, then completes the sit slowly and lets the head tip back. |

### Mina Vale — 2A
*Signature:* furtive glances and captioning gestures; paces quickly when self-conscious.
*Wound:* everything she is must be annotated, or it does not count.

| id | length | prompt |
|---|---|---|
| `transcribing` | 3.3 s loop | A seated person types rapidly with both hands on an invisible stenotype at waist height, eyes fixed forward and unblinking, head making tiny stabilising corrections. Seamless loop. |
| `annotating` | 3 s loop | A standing person points briefly at something to their left, mouths a short word, points at something to their right, mouths another, then repeats with the fingers slightly tighter each time. Seamless loop. |
| `blank_page` | 3.7 s one-shot | A person raises both hands ready to type, holds them poised in the air over nothing, waits far longer than is comfortable, then lowers them into their lap and leaves them open and empty. |

### Lena Ortiz — 2B
*Signature:* continually stitches and mends; weighted walk suggesting she carries everyone else.
*Wound:* she is loved for being useful, so she must never stop mending.

| id | length | prompt |
|---|---|---|
| `stitching` | 3.3 s loop | A seated person draws a needle through fabric held taut between both hands, pulling the thread out to full arm's length on each stitch, working faster than is comfortable. Seamless loop. |
| `mending_air` | 2.7 s loop | A standing person makes small stitching motions in the air in front of their chest with nothing in their hands, thumb and forefinger pinched, the elbow tucked in tight. Seamless loop. |
| `showing_the_seam` | 3.3 s one-shot | A person holds up an invisible garment at arm's length, turns it to show one side, hesitates, then deliberately turns it back to show the mended side outward and holds it there. |

### Juno Kells — 2C
*Signature:* keeps an internal beat through asymmetric hands and a syncopated, bouncing stride.
*Wound:* her work was taken, so she takes, and calls it collaboration.

| id | length | prompt |
|---|---|---|
| `beatkeeping` | 3 s loop | A standing person keeps two different rhythms at once, tapping a fast pattern against their thigh with the right hand while the left hand marks a slower count in the air. Head nods to the slower one. Seamless loop. |
| `sampling` | 2.7 s loop | A person leans in toward something at head height, holds absolutely still with the head cocked to listen, then pulls back and makes a quick grabbing motion with one hand as if catching it. Seamless loop. |
| `handing_it_back` | 3.3 s one-shot | A person holds something small cupped in both hands close to the chest, looks down at it, then extends both arms fully forward and opens the hands flat, giving it away. |

### Malcolm Reed — 3A
*Signature:* tends an imaginary plant with gentle hands; walks as if rooted by grief.
*Wound:* he kept a cutting alive so the goodbye would not finish.

| id | length | prompt |
|---|---|---|
| `tending` | 3.3 s loop | A person crouched on one knee turns invisible leaves over between finger and thumb with great care, inspecting the underside of each before moving to the next. Seamless loop. |
| `listening_to_it` | 3 s loop | A standing person leans slowly toward something at chest height, turns their ear to it, holds there far too long, then straightens and repeats. Seamless loop. |
| `letting_go` | 4 s one-shot | A person holds cupped hands close to the chest, opens them slowly and tips them forward to pour something out onto the ground, then keeps looking down at their empty palms. |

### Omar Bell — 3B
*Signature:* checks an imaginary tool in each hand; places every step as though it may require repair.
*Wound:* if he cannot fix it, he failed it. There is no third option.

| id | length | prompt |
|---|---|---|
| `diagnosing` | 3.3 s loop | A person places one flat palm against a surface at chest height and holds it there, completely still, head turned away and eyes unfocused, feeling for vibration. The other hand hangs ready. Seamless loop. |
| `retightening` | 3 s loop | A kneeling person turns an invisible wrench in short repeated arcs, stops to test the joint with a shake, finds it still loose, and starts turning again. Seamless loop. |
| `declaring_it_dead` | 3.7 s one-shot | A person working on something with both hands slows, stops, sits back on their heels, sets the invisible tool down flat on the floor beside them, and wipes both palms on their thighs. |

### Rhea Sato — 3D
*Signature:* controlled singer's breathing that expands into performance-sized movement.
*Wound:* every involuntary sound she makes is evidence against her.

| id | length | prompt |
|---|---|---|
| `warming_up` | 3.3 s loop | A standing person breathes deliberately with one hand flat on the diaphragm and the other extended forward, the extended arm rising and opening with each inhale and settling on each exhale. Seamless loop. |
| `swallowing_it` | 2.7 s loop | A person begins an expansive open-chested gesture, catches themselves partway, and folds the arm back down across the body, shoulders rounding. Repeats, each time catching it earlier. Seamless loop. |
| `letting_it_crack` | 3.7 s one-shot | A person stands squared and opens both arms wide from the chest, holds the open position through a visible flinch, and does not close them. |

### Peter Wren — 4A
*Signature:* straightens invisible forms, scans nervously, advances in small uncertain steps.
*Wound:* he was brave once, imperfectly, and has been filing about it since.

| id | length | prompt |
|---|---|---|
| `squaring_forms` | 3 s loop | A standing person taps the bottom edge of an invisible stack of papers against a surface to align it, turns the stack ninety degrees, taps again, and repeats indefinitely. Seamless loop. |
| `not_deciding` | 3.3 s loop | A person half-raises one hand to reach forward, stops, lowers it, shifts their weight to the other foot, half-raises the other hand, stops, lowers it. Seamless loop. |
| `proceeding_anyway` | 3.3 s one-shot | A person hesitates with one hand half-raised, then commits: the hand goes forward and through, the shoulders follow, and they take one full step without checking behind. |

### Cam Ortiz — 4C
*Signature:* never becomes fully still; fast courier stride, high feet, restless bounce.
*Wound:* if he stops moving the crash catches up, so he never stops.

| id | length | prompt |
|---|---|---|
| `never_still` | 2.7 s loop | A standing person shifts weight constantly foot to foot, rolls one shoulder, bounces lightly at the knees, and never holds any position longer than a moment. Seamless loop. |
| `checking_the_road` | 2.3 s loop | A person snaps a look sharply over the left shoulder, faces front, snaps a look over the right, faces front, the head movement faster than the body follows. Seamless loop. |
| `putting_it_down` | 4 s one-shot | A person moving restlessly slows, plants both feet flat and level, lets the shoulders drop, and stands completely still — visibly holding the stillness rather than resting in it. |

### Noel Price — 4C
*Signature:* museum-handler stillness, precise hands, artifact-safe measured steps.
*Wound:* he preserved his family so carefully that nobody may touch it.

| id | length | prompt |
|---|---|---|
| `handling` | 3.3 s loop | A person lifts an invisible object with both hands from underneath, never gripping it, rotates it slowly to inspect one face, and sets it down exactly where it was. Seamless loop. |
| `warding_off` | 2.7 s loop | A standing person extends one flat palm forward at waist height in a small restraining gesture, holds it, withdraws it, then extends it again slightly higher. Seamless loop. |
| `using_it` | 3.7 s one-shot | A person lifts an invisible object with the careful two-handed grip, pauses, then changes to an ordinary one-handed hold and uses it casually — the careful posture dropping out of the body. |

### Transient Guests — 4D
*Signature:* sways with jet lag; walks hesitantly as though the assigned room keeps changing.
*Wound:* leaving forever is how they avoid ever deciding to leave.

| id | length | prompt |
|---|---|---|
| `half_packed` | 3.3 s loop | A crouched person puts an item into an invisible bag, pauses, takes it back out, holds it undecided, and puts it in again. Seamless loop. |
| `checking_the_number` | 2.7 s loop | A standing person looks up at something above head height, looks down at their own hand, looks up again, and shakes their head fractionally. Seamless loop. |
| `staying` | 3.7 s one-shot | A person standing with a bag strap held in one hand slowly lets the strap slide out of the fingers, lowers the empty hand, and takes one step further into the room rather than toward the door. |

### Nadia Quell — 5A
*Signature:* drafts square angles in the air; walks in sharply controlled, code-compliant lines.
*Wound:* she was made to sign off on something she knew was unsafe.

| id | length | prompt |
|---|---|---|
| `drafting` | 3 s loop | A standing person draws precise right angles in the air in front of the chest with a flat vertical hand, each stroke stopping cleanly, then squares the corner and starts the next. Seamless loop. |
| `measuring_the_exit` | 3 s loop | A person paces off a distance with deliberate heel-to-toe steps, stops, turns exactly ninety degrees, looks back along the line they walked, and starts again. Seamless loop. |
| `refusing_to_sign` | 3.3 s one-shot | A person brings a hand down to sign something, stops with the hand flat on the surface, holds it, then draws the hand back and closes it into a fist on the thigh. |

### Cal Dwyer — 5B
*Signature:* cocks his head toward unheard broadcasts; body moves half a beat late.
*Wound:* he tuned a moment so finely that it can never be allowed to end.

| id | length | prompt |
|---|---|---|
| `tuning` | 3.3 s loop | A seated person turns a small dial between finger and thumb in tiny increments, freezing completely between each adjustment with the head cocked, then adjusting again. Seamless loop. |
| `half_beat_late` | 2.7 s loop | A standing person's head turns toward something, and the shoulders and torso follow noticeably after a delay, as though catching up. Repeats to alternate sides. Seamless loop. |
| `letting_it_end` | 4 s one-shot | A person holds a dial pinched between finger and thumb, holds the position a long time, then opens the fingers and lets the hand fall away without turning it. |

### Iris Bell — 5C
*Signature:* paints broadly in the air; walks with an expressive, colour-seeking lateral sway.
*Wound:* an imagined audience holds the brush, and it is never satisfied.

| id | length | prompt |
|---|---|---|
| `painting` | 3.3 s loop | A standing person makes broad committed brush strokes in the air from the shoulder, stepping back after every third stroke to look, then moving in again. Seamless loop. |
| `checking_for_watchers` | 2.7 s loop | A person mid-gesture stops, glances quickly behind over one shoulder, returns to the gesture smaller and more careful than before, then glances again. Seamless loop. |
| `painting_badly_on_purpose` | 3.7 s one-shot | A person makes one deliberately loose careless sweep of the arm, holds still as if braced for a reaction, then makes another, looser, without bracing. |

### Sacha Reed — 6A
*Signature:* camera-steady hands, scans for evidence, purposeful witness momentum.
*Wound:* nothing that happened to them counts until it is documented.

| id | length | prompt |
|---|---|---|
| `recording` | 3 s loop | A standing person holds an invisible camera steady at eye level with both elbows tucked, panning slowly and smoothly across a scene, the whole upper body moving as one unit. Seamless loop. |
| `restaging` | 3 s loop | A person gestures at something to reset it, backs up two steps to their previous position, raises the camera again, then lowers it and repeats the reset. Seamless loop. |
| `putting_the_camera_down` | 3.7 s one-shot | A person lowers an invisible camera from their eye, holds it at chest height, then sets it down and lets both hands hang empty while continuing to look at what they were filming. |

### Jonah Price — 6B
*Signature:* writes, pauses, and loses the next word; even his walk feels softly interrupted.
*Wound:* he cannot write the ending, so the ending has started biting.

| id | length | prompt |
|---|---|---|
| `writing` | 3.3 s loop | A seated person writes quickly across an invisible page, stops mid-stroke with the hand still down, waits, lifts the hand, and starts a new line from the left. Seamless loop. |
| `losing_it` | 2.7 s loop | A standing person begins a small explanatory gesture with one hand, loses it partway, opens and closes the hand once as if reaching for the word, and lets the arm drop. Seamless loop. |
| `finishing_the_sentence` | 3.7 s one-shot | A person writes, reaches the usual stopping point, hesitates, then makes one short final stroke and sets the hand flat on the page. |

### Mae Kessler — 6C
*Signature:* handles invisible archives defensively; walks with exact provenance-conscious care.
*Wound:* two true versions of her family cannot both be survivable.

| id | length | prompt |
|---|---|---|
| `cataloguing` | 3.3 s loop | A standing person turns an invisible object over in gloved hands, checks the underside, then reaches out to write on a tag with the object still balanced in the other hand. Seamless loop. |
| `two_accounts` | 3 s loop | A person holds one hand out flat to the left, then the other flat to the right, looking between the two, raising and lowering them alternately as if weighing them and never settling. Seamless loop. |
| `holding_both` | 3.7 s one-shot | A person weighing two things in separate hands stops, brings both hands together in front of the chest without merging them, and holds both, looking straight ahead. |

---

## Production order

Generate in this order — it front-loads what the game can already use.

1. **`idle` and `walk` for all eighteen.** These are the only two the runtime
   currently selects (`AnimatedResident` picks clips by `idle` and `walk`
   suffix), so everything else is inert until the case-interaction contract
   is extended to ask for it.
2. **`converse` and `notice` for the six heroes** — Mina, Juno, Omar, Rhea,
   Nadia, Sacha. They are the ones the case network puts you in a room with.
3. **Mina's full set**, because her case is the one that is playable end to
   end and is the template for the rest.
4. **`compulsion` and `strained` for whichever resident's case ships next.**
5. Everything else, per resident, as their case comes online.

## Notes

- The three unique clips per resident are deliberately *not* interchangeable.
  If two of them could be swapped between characters without anyone
  noticing, the wound is not in the body yet and the prompt needs redoing.
- `recognition` and each resident's `break` are the same dramatic beat from
  two directions: `recognition` is the shared shape of the release, `break`
  is what it costs that specific person. Generate both; blend at runtime.
- Nothing here needs facial animation. The rig contract has none, and every
  prompt above is written to read from across a corridor.
