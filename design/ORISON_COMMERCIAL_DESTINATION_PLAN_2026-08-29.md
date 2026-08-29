# Orison commercial destinations — arrangement ruling, 2026-08-29

Owner direction: one hero shop with a fully interactive interior and
room for NPC life; split some shops onto the main street; use
semi-supernatural layout to distribute destinations evenly; optimise
the player's time across travel, reward and distraction; make the rest
highly interactive facades.

This is a work order, not proof. It is deliberately named so the
completeness ledger refuses it as evidence.

## The hero shop is the bodega, and it already exists in the fiction

Not a new invention. **schedule_director** already carries
`bodega  F01 (16.8, -8.6)  exterior: true` — across the street, east
end, about 17 m from the Orison's front door. **resident_routines**
already holds an authored street polyline to it.
**resident_schedules.json** already sends residents there thirteen-plus
times a day, each with specific habit:

- 07:00 — paper and milk; *corrects the sale sign in her head*
- the morning thermos refill; *the night clerk knows her order*
- 13:30 sharp, same list, receipt kept and filed
- 03:30 — records the cooler hum; buys one thing so it counts as a
  transaction
- the standing list, exact brands; substitution is chaos; the bodega
  only for the two items it reliably stocks
- and one resident who pointedly *never* uses it

There is already a night clerk, a cooler that hums, a display case
people eat off, and a sale sign with a known error. This is the most
densely populated social space in the game's fiction and it has no
interior. Build that, and the existing schedule system populates it
with named neighbours on their own routines for free — no new NPC
machinery.

A New York bodega *is* the deli the owner asked for: sandwiches and
coffee at the front, a cooler, a cat, and a counter at the back that
sells whatever the block actually needs.

## Interior program

**Front** — counter, stools, display case, coffee urn, cooler (it
hums; a resident records it), radio. The social room.
**Aisles** — shelf goods carry the §13 commentary: products still
advertising for manufacturers who no longer exist. The sale sign
carries its error, because a resident already mentally corrects it.
**Back counter — notions.** Fuses, washers, tape, wire, packing. The
corner store that stocks what the block needs, so the super's errand
and the neighbours' errand share one room. Every part fetch is also a
social encounter.
**Back room** — storage. This is where the geometry begins to lie.

## The destination compass

Today every shop sits in one passage on the far side of the building
from the front door: one trip, exhausted once. The arrangement spreads
cost and reward across five directions.

| Direction | Destination | Cost | Reward |
|---|---|---|---|
| East-front, ~17 m | **the bodega** | daily, cheap | food, people, notions, overheard neighbours |
| Front street | news & cigars, keys cut, shoe rebuilding, model laundry as facades | free, passed | signage, steam, life, the Arcade sightline |
| North, deep | the Arcade, its remaining shopfronts, Harukiya below | occasional, long | entertainment, drink, the back rooms |
| Down | boiler, laundry, and later the utility/subway direction | work | the oldest layer |
| Up | roof | deliberate | the landmark network: see the Arcade from above |
| Inward | the impossible link (below) | earned | **time** |

**Street shops** are pulled out of the passage precisely because the
daily walk should have life in it: a newsstand is street furniture par
excellence; a locksmith is thematically perfect beside a building
super; a laundry vents steam to the pavement, which is simultaneously
sensory, atmospheric and an occluder the brief explicitly wants.

**Work and life pull in opposite directions.** The part errand stays
in the passage's hardware/paint — existing shop-inventory wiring is
preserved — while food and neighbours are east. That is a real cost
with real character for a maintenance worker, and it sets up the
payoff.

## The semi-supernatural element: the back room is the transit system

The bodega's back room connects to the Arcade's service corridor.

It should not. The bodega is south-east of the building; the passage
runs north of it. The link crosses the entire Orison and comes out
where nothing adjacent could.

Why here, and why it means something:

- **Frequency breeds violation.** The player visits the bodega daily.
  The brief's §27 rule is to teach the ruler before breaking it — the
  most-visited ordinary room is the correct place to install the
  break.
- **The reward for understanding the map is time.** Two errands in
  opposite directions collapse into one trip for a player who has
  learned the shortcut. This is the answer to "optimise travel and
  reward": the impossible geometry is not decoration, it is transit,
  and comprehension is what unlocks it.
- **It is discovered, never signposted.** No marker, no prompt beyond
  an ordinary door. The first passage through is disorienting; the
  tenth is a commute.
- **It distributes destinations without building metres.** The map
  feels wider while the walkable geometry stays affordable — exactly
  the compression the brief asks for.

Later stages can make the link behave inconsistently (open only at
certain hours, or the return trip arriving somewhere subtly other than
the departure). Do not start there. Start with it simply, quietly
being impossible.

## What "highly interactive facade" means

Cheap, because most of the machinery exists.
**passage_hours_director** already opens and closes shops on the clock
and swaps night-service lighting — extend it to the street shops.
Every facade then carries:

- a sign hierarchy from several eras at once (carved name, painted
  board, neon, plastic panel, handwritten card) per brief §8
- window glass that is never a black rectangle — parallax or reflected
  interiors per §19
- shutters, hours cards, letter slots, notices, lease and permit
  paperwork that contradicts itself
- state that changes with the clock and the story
- answers to §14's six questions: original purpose, first
  modification, second modification, recent use, abandonment event,
  current impossible state

Enterable is one shop. Legible and stateful is every shop.

## Consequences for the Sept 3 work order

1. The bodega interior is the first commercial build, not the Arcade.
2. Its back-counter notions inventory and the impossible link are
   authored together — the link is the reason the room can be small.
3. Three or four passage shops relocate to the front street as
   facades; the rest stay and gain their historical layers.
4. Beat 4 of the golden shift can be satisfied either from the bodega
   notions counter or from hardware/paint through the link; the second
   is better, because it makes the shortcut load-bearing.
