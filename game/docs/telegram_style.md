# The service wire — HUD and world-text style

*Owner-ruled and landed 2026-08-15. Bible §VIII.5.k is the fiction authority;
this file is the production reference.*

## Thesis

The waking world does not float software over objects. It files a field note.
The Vantry service set gives one brief mechanical clack, pushes a narrow paper
slip from its crown, and the camera receives a readable enlargement of the same
telegram. The result should feel less like opening a codex and more like the
building has carbon-copied the player's touch.

The system has one sequence:

```text
E -> authoritative object reaction -> object returns observation facts
  -> powered service set advances paper -> shared HUD presents field copy
```

The presenter owns no interaction, prop state, job state, case truth, inventory,
pause or input focus. Radio OFF suppresses the print/readout; the real object
still answers E. Modal and protected conversation surfaces suppress the card.

## The visual grammar

| Role | Treatment |
|---|---|
| stock | warm unbleached receipt paper; visible rag fiber and low-contrast platen bands; never clean UI white |
| primary ink | carbon brown-black `#211c18` |
| secondary ink | worn graphite `#4e463b` |
| institutional stamp | oxidized service teal `#477f78` |
| work/order accent | old amber `#a95f24` |
| present condition / exception | ledger red `#813a31`, never neon alarm red |
| body | Courier Prime Regular, mixed case for prose, 16 px at 720p |
| title | Courier Prime Bold, uppercase, 20 px at 720p |
| metadata | Courier Prime Regular/Bold, 11–12 px; never required for comprehension |

The paper plate is `telegram_paper_stock_v1.png`, a 1254 px square material
scan used as a stretch-safe panel center and the albedo on the modeled slip. It
contains no baked letters, logos, stamps or hard stains. Live glyphs remain
readable, localizable and scalable.

Courier Prime Regular and Bold are bundled under the SIL Open Font License 1.1.
The unmodified files and `OFL.txt` come from the official
[Google Fonts Courier Prime directory](https://github.com/google/fonts/tree/main/ofl/courierprime).

## Composition

- The field copy sits at the lower right with a 24 px safety margin. It never
  crosses the crosshair or interaction target.
- Header order is stamp, serial, object title, rule, observation, condition.
  The object title may ellipsize; the actual observation must wrap.
- A card is non-modal and self-clearing. A new interaction replaces it rather
  than stacking paper across the screen.
- Typewriter reveal is quick presentation, not a reading gate. Set
  `TELEGRAM_REDUCED_TYPEWRITER=1` for instant text; eventual accessibility UI
  must expose the same choice without changing content.
- At narrow viewports the card contracts to the safe width, never below 300 px.
  The I7 proof pass still owes ultrawide, touch and long-localization captures.

## Copy voice

This is a service wire, not a comedian narrating inventory. Use an honest object
name, one useful observation, and a state-aware condition. `STOP` belongs at
clear telegram clauses, not after every noun. Do not use quotation marks unless
the text is an attributed quotation, and do not invent prices, dates, patent
claims or “first ever” folklore because the typography makes them feel official.

Until I2 lands the sourced object book, `FunctionalProp.service_wire_card()`
prints a deliberately plain condition-only fallback. It is coverage, not final
flavor copy. Existing authored `InspectableZone` prose now uses the shared card
rather than constructing its own lower-third Control tree.

## Where the grammar applies

Use `TelegramStyle` for:

- service-wire field copies;
- objective/work-order slips;
- the universal E prompt's inverse carbon tag;
- Vantry machine plates, filed notices and other institutional service text;
- future trivia cards backed by `PROP_TRIVIA_RESEARCH.md`.

Do not homogenize people. Dialogue, captions and subtitles prioritize voice and
accessibility. Resident handwriting, multilingual text, shop signs, advertising,
newspapers and entertainment brands keep their authored typography. A telegram
may quote their facts, but it cannot replace their material culture.

## Assets and provenance

The paper stock was generated with the built-in image tool, then copied into the
project. Final production prompt:

> Flat, front-facing seamless scan of blank warm ivory teleprinter receipt
> paper, edge to edge and orthographic; photorealistic archival material with
> fine rag fibers, pulp grain, sparse roller bands, faint ruled guides and tiny
> carbon-transfer specks; low contrast, calm readable center; diffuse scanner
> light; no text, glyphs, logos, stamps, border, holes, tears, folds, hard stains,
> objects, shadows or watermark.

Files:

- `game/assets/ui/telegram/telegram_paper_stock_v1.png`
- `game/assets/fonts/courier_prime/CourierPrime-Regular.ttf`
- `game/assets/fonts/courier_prime/CourierPrime-Bold.ttf`
- `game/assets/fonts/courier_prime/OFL.txt`

## Landed owners and proof

- `TelegramStyle`: assets, palette, paper/tag StyleBoxes and font application.
- `TelegramHud`: one non-modal presenter, responsive placement, replacement,
  wrapping, duration and reduced-typewriter behavior.
- `PropServiceWire`: one cached, read-only formatter for the researched object
  book. Mechanism owners supply state tokens after acting; unresolved tokens,
  non-presentable case templates and unknown cards return no slip.
- `PlayerController`: calls the presenter only after the real interaction and
  only if the powered carried device prints successfully.
- `ServiceSetProp`: modeled crown platen, physical textured slip, feed motion
  and recorded mechanical ticks. It owns no text facts.
- `ObjectiveTracker`, the E prompt and service-set Label3Ds use the same family.

`ServiceSetTest.tscn` proves the powered/off split, physical paper, shared HUD,
font ownership, real refrigerator reaction before the field copy, replacement,
non-locking behavior and existing inspection routing. The production capture is
`art/renders/telegram_style_i3/telegram_service_wire.png`.

The first I4 response batch is proven by `ServiceWireResponseTest.tscn`: the
F03 utility latch gives and clicks without opening, after-hours Passage chains
rattle without moving their cart, a busy toaster answers without restarting,
and the HARDWARE PAINT counter taps and returns an inspect card when no order is
eligible. The second batch gives every laundry control its own ray owner: washer
lid, safety release, wringer feed, fill cocks and drain each operate only their
named mechanism; the airer rope cleat raises/lowers the rack while the rinse
stand answers without pretending to be another switch. All five authored task
lamps now own a local Bakelite key: it clicks, turns, interrupts only that lamp,
and remains authoritative when the central LightRig reapplies its budget. The
five line-fed domestic picture receivers now expose their tuning knob rather
than a false universal power switch: the knob and picture answer locally while
the case-bearing electrical signal remains live. I4 remains open for the rest
of the non-ambient matrix.
