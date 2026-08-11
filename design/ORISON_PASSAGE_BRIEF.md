# The Passage — rehousing the shops

*Proposed 2026-08-11. **Not canon until the owner rules.** Nothing is built.
Supersedes nothing yet; `SHOP_INTERIOR_INVENTORY.md` Phase 1 remains as-built
until this is ruled on, and §7 is honest about what ruling it costs.*

---

## 1. What history actually offers

Two traditions, and in 1928 they had not met.

**The enclosed arcade already existed and was grand.** Providence's Westminster
Arcade (1828) is the first enclosed shopping mall in the United States; the
Cleveland Arcade (1890) is the first indoor shopping *centre* — two nine-storey
buildings joined by a five-storey glass-roofed hall over 300 feet long, modelled
directly on the Galleria Vittorio Emanuele II in Milan. These were speculative
commercial monuments, built to impress.

**Working-class New York shopped from carts.** In 1929 the city had 57 open-air
markets serving 6,053 pushcarts, organised out of a 1923 consolidation.
Refrigeration was rare and pantries were small, so food shopping was a daily
errand and the cart was the shop. The enclosed municipal market — Essex Street
and its siblings — is *later*: LaGuardia's WPA programme in the 1930s, with
pushcarts finally banned in 1938.

**So a glass-roofed arcade full of pushcarts is not a compromise between the
two. It is what happens when the first is built for a neighbourhood that can
only afford the second.** That is already this game's thesis.

---

## 2. The proposal

**The Vantry Arcade**, off the same block, built 1912 by the company that built
the Orison, for the same reason: as a demonstration.

Vantry & Co built the Orison as a showcase, which is canon and is why an
ordinary Queens walk-up is wired past the standard of a broadcast house
(§VIII.3). They built the Passage for the same prospectus — a glass barrel vault,
iron ribs, terrazzo, eleven units with proper shopfronts, gas and then electric,
and an acoustic that was in the sales drawings.

By 1928 it has settled into what the neighbourhood needed rather than what it
was sold as. **The eleven units are still there behind their glass. The middle
of the hall, which was drawn with promenading couples in it, is full of
pushcarts** — the market the street would otherwise have held, moved indoors a
decade before the city thought of it, because the roof was already there.

Nobody finds this remarkable. It is the same sentence as the building: **built
for a future that did not arrive, occupied by the present that did.**

And the carts never leave, because 1938 never comes.

---

## 3. Why this solves the problem you started with

- **The exterior LOD question disappears.** From the street the Passage is one
  facade and one entrance. There are no shop interiors on the street to draw,
  cheapen, or stream. The eleven interiors exist inside one enclosed volume that
  is only rendered when the player is in it.
- **The display-case doctrine survives intact.** `SHOP_INTERIOR_BUILD_GUIDE`
  says the shops are "authored to be looked into through a storefront" — an
  arcade *is* a street with a roof on it, so every one of those windows still
  works exactly as designed. A market hall of open stalls would have destroyed
  that; this preserves it.
- **No threshold transition.** You walk in. The hall is a room the way the lobby
  is a room. Nothing fades.
- **R2's "density at the perimeter, clear floor in the middle" gets a third
  answer**: the perimeter is shops, the middle is carts, and *carts move*. See
  §5.

---

## 4. The loop, which is the point

Today the shops are a place to look at. The ask is to make going there and
coming back a real activity. The pieces, in order of how much they matter:

**1. What you carry changes how you cross.** This is the keystone and it wires
the Passage directly to the street. A crate of valves, a sack, a full box — you
walk slower, you cannot sprint, and it sits low enough in frame to spoil your
view of the near lane. Crossing back is measurably harder than crossing over,
using no UI and no new systems. The errand has a *return leg* with its own
difficulty, which is the thing the current shops entirely lack.

**2. The carts move, so finding is part of the trip.** A cart is not at a fixed
address. The fishmonger is where the fishmonger fits today. You learn the hall
by its regulars, not by a map, and a vendor who has moved is a small mystery
with a mundane answer. This is also why carts, mechanically: they can be
*shoved*, which makes navigating the middle of the hall a fidget rather than a
corridor.

**3. The hall keeps hours.** Come late and the units are shuttered and the carts
are chained in a row, and a 300-foot glass hall with nothing in it is the best
free horror set the project will ever get. This wants pairing with the street's
open question about whether traffic stops at night.

**4. Residents shop.** Seeing Evelyn buying tea, at the hour her routine says
she buys tea, does more for the building being inhabited than any number of
props. `resident_routines.gd` is anchor-to-anchor, so this is venue anchors,
which is work R3 already needs doing.

**5. Errands have a reason to exist.** The dead-channel chore already ends "buy
one at the bodega, return" (S4). That shape generalises: something in the
building is broken, the part is in the Passage, the trip is the gameplay, and
the fix is the reward. No shop needs a currency system for this to work.

---

## 5. What the eleven units become

Unchanged in kind. The ten trades plus Otis & Son keep their identities and
their fitted interiors; they gain proper shopfronts onto the hall instead of
onto weather, and the re-plan R2 asked for happens as part of the move rather
than as surgery on `_south_street_wall()`.

Two things the move fixes for free:

- **`_south_street_wall()` stops being the constraint.** R2 notes width is
  expensive because every shop is its own building on the street, driving
  footprint, void, awning, blade and signage together. Inside a hall, a unit is
  a unit; width is cheap and the party walls are just party walls.
- **The two units that could not grow backward** — the diner in the Harukiya's
  mass, the druggist in `nbr_w` — are no longer boxed in by neighbours that
  exist for exterior reasons.

The pushcarts are the new small-trade layer: produce, fish, notions, secondhand
tools, a knife grinder, a coffee stand. They are also where a vendor can be a
person without needing a modelled interior.

---

## 6. Naming — a real hazard, flag it now

**`arcade` already means the cabinets in this codebase.** `game/scripts/arcade/`,
`ArcadeCabinetProp`, `ArcadeCatalog`, `arcade_row.gd` — and §VIII.5.g already
ruled that "arcade" is the subsystem and "signal parlour" is the fiction.

Proposed, mirroring that split exactly:

- **Fiction: "the Vantry Arcade", or just "the Passage".**
- **Code: `passage`.** Historically it is the better word anyway — the Parisian
  *passage couvert* is the type specimen the whole form descends from.

Do not let a second `arcade` into the source tree.

---

## 7. What this costs, honestly

This is the expensive part of the proposal and it should be ruled on with the
number in view.

**Shop Phase 1 is built, verified and signed off**: eleven interiors, 181
per-shop buffers, shop routes PASS, `ShopEntryTest` PASS, LightingAudit PASS at
127 spaces, entered-shop luma measured. Relocating them into a hall invalidates
the *placement* half of that work — the void cuts, the awnings, the blades, the
signage, the exterior stage boundary interactions, and every route anchor that
points at a street door.

**What survives:** the interiors themselves, the fittings, the trade
identities, the buffers, and the build guide's doctrine. This is a move, not a
rebuild.

**What does not:** `SHOP_PLAN`'s street geometry, `_south_street_wall()`'s
per-shop buildings, and the storefront elevation as authored. R5's two
protections — the 181 buffers and the deliberate NEWS CIGARS inaccessible side —
both need carrying across deliberately rather than assumed.

**A cheaper middle exists** and should be considered rather than dismissed:
**keep three or four on the street and move the rest.** The trades that want a
street are the ones you use without planning to — the luncheonette, news &
cigars, the pawnbroker's window. The trades that reward a trip go inside. That
halves the demolition, keeps the street's frontage alive for the frogger to have
a destination, and still removes most of the interior load from the exterior
frame.

---

## 8. Open questions for the owner

1. **All eleven, or the split in §7?** The split is cheaper and arguably better
   for the street; all-eleven is cleaner for performance and for the loop.
2. **Where does it attach?** East of the Orison, sharing the party wall, is the
   strongest read — Vantry built both, so they are one investment. It also puts
   the entrance on the same side as the bodega and makes the frogger crossing
   the natural route.
3. **Is the Passage's roof intact?** A glass vault with panels missing, boarded,
   or sheeted over changes the light in there completely and is the single
   biggest atmosphere decision in this document.
4. **Do the carts have owners who are always the same people?** Named vendors
   are characters and cost writing; anonymous ones are furniture that moves.
5. **Currency, or barter, or neither?** §4.5 argues errands work with none of
   the three. Adding money is a system, not a detail.

---

## Sources

- [Westminster Arcade, Providence (1828) — Wikipedia](https://en.wikipedia.org/wiki/Westminster_Arcade)
- [The Cleveland Arcade (1890), modelled on Milan's Galleria — Downtown Cleveland](https://www.downtowncleveland.com/blog/the-arcade-y789n)
- [Cleveland Arcade, glass skylight and four balconies — Only In Your State](https://www.onlyinyourstate.com/ohio/first-attraction-oh/)
- [New York City's public markets, past and present — Turnstile Tours](https://turnstiletours.com/new-york-citys-public-markets-past-present/)
- [Evolution of New York City markets: 57 open-air markets, 6,053 pushcarts in 1929 — City Food Research](http://cityfoodresearch.org/2018/11/22/evolution-of-new-york-city-markets/)
- [LaGuardia's war on pushcarts and the making of Essex Market — The Bowery Boys](https://www.boweryboyshistory.com/2026/04/la-guardias-war-on-pushcarts-and-the-making-of-essex-market.html)
