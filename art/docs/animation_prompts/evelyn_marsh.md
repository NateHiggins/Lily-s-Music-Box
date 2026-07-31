# Evelyn Marsh — 1A — animation prompts

Expanded, performance-ready prompts. Ten clips: the shared seven written *as
Evelyn* rather than with a signature slot, then her three.

This is the template for the other seventeen. If a prompt here could be
handed to Teresa or Mae without anyone noticing, it has failed.

## Who is moving

A retired schoolteacher in her late sixties. Thirty years of standing in
front of a room have left the posture in her: spine long, shoulders back and
level, chin parallel to the floor. She is not stiff — she is *composed*, and
the difference matters, because composure is something a body maintains.

**Her wound is that care and control became the same reflex and it never
switches off.** She corrects things. Papers, hems, the position of a cup, a
sentence someone else is still saying. It is affection expressed as
correction, and she cannot tell the two apart any more. Her case ends at
*good enough can hold* — the first time she leaves something wrong on
purpose.

**Physical brief**, from `resident_animation_profiles.json`:

| parameter | value | what it means for the animator |
|---|---|---|
| sway | 0.35 | low — very little lateral hip motion |
| glance | 0.55 | moderate — she looks *at* things, does not scan |
| hand | 1.65 | **high — her hands are the performance** |
| posture | −0.15 | slightly back, upright, chest open |
| stride | 0.72 | short, measured steps |
| lift | 0.55 | modest foot clearance |
| bounce | 0.45 | low — almost no vertical travel |
| arm | 0.42 | restrained arm swing, elbows close |

The single most important number is **hand 1.65**. Everything expressive
about her happens between the wrist and the fingertips. If a generated clip
puts the expression in her shoulders or her hips, reject it.

---

## The shared seven, as Evelyn

### `idle` — 2.7 s, seamless loop

A woman in her late sixties stands at rest, but rest for her is still a
taught posture: the spine stays long, the shoulders sit back and level, the
chin stays parallel to the floor. Her weight settles onto the left hip and
stays there. Her hands find each other low in front of her at waist height,
and the right thumb slowly smooths back and forth across the knuckles of the
left. Every few seconds the weight transfers to the other hip in one small
controlled movement — no roll, no slump — and the breath stays quiet and
even. Seamless loop.

### `walk` — 1.1 s, cyclic in place

She walks in short measured steps, the heel landing first and the foot
rolling through cleanly, as though the floor is being crossed on purpose
rather than merely travelled. The spine stays vertical and the head stays
level; she does not look down at her feet. The arms swing very little and
stay close to the body, elbows soft, and the fingers of the right hand keep
a slight curl as if carrying something that is not there. Almost no vertical
bounce. Cyclic in place, feet planting cleanly.

### `notice` — 1.5 s, one-shot

Her head turns first, cleanly and without any startle, the way a teacher
registers a raised hand at the back of a room she is already in command of.
The chin leads, the eyes arrive, and only then do the shoulders rotate to
square up with what she has found. As the shoulders come round, her hands
meet in front of her at waist height and hold there. The whole movement is
unhurried and finishes completely still.

### `converse` — 2.7 s, seamless loop

She listens standing, hands clasped low in front of her, head tilted a few
degrees to one side and held at that angle. Once in the loop the right hand
releases from the clasp, rises to just below chest height, and makes one
small precise turn of the wrist — a point being *placed* rather than argued
— before returning to the clasp. Her nods are small, slow and infrequent,
arriving a beat after the other person rather than on it. The weight shifts
once, hip to hip, without disturbing the spine. Seamless loop.

### `strained` — 2.7 s, seamless loop

She holds herself too upright and too still, the shoulders drawn up toward
the ears and the breath gone shallow and high in the chest. The stillness
does not reach her hands. The fingers of the right hand tap a small
repeating correction against her thigh — four beats and a pause, four beats
and a pause — and between rounds the left hand smooths the same short
stretch of sleeve over and over, flattening a crease that keeps coming back.
Her chin stays level and her eyes do not wander. Seamless loop.

### `recognition` — 3 s, one-shot

Her right hand is already rising to correct something when she stops it —
dead, mid-air, at about chest height. She holds it there a long beat, longer
than is comfortable to watch, the whole body locked around the unfinished
gesture. Then it releases from the top down: the shoulders drop and widen,
the raised hand opens and the fingers loosen, the chin comes up, and she
exhales fully through the mouth for the first time. The hand lowers to her
side and stays open.

### `settled` — 2.7 s, seamless loop

She stands with her hands resting apart rather than clasped — one at her
side, one loose against her thigh — shoulders low and level, spine tall
without effort. The breath is slow and deep, moving the belly rather than
the chest. Once in the loop her right hand starts to lift toward something
in front of her, the old correcting reflex beginning, and then simply does
not complete: the hand stops after an inch or two and settles back down. She
looks about the room easily, without scanning. Seamless loop.

---

## Her three

### `marking` — 3.3 s, seamless loop — *occupation*

She sits with an invisible sheet of paper held up in her left hand at chest
height, close enough to read without leaning toward it. Before each mark she
squares the page — a short firm tap of its bottom edge against her knee —
then brings the right hand across and makes two or three short decisive
strokes, wrist-led, each landing with a little extra pressure at the end.
Her head makes tiny corrections to follow the line down the page. She never
pauses to consider; the strokes come quickly and land exactly where she
intends. Seamless loop.

### `straightening` — 2.7 s, seamless loop — *compulsion*

Standing, she reaches out to something in front of her at waist height and
adjusts it by a fraction of an inch, thumb and forefinger, wrist-led, the
arm barely moving. She withdraws the hand almost back to her side, looks at
the result, and reaches straight back in to move it a fraction the other
way. The corrections get smaller each time round the loop and never resolve
into satisfaction. Her shoulders stay square and her feet do not move.
Seamless loop.

### `enough` — 3.7 s, one-shot — *break*

Her hand comes up to make one more correction, exactly as it has a hundred
times before, and stops halfway — the arm still extended, the fingers still
shaped for the task, everything held. She stays in that unfinished position
long enough for it to become uncomfortable to watch. Then, deliberately and
without hurry, she lowers the arm all the way to her side, opens the
fingers, and lets the hand hang. She does not look back at what she has left
uncorrected.

---

## What to reject

Generators will produce plausible motion that is not *her*. Send it back if:

- **The expression is in her shoulders or hips.** Hand is 1.65 and sway is
  0.35; she performs with her hands and holds the rest still.
- **She slumps.** Even exhausted, even at rest, the spine stays long. She
  has never once let her shoulders round in front of anyone.
- **She scans the room nervously.** Glance is 0.55 — she looks *at* one
  thing, decisively, then at the next. Darting eyes belong to Peter Wren.
- **Her hands go idle.** In every clip except `settled`, her hands are doing
  something, even if it is only holding each other.
- **The walk bounces or the stride opens up.** Bounce 0.45, stride 0.72:
  short, level, contained. She is not striding anywhere.
- **`enough` resolves comfortably.** The held beat has to be too long. If it
  reads as a smooth considered decision rather than as something breaking,
  the clip has missed the whole point of her arc.

## Notes for the runtime

`idle` and `walk` are the only two `AnimatedResident` currently selects, so
generate those first and judge the character off them. `strained` swaps in
while her case is active or reopened; `recognition` and `enough` are the
same beat from two directions and should be generated together and blended.
