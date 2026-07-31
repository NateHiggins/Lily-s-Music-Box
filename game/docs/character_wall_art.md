# Character Wall-Art Library

The Orison now has a second character-art layer: 20 posters, signs,
paintings, diagrams, and found artifacts placed in resident apartments.
Unlike the framed memory images, these objects show taste, politics,
occupation, coping habits, and the things residents have stolen or kept.

The runtime catalog is `res://data/character_wall_art.json`. Each entry
selects one quadrant of a 2x2 atlas and gives its apartment, wall, and
position. The five source atlases live in
`res://assets/building/textures/character_wall_art/`.

At load time each selected quadrant is copied into an isolated image texture
with a protected inset. This prevents filtering or mipmaps from exposing the
other three atlas panels. Wall transforms also apply an inward clearance,
room-facing rotation, and authored hanging height so frames do not sit
coplanar with or disappear into walls.

## Inventory

- Evelyn: “GOOD ENOUGH CAN HOLD” school print
- Teresa: chipped “QUIET PLEASE” hospital sign
- Mina: *THE UNSAID* art-film poster
- Lena: “VISIBLE MENDS” textile-union print
- Juno: “OPEN CHANNEL” bootleg gig poster
- Malcolm: antique propagation plate
- Omar: exploded toaster repair diagram
- Rhea: “ONE BAD NOTE” lounge poster
- Peter: “PROCEED UNCERTAIN” bureaucratic motivational poster
- Cam: stolen “BIKE ROUTE” street sign
- Noel: *ORDINARY OBJECTS* gallery poster
- transient guests: impossible “YOU ARE HERE” motel escape map
- Nadia: “PEOPLE LIVE HERE” housing-justice poster
- Cal: “SIGNAL RECEIVED” QSL card
- Iris: original impossible-fold color-field painting
- Sacha: “LOOK FIRST” darkroom contact sheet
- Jonah: “BEGIN ANYWHERE” print and altered “WORDS MISSING” library sign
- Mae: “PROVENANCE UNKNOWN” auction broadside and object genealogy

## Generation prompt pattern

Built-in ImageGen was used in stylized-concept mode. Each prompt requested
an exact 2x2 atlas of complete, front-facing, square-scanned artifacts with
black divider gutters, visible worn edges, no room background, no people,
no brands, and no extra text. Individual panels specified the resident,
artifact history, printing process, palette, wear, and exact permitted text.
