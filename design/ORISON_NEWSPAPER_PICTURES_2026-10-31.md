# The papers' pages and pictures

Evidence class: **INERT**

Lily asked for experiments with layouts and generated content, then for research into
period sources, and then chose all five test pages on 2026-10-31.

## What the papers now do

- **The Record** has a blackletter nameplate, a weather woodcut in the ear, a stepped lead
  in five columns, and a line portrait or a press photograph.
- **The Speaker** has a red fat-face nameplate with the horn, a two-line banner, and either
  a picture across the page or a tall one between columns. The Listening Lady signs her
  column with a drawing of herself.
- **Composographs** are in the Speaker only. A posed figure is cut out and pasted over a
  scene with the seam showing, and the caption says so.
- **The Brown Section** folds into the Speaker on Sundays: four sepia pictures, captions
  only, reached by a third turn of the sheet.
- **The Photo Drama** runs on the back of Saturday's Speaker: three posed stills, one line
  under each.

## How it is built

`art/data/newspaper_picture_book.json` holds every prompt, chosen seed and caption.
`art/tools/build_newspaper_pictures.py` writes small greyscale images and
`game/data/newspapers/pictures.json`. **the print shader** prints the images as
halftone, gravure or ink at screen resolution, so the dots stay crisp. A date with no
picture still sets a whole page. `tools/audit_newspapers.py` holds captions to the same
brief as the rest of the paper.

Generated sources stay outside the repository. Reference photographs were looked at for
form only and never given to the generator (RUL-007). No lettering is generated (RUL-008).

## What the research gave

- Boxed ears, a banner with a second italic deck, inset portraits and a small quip panel:
  [Santa Ana Register, 28 October 1929](https://commons.wikimedia.org/wiki/File:Santa_Ana_Register_front_page,_Oct_28,_1929_-_Flickr_-_Orange_County_Archives.jpg).
- Plain portrait cuts with name captions:
  [Oceanside Blade-Tribune, 8 October 1929](https://commons.wikimedia.org/wiki/File:Blade-Tribune-Front-Page-1929-10-08-v2.jpg).
- A weather ear with a woodcut:
  [San Francisco Examiner, 24 April 1929](https://commons.wikimedia.org/wiki/File:Point_Reyes_Lighthouse_1929_Time_Capsule-_Newspaper-_San_Francisco_Examiner-_April_24,_1929._Front_Page._(15904044-829d-4d32-afcf-95e3297ab392).jpg).
- Composographs and "Photo Drama from Life":
  [Bob Stepno on the Evening Graphic](https://stepno.com/unc/graphic/).
- Sepia "brown section" pictures and captions:
  [The Vindicator's section](https://bobonbooks.com/tag/vindicator/) and
  [the first American section, 1912](https://graphicarts.princeton.edu/2017/12/25/first-american-rotogravure-section-december-1912).

Library of Congress scans sat behind a human-verification check and were not used. The
tabloid "X marks the spot" device could not be confirmed and was left out.

## Open for Lily

All captions and Photo Drama scripts are new first-draft writing and were not read against
every thread. They name no residents, and none of them answers who sends Party Line her
sardines. Change or cut any of them in the book and rebuild.
