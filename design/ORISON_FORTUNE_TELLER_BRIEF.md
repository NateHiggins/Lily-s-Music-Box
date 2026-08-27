# A11 — THE HOUSE HEARD “BIG”

Status: focused prototype complete; **not placed and not campaign-active**.
The retired F01 wall is proved clear, but production still requires the live,
route, render and persistence gates below. Empty wall remains the control.

## The object

One compact 1927 coin-controlled answering head, mechanically grounded in John
J. Scharli Jr., US 1,621,756 (filed 20 June 1925, granted 22 March 1927). A coin
falls into one of two troughs; its weight closes a leaf switch, one of two
electromagnets positions a common striker, and a hand plunger drives the chosen
pendulum so the head nods or shakes. The striker then returns to neutral. The
machine does not parse speech, know a question or predict anything. Its
ordinary electrical and mechanical truth must be demonstrated before the
impossible event.

Working title: **THE HOUSE ANSWERS YES / NO**. Do not reproduce Zoltar's name,
cabinet, face, costume, typography, speech or fortune card. Avoid an ethnicized
“mystic” caricature; use an anonymous pressed-metal civic head, exposed coin
race, YES/NO enamel windows and Orison/Vantry service vocabulary.

Alternate primary mechanism: Mills Novelty Co., US 1,586,455 (1926), rotating
legend wheels combined with vending. Use only if the nodding head proves
visually unreadable.

## Why BIG is useful

Penny Marshall's *Big* (1988) supplies a legible four-beat folk structure:

1. an old public machine accepts a private wish;
2. the impossible answer arrives after the player leaves;
3. apparent empowerment becomes an adult burden;
4. returning to the same machine allows a more mature reversal.

AFI's catalog confirms the film's machine solicits a wish, produces a granted
receipt, disappears with the carnival, and is later found so the protagonist
can reverse the transformation. The Orison borrows that structure only. It
does not borrow dialogue, characters, romance, toy-company plot, visual design
or trademarked identity.

Source: https://catalog.afi.com/Film/58497-BIG

## Orison storyline — “THE BIG JOB”

The player asks the machine a question it cannot hear:

> AM I BIG ENOUGH TO KEEP THIS WHOLE HOUSE?

The coin visibly takes the YES trough, its leaf switch closes, and the powered
machine nods when the player works the plunger. This is ordinary chance, not
magic. Later the plug is found loose on the floor. That does not prove it was
loose when the answer occurred; the machine preserves ambiguity rather than
claiming a physically impossible unpowered answer.

On the next shift the wish is granted occupationally, not anatomically. Every
building instrument recognizes the player as its responsible hand at once:
annunciator drops fall, the house telephone asks, message slips accumulate,
keys are checked out to the same number, and unrelated residents address them
as superintendent. Existing owners request these presentations; the fortune
machine authors no job, case, access or save fact.

The comedy escalates through cheap existing systems. Suggested meme beats:

- a work-order strip longer than the player is tall;
- every board says the same responsible hand while no resident agrees who
  appointed them;
- “Congratulations on the promotion. Which tenant promoted you?”;
- after the ordinary answer, the machine sits unplugged while the wired house
  continues answering for it;
- HOUSE ENGLISH renders the state as **THE HOUSE HEARD BIG**.

The burden is not solved by completing a checklist. The player returns and asks:

> CAN I BE SMALL ENOUGH TO HEAR ONE APARTMENT AT A TIME?

The same honest coin race may land YES or NO. Reversal is earned by restoring
custody—returning keys, releasing cords and selecting one report—after which the
house stops addressing the player in aggregate. The final head pose is not proof
of what caused it.

## Ownership and scope

- One prop; no viewport, screen, dynamic light or physics body.
- Its runtime kind is `fortune_answer`, never `arcade_cabinet`; it does not
  consume a cabinet programme or inherit the signal-parlour family contract.
- Two coin troughs and leaf switches, two electromagnets, common striker,
  plunger, nod/shake pendulums, neutral return, locked money drawer and bounded
  bell/clack.
- First interaction is always ordinary and reconstructible.
- A case/orchestration owner may observe one neutral `answer_given` fact:
  answer, coin path, powered-at-actuation and sequence.
- The prop never understands question text and never grants or reverses state.
- The “promotion” reuses existing telephone, register, keys, annunciators and
  WorkOrders presentations; it creates no duplicate lifecycle.
- Plain-language accessibility states coin path and head motion. YES/NO remains
  literal and never depends on color.

## Integration map

| Beat | Existing owner | What A11 may request | What A11 must not do |
| --- | --- | --- | --- |
| Ordinary answer | Fortune prop | Publish answer/path/sequence | Store a question or infer meaning |
| House answers back | First-shift/case orchestration | Ask existing instruments to present their own state | Fabricate jobs, calls, keys or residents |
| Burden | WorkOrders and instrument owners | Select already-authored simultaneous presentations | Advance or close their lifecycle |
| Reversal | Custody and first-shift owner | Observe cords released, keys returned, one report selected | Treat checklist completion as moral proof |
| Save/reload | RealityState through its current owners | Persist only the orchestration owner's case boundary | Let the cabinet write campaign state |

The cheap spectacle is deliberately distributed: one owner composes many
existing instruments, while each instrument retains its ordinary mechanics.
This makes the scene larger than the new asset without creating a second game
inside the cabinet.

## Gates

Focused: deterministic coin paths, one answer per coin, refusal without coin,
refusal without current, neutral striker return, no question storage, no
story/persistence references, snapshot/abort.

Production-live: reachable on the cleared F01 wall, no blocked route, ordinary
operation changes only its own mechanism, unplugged pose is visibly distinct,
existing owners alone produce the “big job” cascade.

Render: empty-wall control; ordinary powered coin race; nod and shake;
unplugged refusal and loose plug after the answer;
oversized work strip and simultaneous house indications; restored quiet wall.
No frame may require a caption to distinguish YES from NO.
