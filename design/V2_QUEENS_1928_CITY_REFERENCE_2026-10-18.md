# Queens cityscape reference, November 1928

Evidence class: **INERT**. Historical research and implementation direction;
neither a runtime receipt nor human appearance acceptance.

The Bible dates the opening to November 10, 1928 and places the Orison in
Queens without fixing a surveyed neighborhood. Use western Queens as a visual
reference, not a claim that the fictional block occupies Queens Plaza. Dates
below describe the source material; modern photographs are not period views.

## Sources and inspected material

- [Queens Chamber of Commerce, 1920 illustrated volume, LOC catalogue](https://www.loc.gov/resource/gdcmassbookdig.queensboroughnew02cham/?st=gallery).
  The [digitized original volume](https://archive.org/details/queensboroughnew00chamrich)
  was inspected at printed pages 16, 88-89 and 98 (PDF pages 20, 96-97 and 106).
  The photographs show the Brewster tower above lower frontage, industrial
  window grids, varied factory heights, rooftop tanks and open sky between
  masses. These establish earlier built fabric, not an exact 1928 panorama.
- [NYC LPC, Bank of the Manhattan Company, LP-2570](https://s-media.nyc.gov/agencies/lpc/lp/2570.pdf),
  pages 1-3 and 6: the bank opened in May 1927; the report records nearby
  five-story apartments, factories, elevated transit and a second office
  building dating to 1928. The inspected plate on page 9 is explicitly a
  **2015** photograph. Its surviving upper form is useful; later storefronts,
  air conditioners and altered details must not be copied into 1928.
- [NYC LPC, Hunters Point, LP-0450](https://s-media.nyc.gov/agencies/lpc/lp/0450.pdf),
  pages 3-6: earlier brick houses and apartments provide narrow vertical
  windows, cornices, stoops and a mixture of two-, three- and four-story
  frontage. This is a domestic reference, not a template for every factory.
- [Queens Library Archives, former LIRR terminal, circa 1920](https://www.flickr.com/photos/qbpllid/2760071903):
  catalogue date and power-station caption verified. The full image request
  was denied, so it is **not** recorded as visually inspected.
- [NYC Municipal Archives, 1924 aerial maps](https://a860-collectionguides.nyc.gov/repositories/2/accessions/37):
  useful future survey source; catalogue only, individual sheets not inspected.
- [NYC planning historic resources, Chrysler chronology](https://www.nyc.gov/assets/planning/download/pdf/applicants/env-review/vanderbilt/06_feis.pdf)
  dates that building to 1928-30. A finished Chrysler crown is unsuitable.
  [Empire State Building history](https://www.esbnyc.com/about/history) dates its
  construction to 1930-31. Neither completed silhouette belongs in this scene.
  [NYC housing historic documentation](https://www.nyc.gov/assets/hpd/downloads/pdfs/services/nycha-section-106-programmatic-agreement.pdf)
  reproduces a 1939 Queensbridge opening notice: its superblock form is later.

## Applied art direction

The additive horizon source now mixes 48 narrow rowhouses, 57 walk-ups,
18 factories and one commercial accent across 124 disjoint footprints.
Most eaves lie between 9.6 and 21.6 metres; one commercial mass reaches
35.2 metres. These are authored composition choices inspired by the sources,
not measured historical building dimensions or a census of Queens.

Separate sash frames, industrial crossbars, cornice stocks and capped masonry
chimneys replace anonymous recessed rectangles. Existing catalogue PBR maps
and authored metric charts remain the surface authority. Photographs are
reference only: none is baked, projected, imported or committed as game art.

An enclosing ring at every rooftop camera height was the wrong visual target.
The source probe still requires distant grade-level continuity; it records
open sky above the deliberately lower roofs without treating that sky as a
missing building. Actual world registration and sightlines still need the
original composed render. Retained near-city masses and their roof hardware
are unchanged by this additive revision and remain a separate polish scope.

Native rebuilding, source checks and preview images do not renew the expired
surface/access contracts. New original composed captures and full qualification
remain required before publishing this candidate as accepted V2 scenery.

## Candidate checks

Both native builds complete with closed, consistently oriented stock and
12,331 recessed-pane BVH samples at the original 0.1 mm tolerance. Both GLB
UV audits have zero failing surfaces. The four final native context previews
are inspected; their source hashes are recorded in the adjacent review JSON.
They omit the retained near-city context and are not composed game captures.

The original **queens_horizon_bench3.log.receipt.json** reports 12,458 checks,
zero failures and no script errors. Imported extents match independently
measured source vertices, including projecting sash frames and chimney caps;
every pane has a fitted physical hit. **queens_source_bench2** also passes.
The first two horizon benches correctly reject the old flush-wall extent
assumption; those diagnostics are retained. The first returns process code
124 because it counted 124 failures, but its receipt says **timed_out: false**
and elapsed 7.81 seconds. It is not a successful run or ceiling termination.
The bench now returns 1 for any failure, avoiding that reserved-code ambiguity.

Reader baseline: zero new unread fields. Selected native/source preflights
pass. These checks grant no played exterior access, human acceptance or
whole-V2 completion status.
