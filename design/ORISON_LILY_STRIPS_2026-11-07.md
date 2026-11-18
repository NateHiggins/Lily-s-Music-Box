# Lily's strips at the Harukiya, a penny each

Evidence class: **INERT**. Working brief, 2026-11-07. Lily asked for her daily strips to be sold at the bar for a
penny (2026-11-06). On 2026-11-07 she asked for them to be added to the game's library of strips, and said she means to
make one every day for a year.

## The year of strips

Each real day's strip runs as the same day in the paper year, 10 November 1928 to 9 November 1929. So 10 November to
31 December are 1928, and every other day is 1929. A year of strips, starting 10 November 2026, fills the paper year
exactly. The first two strips sit at its end:

- *Radio*, 6 November 1929;
- *Progress*, 7 November 1929.

The strips are drawn outside the repository: the LILITH pipeline, the comic library's `daily/` folder and its
`LIBRARY.md`. Only the finished, lettered strip ships. The prompts, LoRAs and renders stay private.

## Adding a day's strip

```
python tools/add_lily_strip.py <strip.png> --title "Progress" [--date 2026-11-07]
```

This maps the real date (today if omitted) into the paper year. It writes the picture to
`game/assets/ui/comics/strips/<date>.webp`, 1,600 pixels wide, and adds or replaces that day's row in
`game/data/lily_strips.json`. Godot then imports the picture once, and its `.webp.import` is staged with `git add -f`,
as every newspaper picture is.

## In the game

- **On the bar.** A short pile of paper sits a hand's width west of the counter glass, with a card in Lily's hand:
  "LILY'S STRIP, A PENNY". The pile holds the strips whose day has come and that the case does not hold yet, newest
  on top. Its height follows that count.
- **Drawing one.** The player's hand grabs the top strip and draws it toward the customer's side (RUL-013; there is no
  menu). Drawn far enough, it is bought: the `lily_strip` item, 1 cent, at the Harukiya, through `ShopSales`.
  - The settlement owns the hours (the bar is open 19:00 to 02:00), the stock group `strips` and the exact debit.
  - A refusal leaves money, stock and the pocket as they were, and the counter's notice line says why: closed, short
    of cash, or the till's carrier down.
  - A strip already kept is not on the pile, so it cannot be bought twice.
- **Keeping and reading.** A bought strip goes into the case's comics pocket (`PaperPocket`, its own `strips` list),
  behind the LILITH issues, newest first. Its cover in the pocket reads LILY and the day. Drawn from the case, it is
  held up as a picture: the pocket reader shows the strip three panels wide, with the lettering drawn into the art.

## Verification

`HarukiyaStripRouteTest` runs in the production V2 root with real input. It checks:
- before the first strip's day, the pile is empty;
- on the day, the pile holds both strips, newest on top;
- at 3 p.m. the bar is shut and nothing is sold;
- at 8 p.m. a strip is bought for exactly a penny, and the hand lets go;
- short of cash, nothing moves and the notice says why;
- the second strip sells, and the pile is then empty;
- both strips are in the comics pocket, newest first, and the newest is read as a picture.

## Not built

- **Who sells them.** Stacy is not involved in the sale, and the pile is self-service while the bar is open. Lily may
  want Stacy to hand them over instead.
- **The 7 AM pitch.** The scheduled pitch task does not add strips to the game. Adding one is the command above, run
  when a strip is finished.
