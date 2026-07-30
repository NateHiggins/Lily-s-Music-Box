# Orison Furnishing Library — Design References

Every piece in the building is an **original parametric model** authored in
`art/blender/scripts/build_orison.py` (the `asm_*` functions). Each one is
designed *in the spirit of* an iconic furniture or appliance typology — the
era and design language are the reference, the geometry is ours. Nothing is
a replica; dimensions follow period ergonomic norms.

| Model (`asm`) | Typology / era referenced | Our variation |
|---|---|---|
| `sofa` | 1950s architectural "boxed" sofa — the rational rectilinear school of postwar office-lobby seating | Piped cushion rolls front and back, slab arms, tapered round legs; leg finish flips between dark wood and chrome per household |
| `chair` | 19th-century Viennese bentwood café chair (steam-bent beech, round seat) | Hoop back approximated in three bent segments + inner rail, splayed turned legs, 44 cm seat |
| `table_round` | 1950s single-pedestal "tulip" dining table — the war on the "slum of legs" | One sculpted lathe stem with a flared foot and under-beveled 1.1 m top |
| `table_rect` | Farmhouse refectory table with turned legs | Double-square top, spool-turned legs, recessed apron |
| `coffee` | Postwar biomorphic studio table (elliptical glass over sculptural base) | Elliptical glass blade over two interlocking keeled fins |
| `bed` | American spool ("Jenny Lind") bed, turned posts and spindles | Turned head/foot posts with urn finial steps, five head spindles, deep mattress, folded turnback blanket, lathe-puffed pillows |
| `wardrobe` | Biedermeier armoire: plinth, framed doors, crown cornice | Two raised-panel doors, center stile, turned brass knobs, stepped cornice |
| `shelf` | Postwar modular wall-system shelving (slim steel ladders + boards) | Four round steel posts, five oak boards, jittered book runs and one leaning book per bay |
| `tv` | Splay-leg mid-century media credenza | Dowel legs, magazine shelf, thin panel on a fork column |
| `nightstand` | Mid-century bedside chest | Tapered legs, single drawer, brass cone knob |
| `desk` | Danish-school teak writing desk | Floating top, splayed square-taper legs with stretchers, single drawer with recessed pull |
| `kitchen` | The 1926 Frankfurt Kitchen: flat fronts, continuous work surface | Toe-kick, groove pulls, inset sink with arched spout and cross taps, matching uppers |
| `stove` | 1940s American enamel range | Backsplash clock panel, four ringed burners, bakelite knob row, towel-rail oven door with window |
| `fridge50` | 1950s rounded-shoulder compact refrigerator | Three-step crown chamfer, proud door face, vertical chrome pull with standoffs, latch and maker's badge |
| `toilet` / `sink_ped` | Interwar sanitary porcelain: close-coupled WC, pedestal lavatory | Lathe-turned bowls and basins, chrome cross taps, framed mirror |
| `shower` | Tenement retrofit shower corner | Porcelain tray, chrome L-rail, half-drawn curtain, wall head |
| `switch` | 1930s bakelite toggle on a molded two-step plate | 88 doorways × both faces, latch-side placement at 1.12 m, chrome screws |
| `bench` | Turn-of-century hall settle | Slat seat, spindle back, spool legs |
| `mailbank` | Brass apartment-lobby pigeon bank | 4×5 doors with label windows and dial knobs; one door hangs open |
| `plantable` | Architect's trestle drafting table | A-frame trestles, six overlapping plan sheets, rolled tubes |
| `workbench` | Machinist's bench | Angle-steel legs, butcher-block top, drawer, side vise with bar handle |
| `plant` | Terracotta-potted ficus | Lathe pot, soil disc, three jittered canopy lobes |
| `pipe` | Exposed basement services | True cylinders: headers, mains, conduit, risers; `local: true` anchors a run to a marker (the per-floor radiator risers) |

### Personality clutter (Phase 6 hero/resident pass)

| Model (`asm`) | Typology / era referenced | Our variation |
|---|---|---|
| `amp` | 1960s valve combo amplifier | Vinyl cab, cloth grille, chrome knob row, brass pilot, bakelite strap handle; stacks (Juno runs a small head on a big cab) |
| `guitar` | Electric solid-body / flat-top acoustic | Waisted two-slab body, tilted neck to a paddle head, single string line; leans back toward local −Y onto whatever is closest |
| `pedalboard` | Home-built plywood stomp board | Four mismatched pedals (bakelite/enamel/steel/painted), chrome switches, patch leads |
| `micstand` | Round-base studio mic stand | Cast base, tapering column, boom dropping a capsule toward +Y |
| `reeldeck` | 1970s reel-to-reel deck | Twin platters with enamel hubs, head block, paper VU windows, knob row |
| `headphones` | Cans on a turned wooden stand | Two-segment band, squashed-lathe cups, cable slumped to the surface |
| `mug` | Diner china / enamel shop mug | Lathe body, two-segment tube handle; `mat` picks porcelain/ceramic/enamel |
| `papers` | Loose worked-over paper stack | Per-sheet drift; `mess` widens it (Mina 0, Nadia 0.8) |
| `bookpile` | Horizontal to-read pile | Jittered sizes, five cover materials; doubles as tape boxes and manuals |
| `pinboard` | Cork noticeboard | Card grid squared (`neat`) or drifted layers fighting for space; mounts flush on the storey's true wall face |
| `toolboard` | Shop pegboard | Wrench row by size, hammer, coiled cord on a nail |
| `partstray` | Machinist sorting tray | Rimmed steel tray, 12-cell parts grid; optional opened chassis with socketed glass valves |
| `jarrow` | Salvage jar row | Glass jars, bakelite lids, per-jar fill (screws/washers/fuses) |
| `tripod` | Video camera on sticks | Three splayed legs, center column, body with front lens tube and rear screen |
| `softbox` | Streamer's stand light | Tripod base, tall column, diffuser panel pitched down at the subject (+Y) |
| `cablecoil` | Uncoiled-tomorrow instrument cable | Octagon tube loop, alternating lay, wandering tail |
| `crate` | Slat shipping crate | Record collection filed edge-on (`records`) or a jumble under the lid line (`fill`) |
| `radio` | 1930s table radio | Wood cab, cloth grille, paper dial with brass pointer, two bakelite knobs |
| `sitemodel` | Architect's chipboard massing study | The Orison and its three neighbors on a plan sheet (Nadia is studying this building) |
| `bottles` | Empties colonizing a surface | Lathe long-necks or drink cans (`cans`), one always fallen |

## Godot conductor props (procedural, in `game/scripts/props/`)

| Prop | Typology referenced | Identity details |
|---|---|---|
| Radiator | Classic four-column cast-iron sections | 9 sections × 4 round columns, bulged headers, feet, supply elbow, brass valve wheel |
| Washer | 1960s coin-laundry front-loader | Chrome torus porthole, dark drum glass, program dial with pointer, soap hatch, kick plate |
| Desk lamp | Sprung articulated task lamp | Stepped weighted base, two angled arms with elbow, spun dome shade, visible bulb |
| Corridor light | Enamel batten fluorescent | Exposed tube, end caps, starter can, pull chain |
| Speaker | Salvage studio monitor | Conical woofer with surround and dust cap, horn tweeter, bass port, grille pegs |
| Box fan | Mid-century ring-shroud floor fan | Four pitched blades on a hub, radial wire guard, cradle feet, speed switch |
| Fridge (4B) | Matches `fridge50` | Same crown steps, chrome pull, latch, badge — the prop and the library agree |
| Boiler | Riveted vertical drum | Band seams, domed crown, dogged fire door, brass-ringed gauge, flue and relief pipe |
| Monitors | Modern thin-bezel pair | Fork stands, cable drops, power pips |
| Doors | Stile-and-rail four-panel leaves | Recessed panel fields both faces, brass lever on rosette, keyhole escutcheon |

Regeneration: `python art/data/gen_layout.py` →
`blender -b -P art/blender/scripts/build_orison.py` → copy JSONs → import.
