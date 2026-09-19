# Critique contract

One JSON file per specimen in the review run's `critiques/` directory, named
`<specimen id>.json`. The scorer (`priority.py`) reads only the fields below;
everything else in the file is kept as the reviewer's notes.

```json
{
  "specimen": "fridge__1927_monitor_top",
  "axes": {
    "object_class": 0, "proportion": 2, "silhouette": 1, "detail": 3,
    "material": 2, "wear": 3, "mount": 0
  },
  "effort_hours": 6,
  "confidence": "high",
  "summary": "Two sentences: the one thing most wrong, and whether the object class is right.",
  "modelling": ["concrete change with a dimension or a primitive count", "..."],
  "texturing": ["concrete change naming a material key or a map", "..."],
  "references_used": ["File:GE Monitor Top.jpg", "..."],
  "not_reopened": ["ruling the notes already made that this critique respects"]
}
```

## Axes

Each axis is the size of the gap between our specimen and the reference
photographs on that axis, 0 to 5. It is not a taste score.

| axis | 0 means | 5 means |
|---|---|---|
| object_class | it is the right kind of thing for 1927-1928 Queens | it is a different object (wrong era, wrong type) |
| proportion | the overall w:h:d and the part ratios match the real object | a major dimension is off by a third or more |
| silhouette | the outline reads as the real object from three metres | the outline reads as a box with a label |
| detail | the parts a hand would reach exist and are placed right | the interactive or characteristic parts are missing |
| material | surfaces read as the right substance and finish | flat colour where the reference shows a clear material |
| wear | age and use read as the fiction says (sixteen years, rented) | factory-fresh or uniformly grubby |
| mount | it stands, hangs or fixes the way the real one does | it floats, sinks or faces the wrong way |

## How to look

1. Open the sheet: our four bearings on top, references below with their
   licence in the caption. Read the header: size in metres, mount, installed
   count, tier, whether a completed review already served the family, and
   the flat-colour share from the material census.
2. Compare silhouette first (three_quarter and side), then proportion against
   the stated metres, then the parts, then the surfaces (high_quarter and
   front show finish best).
3. Read the prop script's header comment before writing a modelling bullet.
   The house rule is proportion before detail, the right object before a
   nicer wrong one, wear that says who owns it, model what will be touched,
   do not gold-plate scenery.
4. Do not reopen a ruling. `queries.json` lists `already_ruled` per kind and
   `PROP_REFERENCE_NOTES.md` carries the reasoning. Put anything you would
   have changed but may not into `not_reopened`.
5. Write bullets a modeller can act on: "add the second hinge knuckle at
   1.83 m" beats "improve the hinges". Name material keys from
   `MATERIAL_CATALOG` in `gen_layout.py` where one exists; say "new key"
   where one does not.
6. Effort in hours for a competent GDScript modeller following the script's
   existing style, including the before/after render.

## What the critique is not

It is judgement, and it is the only judgement in the pipeline. The
measurements around it (bounds, census, installed counts, tiers) are facts
the tool reads; the score is a formula over both. A critique that says "looks
fine" with every axis at 0 is a valid result and must be written when true.
