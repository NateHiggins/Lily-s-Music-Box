# Found Art Library

This library repurposes the strongest original images from `assets/2d art` into
twelve compressed 2×2 WebP atlases. The source archive is deliberately ignored
by Godot; only these optimized derivatives ship into the scene.

- `posters_01`–`posters_04`: apartment posters, occult ephemera, gig art
- `fine_art_01`–`fine_art_02`: framed paintings and inherited artwork
- `editorial_01`–`editorial_03`: magazines, zines, catalogs, loose paper
- `screens_01`–`screens_02`: monitor desktops, broadcasts, strange interfaces
- `billboards_01`: large-format exterior advertising

Atlas cells use `(column, row)` coordinates from `(0,0)` at upper left. Runtime
placement is defined in `data/found_art_catalog.json`. `StoryDecal` and
`CharacterMemoryArt` crop each cell with a small inset to prevent mip bleeding.

The curated source archive contains 48 user-created masters. Obvious franchise
likenesses, explicit material, weak duplicates, and images without a useful
environmental storytelling role were intentionally excluded.
