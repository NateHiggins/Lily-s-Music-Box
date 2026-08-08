"""
games/lilys_music_box/tilesets.py
-----------------------------------
ImageTilesetProvider: loads tile PNGs from an assets/tilesets/<id>/ directory
and scales them to the engine's display tile size (32×32).

When an image file is missing the provider falls back to a palette of solid
colours so the tileset switch is always visually distinct — even before the
full image set is generated.

Standard file layout within any tileset directory (mirrors escher_foyer):
  void/void_open.png          → background tile (tiled across full room)
  floor/floor_surface.png     → solid floor tile
  wall/wall_left_face.png     → wall tile
  stair/stair_ascending_right.png  → platform tile (reused)

NPCs, player, objectives and updraft are always drawn by the game's
LilyArtProvider (art style stays consistent — only the world geometry changes).
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

import pygame

if TYPE_CHECKING:
    pass   # avoid circular imports


# ── Palette fallback descriptor ───────────────────────────────────────────────

@dataclass
class TilesetPalette:
    """
    Procedurally rendered colours used when image files are absent.
    Gives each tileset a distinct look from day one so the swap is visible.
    """
    bg_color:    tuple[int, int, int]
    floor_body:  tuple[int, int, int]
    floor_top:   tuple[int, int, int]
    wall_color:  tuple[int, int, int]
    ghost_color: tuple[int, int, int, int]   # RGBA


# Pre-defined palettes — one per registered tileset

PALETTES: dict[str, TilesetPalette] = {
    # Escher: monochrome paper — mostly handled by images; this is the fallback
    "escher_foyer": TilesetPalette(
        bg_color   = (235, 232, 225),
        floor_body = (100, 95, 88),
        floor_top  = (180, 175, 168),
        wall_color = (60, 55, 52),
        ghost_color= (140, 130, 120, 45),
    ),
    # Klimt: warm gold field
    "klimt_dining": TilesetPalette(
        bg_color   = (200, 155, 20),
        floor_body = (61, 28, 2),
        floor_top  = (212, 160, 23),
        wall_color = (45, 20, 2),
        ghost_color= (212, 160, 23, 50),
    ),
    # Guardian Gothic: dark stone
    "guardian_gothic": TilesetPalette(
        bg_color   = (28, 26, 38),
        floor_body = (55, 52, 68),
        floor_top  = (90, 85, 110),
        wall_color = (35, 32, 45),
        ghost_color= (90, 85, 110, 45),
    ),
    # Lily Bedroom: deep navy / starfield
    "lily_bedroom": TilesetPalette(
        bg_color   = (10, 10, 28),
        floor_body = (35, 32, 60),
        floor_top  = (100, 95, 150),
        wall_color = (20, 18, 40),
        ghost_color= (100, 95, 150, 45),
    ),
}

_DEFAULT_PALETTE = TilesetPalette(
    bg_color   = (20, 16, 28),
    floor_body = (60, 55, 70),
    floor_top  = (100, 90, 110),
    wall_color = (40, 36, 50),
    ghost_color= (100, 90, 110, 45),
)


# ── Colour helpers ────────────────────────────────────────────────────────────

def _lighten(color: tuple[int, int, int], amount: int) -> tuple[int, int, int]:
    """Clamp-add amount to each RGB channel."""
    return tuple(min(255, c + amount) for c in color)  # type: ignore[return-value]


def _auto_contrast(surf: pygame.Surface) -> pygame.Surface:
    """
    Stretch the brightness range of a small tile surface to [0, 255].

    WHY: source tile images are typically detailed line-art (e.g. Escher) on a
    white background.  Smoothscaling from 1000+ px down to 32 px averages the
    dark lines away to near-white.  This function finds the compressed range
    (e.g. 248–255) and stretches it back to full contrast so the line-work is
    again visible.

    Greyscale-normalises the result; preserves hue when the source has a colour
    tint by scaling each channel uniformly around the per-pixel average.

    No-op when the existing brightness range is already >= 40 units (the image
    already has adequate contrast and does not need treatment).
    """
    w, h = surf.get_size()
    lo, hi = 255, 0
    for x in range(w):
        for y in range(h):
            r, g, b = surf.get_at((x, y))[:3]
            v = (r + g + b) // 3
            if v < lo:
                lo = v
            if v > hi:
                hi = v
    span = hi - lo
    if span >= 40 or span < 2:
        return surf          # already good, or completely uniform
    scale = 255.0 / span
    out = surf.copy()
    for x in range(w):
        for y in range(h):
            r, g, b = surf.get_at((x, y))[:3]
            v = max(0, min(255, int(((r + g + b) // 3 - lo) * scale)))
            out.set_at((x, y), (v, v, v))
    return out


# ── Image-based tileset provider ──────────────────────────────────────────────

class ImageTilesetProvider:
    """
    Loads tile images from a named tileset directory.
    Scales every image from source size (typically 512×512) to display size
    using smooth downscaling.

    Falls back to solid-colour procedural tiles for any missing file.
    NPC / player / objective / updraft calls are always delegated to the
    passed-in `npc_art` provider so character art stays consistent across
    tileset swaps.
    """

    # Standard relative paths within any tileset directory.
    # Each key maps a tile role to the asset path inside the tileset folder.
    # Missing files fall back to the palette-based procedural variant.
    # Every key here maps a tile role → relative path inside the tileset dir.
    # Missing files fall back gracefully (decorative_tile returns None → bg).
    # Verified against escher_foyer asset inventory — do not add paths that
    # don't exist in at least one tileset directory.
    _FILE_MAP = {
        # ── Structural (present in all tilesets) ─────────────────────────────
        "bg":               "void/void_open.png",
        "floor_surface":    "floor/floor_surface.png",
        "floor_left_edge":  "floor/floor_surface_left_edge.png",
        "floor_right_edge": "floor/floor_surface_right_edge.png",
        "floor_slab":       "floor/floor_slab.png",
        "wall_left":        "wall/wall_left_face.png",
        "wall_right":       "wall/wall_right_face.png",
        "ceiling":          "ceiling/ceiling_slab.png",
        "floor":            "floor/floor_surface.png",   # legacy alias
        # ── Ornamental — stairs (escher_foyer) ───────────────────────────────
        "stair_right":      "stair/stair_ascending_right.png",
        "stair_left":       "stair/stair_ascending_left.png",
        "stair_deep":       "stair/stair_step_deep.png",
        "stair_landing":    "stair/stair_landing_flat.png",
        "stair_turn_ne":    "stair/stair_turn_ne.png",
        "stair_turn_nw":    "stair/stair_turn_nw.png",
        "stair_turn_se":    "stair/stair_turn_se.png",
        "stair_turn_sw":    "stair/stair_turn_sw.png",
        # ── Ornamental — pillars (escher_foyer) ──────────────────────────────
        "pillar_top":       "pillar/pillar_cap_top.png",
        "pillar_shaft":     "pillar/pillar_shaft.png",
        "pillar_base":      "pillar/pillar_cap_bottom.png",
        # ── Ornamental — arches (escher_foyer) ───────────────────────────────
        "arch_left":        "arch/arch_left_springer.png",
        "arch_right":       "arch/arch_right_springer.png",
        "arch_keystone":    "arch/arch_keystone.png",
        # ── Special / impossible geometry (escher_foyer) ─────────────────────
        # impossible_floor_ceiling: floor surface on top, ceiling below —
        #   the literal Escher Relativity motif for gravity-ambiguous zones.
        "impossible_floor": "special/impossible_floor_ceiling.png",
        # Gravity transition tiles: suggest a staircase crossing into a gravity
        # that runs perpendicular to the player's current orientation.
        "gravity_east":     "special/transition_gravity_east.png",
        "gravity_west":     "special/transition_gravity_west.png",
        # window_void: a framed stone opening looking out into void space.
        "window_void":      "special/window_void.png",
    }

    def __init__(
        self,
        tileset_id: str,
        tileset_path: Path,
        npc_art,                # LilyArtProvider — handles characters
    ) -> None:
        self.tileset_id   = tileset_id
        self.tileset_path = Path(tileset_path)
        self.npc_art      = npc_art
        self.palette      = PALETTES.get(tileset_id, _DEFAULT_PALETTE)
        self._img_cache: dict[str, pygame.Surface | None] = {}

        # Escher monster tessellation — pre-scaled once, then cropped per cell.
        # None until first escher air_layout call; persists for the session.
        self._tess_surf:  pygame.Surface | None = None
        self._tess_cache: dict[tuple, pygame.Surface] = {}

    # ── Internal image loading ────────────────────────────────────────────────

    @staticmethod
    def _white_to_alpha(surf: pygame.Surface, threshold: int = 230) -> pygame.Surface:
        """
        Return a copy of *surf* with near-white pixels made fully transparent.

        WHY: Escher tiles are black line-art on a white background.  Making white
        transparent lets the background (or tessellation) show through while the
        ink lines remain opaque.  Conversion happens at SOURCE resolution, before
        smoothscale, so downsampling naturally blends dark ink edges into
        semi-transparent pixels rather than into muddy grey.

        threshold: per-channel minimum value for "white enough" (0–255).
        Any pixel where R, G, and B are all ≥ threshold becomes alpha=0.
        """
        # Convert to per-pixel alpha so we can write the alpha channel.
        out = surf.convert_alpha()
        # pygame.PixelArray gives direct pixel access without numpy.
        for x in range(out.get_width()):
            for y in range(out.get_height()):
                r, g, b, a = out.get_at((x, y))
                if r >= threshold and g >= threshold and b >= threshold:
                    out.set_at((x, y), (r, g, b, 0))
        return out

    def _load(self, rel_path: str) -> pygame.Surface | None:
        """Load and cache a raw image. Returns None if file is absent."""
        if rel_path in self._img_cache:
            return self._img_cache[rel_path]
        full = self.tileset_path / rel_path
        if not full.exists():
            self._img_cache[rel_path] = None
            return None
        try:
            surf = pygame.image.load(str(full)).convert()
            self._img_cache[rel_path] = surf
            return surf
        except Exception:
            self._img_cache[rel_path] = None
            return None

    def _load_alpha(self, rel_path: str) -> pygame.Surface | None:
        """
        Load, white-strip, and cache a decorative image with per-pixel alpha.

        WHY separate from _load(): structural tiles (floor, wall, bg) must
        remain opaque so the base layer is never transparent.  White-stripping
        is only wanted for ornamental air-cell tiles where the Escher line-art
        should float on top of the tessellation background.
        """
        cache_key = rel_path + ":alpha"
        if cache_key in self._img_cache:
            return self._img_cache[cache_key]
        raw = self._load(rel_path)   # prime the opaque cache too
        if raw is None:
            self._img_cache[cache_key] = None
            return None
        surf = self._white_to_alpha(raw)
        self._img_cache[cache_key] = surf
        return surf

    def _scaled(self, role: str, w: int, h: int) -> pygame.Surface | None:
        # White-stripped so tessellation shows through any white fill in the art.
        raw = self._load_alpha(self._FILE_MAP[role])
        if raw is None:
            return None
        scaled = pygame.transform.smoothscale(raw, (w, h))
        return _auto_contrast(scaled)

    # ── TileArtProvider interface ─────────────────────────────────────────────

    def _clear(self, w: int, h: int) -> pygame.Surface:
        """Fully transparent tile — used when structural tiles should be invisible."""
        s = pygame.Surface((w, h), pygame.SRCALPHA)
        s.fill((0, 0, 0, 0))
        return s

    @property
    def _invisible(self) -> bool:
        """True when this tileset renders only the tessellation, no stone geometry."""
        return self.tileset_id == "escher_foyer"

    # ── Ornamental tile dispatch ──────────────────────────────────────────────

    def decorative_tile(self, role: str, tile_w: int, tile_h: int) -> pygame.Surface | None:
        """
        Load any tile by its role key — used for ornamental air-cell decoration.
        Returns None if the file is absent so the renderer can fall back to bg.

        Handles position-encoded tessellation roles of the form "tess:{col}:{row}".
        Each such role produces a unique crop from the Escher monster tessellation
        image, letting the full pattern tile continuously across all air cells.
        Crops are cached individually so the full image is scaled only once.
        """
        # ── Escher monster tessellation ───────────────────────────────────────
        if role.startswith("tess:"):
            _, c_str, r_str = role.split(":")
            col, row = int(c_str), int(r_str)
            key = (col, row, tile_w, tile_h)
            if key in self._tess_cache:
                return self._tess_cache[key]
            # Load and scale the tessellation image on first use.
            # One repeat is scaled to 4×4 tiles; modulo wrapping tiles it
            # continuously across the room at the same density as other tiles.
            if self._tess_surf is None:
                tess_path = Path(__file__).parent / "mcescherTile" / "escher monster tesselation.png"
                if not tess_path.exists():
                    return None
                try:
                    raw = pygame.image.load(str(tess_path)).convert()
                except Exception:
                    return None
                # Crop a small border from the source image before scaling.
                # The original PNG has a thin dark frame that becomes a visible
                # grid line at every tile-repeat boundary when tiled.  Removing
                # ~3 % from each edge cuts off that frame so the scaled content
                # tiles seamlessly.
                rw, rh = raw.get_size()
                bx = max(1, rw // 30)
                by = max(1, rh // 30)
                raw = raw.subsurface(
                    pygame.Rect(bx, by, rw - 2 * bx, rh - 2 * by)
                ).copy()
                # Scale to tile-grid size, keep opaque — the tessellation is
                # the background layer; ornamental tiles blit on top of it.
                target = 4 * tile_w   # one repeat = 4×4 tiles (160×160 px)
                self._tess_surf = pygame.transform.smoothscale(raw, (target, target))
            tess = self._tess_surf
            tw, th = tess.get_size()
            src_x = (col * tile_w) % tw
            src_y = (row * tile_h) % th
            crop = pygame.Surface((tile_w, tile_h))
            crop.blit(tess, (0, 0), (src_x, src_y, tile_w, tile_h))
            self._tess_cache[key] = crop
            return crop

        # ── Standard role lookup ──────────────────────────────────────────────
        rel = self._FILE_MAP.get(role)
        if rel is None:
            return None
        raw = self._load_alpha(rel)   # white-stripped per-pixel-alpha version
        if raw is None:
            return None
        scaled = pygame.transform.smoothscale(raw, (tile_w, tile_h))
        return _auto_contrast(scaled)

    # ── Air decoration layout ─────────────────────────────────────────────────

    def air_layout(
        self,
        solid_tiles: "set[tuple[int,int]]",
        cols: int,
        rows: int,
        seed: int,
    ) -> "dict[tuple[int,int], str]":
        """Dispatch to the tileset-specific decoration generator."""
        if self.tileset_id == "escher_foyer":
            return self._escher_air_layout(solid_tiles, cols, rows, seed)
        # Other tilesets use plain bg tiles for air — extend here when those
        # tileset directories gain their own ornamental assets.
        return {}

    def _escher_air_layout(
        self,
        solid: "set[tuple[int,int]]",
        cols: int,
        rows: int,
        seed: int,
    ) -> "dict[tuple[int,int], str]":
        """All air cells receive the monster tessellation; no stone ornaments."""
        deco: dict[tuple[int, int], str] = {}
        floor_row = rows - 3

        def is_air(c: int, r: int) -> bool:
            return (
                1 <= c <= cols - 2
                and 1 <= r <= floor_row - 1
                and (c, r) not in solid
            )

        for r in range(1, floor_row):
            for c in range(1, cols - 1):
                if is_air(c, r):
                    deco[(c, r)] = f"tess:{c}:{r}"
        return deco

    def bg_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        """Opaque fallback for any air cell not covered by the deco map."""
        if self._invisible:
            return self._clear(tile_w, tile_h)
        raw = self._load(self._FILE_MAP["bg"])
        p = self.palette
        if raw is None:
            surf = pygame.Surface((tile_w, tile_h))
            surf.fill(p.bg_color)
            return surf
        scaled = pygame.transform.smoothscale(raw, (tile_w, tile_h))
        return _auto_contrast(scaled)

    def _tess_background_tile(self, tile_size: int) -> pygame.Surface:
        """
        Return a scaled, opaque tessellation repeat tile for use in background().
        Cached in _tess_surf; reuses the same surface if already built at the
        same size so background() can call this without re-loading.
        """
        if self._tess_surf is not None and self._tess_surf.get_width() == tile_size:
            return self._tess_surf
        tess_path = Path(__file__).parent / "mcescherTile" / "escher monster tesselation.png"
        if not tess_path.exists():
            return None
        try:
            raw = pygame.image.load(str(tess_path)).convert()
        except Exception:
            return None
        # Crop the same border fraction as the renderer path so both uses of
        # the tessellation tile seamlessly — no dark frame at repeat boundaries.
        rw, rh = raw.get_size()
        bx, by = max(1, rw // 30), max(1, rh // 30)
        raw = raw.subsurface(pygame.Rect(bx, by, rw - 2 * bx, rh - 2 * by)).copy()
        self._tess_surf = pygame.transform.smoothscale(raw, (tile_size, tile_size))
        # Invalidate the per-cell crop cache; a size change would break old crops.
        self._tess_cache.clear()
        return self._tess_surf

    def background(self, biome: str, width: int, height: int) -> pygame.Surface:
        p = self.palette
        surf = pygame.Surface((width, height))

        # ── Escher foyer: tessellation as full-room backdrop ──────────────────
        # The monster tessellation tiles behind every other layer. All structural
        # and decorative tiles are white-stripped (transparent white) so the
        # pattern shows through everywhere the original art had a white background.
        if self.tileset_id == "escher_foyer":
            TILE_SIZE = 4 * 40   # 4×4 game-tiles per repeat (160×160 px)
            tess = self._tess_background_tile(TILE_SIZE)
            if tess is not None:
                for ty in range(0, height, TILE_SIZE):
                    for tx in range(0, width, TILE_SIZE):
                        surf.blit(tess, (tx, ty))
                return surf
            # Fall through to solid-colour if image is missing.

        # ── Generic fallback ──────────────────────────────────────────────────
        raw = self._load(self._FILE_MAP["bg"])
        if raw is None:
            surf.fill(p.bg_color)
            for y in range(0, height, 2):
                frac = 1.0 - (y / height) * 0.25
                r = min(255, int(p.bg_color[0] * frac + 15))
                g = min(255, int(p.bg_color[1] * frac + 10))
                b = min(255, int(p.bg_color[2] * frac + 20))
                pygame.draw.line(surf, (r, g, b), (0, y), (width, y))
            return surf

        tile_w, tile_h = 32, 32
        scaled_tile = pygame.transform.smoothscale(raw, (tile_w, tile_h))
        for ty in range(0, height, tile_h):
            for tx in range(0, width, tile_w):
                surf.blit(scaled_tile, (tx, ty))
        return surf

    def floor_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        if self._invisible:
            return self._clear(tile_w, tile_h)
        s = self._scaled("floor", tile_w, tile_h)
        if s:
            return s
        p = self.palette
        surf = pygame.Surface((tile_w, tile_h))
        surf.fill(p.floor_body)
        pygame.draw.rect(surf, p.floor_top, (0, 0, tile_w, 4))
        return surf

    def platform_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        if self._invisible:
            return self._clear(tile_w, tile_h)
        s = self._scaled("platform", tile_w, tile_h)
        if s:
            return s
        p = self.palette
        surf = pygame.Surface((tile_w, tile_h))
        surf.fill(p.floor_body)
        pygame.draw.rect(surf, p.floor_top, (0, 0, tile_w, 3))
        return surf

    def ghost_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        if self._invisible:
            return self._clear(tile_w, tile_h)
        p = self.palette
        surf = pygame.Surface((tile_w, tile_h), pygame.SRCALPHA)
        surf.fill(p.ghost_color)
        pygame.draw.rect(surf, (*p.ghost_color[:3], 90), (0, 0, tile_w, 2))
        return surf

    def wall_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        if self._invisible:
            return self._clear(tile_w, tile_h)
        s = self._scaled("wall_left", tile_w, tile_h)
        if s:
            return s
        p = self.palette
        surf = pygame.Surface((tile_w, tile_h))
        surf.fill(p.wall_color)
        return surf

    def wall_right_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        if self._invisible:
            return self._clear(tile_w, tile_h)
        s = self._scaled("wall_right", tile_w, tile_h)
        if s:
            return s
        # Fallback: horizontally flip the left wall image if available,
        # otherwise use plain wall palette colour with left accent.
        left = self._scaled("wall_left", tile_w, tile_h)
        if left:
            return pygame.transform.flip(left, True, False)
        p = self.palette
        surf = pygame.Surface((tile_w, tile_h))
        surf.fill(p.wall_color)
        pygame.draw.line(surf, _lighten(p.wall_color, 30), (0, 0), (0, tile_h))
        return surf

    def ceiling_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        if self._invisible:
            return self._clear(tile_w, tile_h)
        s = self._scaled("ceiling", tile_w, tile_h)
        if s:
            return s
        p = self.palette
        surf = pygame.Surface((tile_w, tile_h))
        surf.fill(p.wall_color)
        pygame.draw.line(surf, _lighten(p.wall_color, 40), (0, tile_h - 1), (tile_w, tile_h - 1))
        return surf

    def floor_slab_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        if self._invisible:
            return self._clear(tile_w, tile_h)
        s = self._scaled("floor_slab", tile_w, tile_h)
        if s:
            return s
        p = self.palette
        surf = pygame.Surface((tile_w, tile_h))
        surf.fill(p.floor_body)
        return surf

    def floor_left_edge_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        if self._invisible:
            return self._clear(tile_w, tile_h)
        s = self._scaled("floor_left_edge", tile_w, tile_h)
        if s:
            return s
        # Fallback: floor surface with a left-edge accent line
        surf = self.floor_tile(tile_w, tile_h)
        pygame.draw.line(surf, self.palette.floor_top, (0, 0), (0, tile_h))
        return surf

    def floor_right_edge_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        if self._invisible:
            return self._clear(tile_w, tile_h)
        s = self._scaled("floor_right_edge", tile_w, tile_h)
        if s:
            return s
        surf = self.floor_tile(tile_w, tile_h)
        pygame.draw.line(surf, self.palette.floor_top, (tile_w - 1, 0), (tile_w - 1, tile_h))
        return surf

    # Characters always delegate to npc_art — they don't change with tileset
    def npc_sprite(self, npc_id: str, width: int, height: int) -> pygame.Surface:
        return self.npc_art.npc_sprite(npc_id, width, height)

    def player_sprite(self, width: int, height: int) -> pygame.Surface:
        return self.npc_art.player_sprite(width, height)

    def objective_sprite(self, size: int) -> pygame.Surface:
        return self.npc_art.objective_sprite(size)

    def updraft_band(self, width: int, height: int, alpha_frac: float) -> pygame.Surface:
        return self.npc_art.updraft_band(width, height, alpha_frac)


# ── Guardian Gothic Swing Tileset ─────────────────────────────────────────────


def _guardian_air_layout(
    solid: "set[tuple[int,int]]",
    cols: int,
    rows: int,
    seed: int,
) -> "tuple[dict[tuple[int,int], str], set[tuple[int,int]]]":
    """
    Generate the Guardian Gothic decoration map and swing anchor set.

    Tile roles produced:
      pulley_node    — ceiling-hung ring; primary swing anchor (row 1–2).
      branch_node    — mid-air corbel; secondary grab point (upper 60 % of air).
      arch_anchor    — wall-adjacent arch springer; structural decoration only.
      ground_foliage — dense foliage on the ground zone; marks the hidden garden.
                       Non-climbable / non-anchor; purely visual.

    Anchor set returned contains all pulley_node and branch_node cells — read by
    SwingAscendAbility.on_room_enter() to know where chains can attach.

    Spacing rules guarantee no conventional jump is required:
      • pulley_node columns are placed every PULLEY_SPACING cols (≤ ASCEND_H_RANGE
        search width of the swing ability) so every floor position is within reach.
      • branch_nodes fill the mid-height layer to give release-and-reattach paths.
    """
    rng           = random.Random(seed ^ 0xF0E1D2C3)
    floor_row     = rows - 3
    PULLEY_SPACING = 5    # columns between pulley nodes (≤ ASCEND_H_RANGE=6)
    layout: dict[tuple[int, int], str] = {}
    anchor_cells: set[tuple[int, int]] = set()
    occupied: set[tuple[int, int]]     = set(solid)
    for r in range(rows):
        occupied.add((0, r))
        occupied.add((cols - 1, r))
    for c in range(cols):
        occupied.add((c, 0))

    # ── 1. Ceiling pulley nodes ───────────────────────────────────────────────
    # Evenly spaced across the ceiling row so the swing ability can always find
    # an anchor within its horizontal search window regardless of player position.
    for c in range(2, cols - 2, PULLEY_SPACING):
        # Prefer row 1 (just below ceiling); fall back to row 2 if blocked.
        for r in (1, 2):
            cell = (c, r)
            if cell not in occupied and cell not in solid:
                layout[cell]  = "pulley_node"
                anchor_cells.add(cell)
                occupied.add(cell)
                break

    # ── 2. Branch nodes — mid-air grab points ────────────────────────────────
    # Fill the upper 60 % of the air space with scattered branch nodes.
    # Two passes: a regular grid pass (guarantees coverage) then a random-jitter
    # pass (breaks grid regularity so the room doesn't look procedurally stamped).
    mid_top    = 3
    mid_bot    = max(mid_top + 1, int(floor_row * 0.60))

    # Grid pass: every 4 columns, every 3 rows in the mid band
    for c in range(3, cols - 3, 4):
        for r in range(mid_top, mid_bot, 3):
            cell = (c + rng.randint(-1, 1), r + rng.randint(-1, 1))
            cc, cr = max(1, min(cols - 2, cell[0])), max(1, min(rows - 2, cell[1]))
            cell = (cc, cr)
            if cell not in occupied:
                layout[cell]  = "branch_node"
                anchor_cells.add(cell)
                occupied.add(cell)

    # ── 3. Arch anchors — near-wall decorative springers ─────────────────────
    # Placed at left and right walls in the upper third to suggest a gothic arch
    # framing the hidden garden below.  Non-anchor (purely visual).
    arch_rows = [max(1, floor_row // 4), max(1, floor_row // 2)]
    for ar in arch_rows:
        for ac in (1, cols - 2):
            cell = (ac, ar)
            if cell not in occupied:
                layout[cell] = "arch_anchor"
                occupied.add(cell)

    # ── 4. Ground foliage — marks the hidden garden zone ─────────────────────
    # Cover the lower 2 air rows (just above the floor) with foliage silhouettes.
    # These are visual only — no collision, no anchor participation.
    for r in range(floor_row - 2, floor_row):
        for c in range(1, cols - 1):
            cell = (c, r)
            if cell not in occupied and cell not in solid:
                if rng.random() < 0.70:
                    layout[cell] = "ground_foliage"
                    occupied.add(cell)

    return layout, anchor_cells


class GuardianGothicTilesetProvider:
    """
    Tileset provider for guardian_gothic.

    Loads structural tiles from the guardian_gothic asset directory.
    Air cells are decorated with swing-anchor geometry:
      pulley_node  — ceiling rings for chain attachment
      branch_node  — mid-air corbels for grab-and-release traversal
      arch_anchor  — gothic arch springers (decorative)
      ground_foliage — foliage silhouettes marking the hidden garden

    _anchor_cells is populated by air_layout() and read by SwingAscendAbility
    on room entry to know every valid chain-attachment point.

    Character rendering always delegates to npc_art for cross-tileset consistency.
    """

    # Roles that can serve as chain-attachment anchors for the swing ability.
    # Only pulley_node and branch_node participate — arch_anchor and foliage are
    # visual-only and must never be offered as grab targets.
    SWING_ANCHOR_ROLES: frozenset[str] = frozenset({"pulley_node", "branch_node"})

    # Procedural fallback specs for each decorative role.
    # Tuple: (fill_rgb, accent_rgb, shape)
    # shape: "circle" | "rect" | "diamond" | "none"
    _PROC_TILES: dict[str, tuple] = {
        "pulley_node":    ((55, 52, 68),  (160, 150, 200), "circle"),
        "branch_node":    ((42, 40, 54),  (120, 115, 150), "diamond"),
        "arch_anchor":    ((35, 32, 45),  (100, 95, 130),  "rect"),
        "ground_foliage": ((30, 55, 30),  (50,  90,  45),  "none"),
    }

    def __init__(self, tileset_path: Path, npc_art) -> None:
        self.tileset_path = Path(tileset_path)
        self.npc_art      = npc_art
        self.palette      = PALETTES.get("guardian_gothic", _DEFAULT_PALETTE)
        self._img_cache: dict[str, pygame.Surface | None] = {}
        # Populated by air_layout(); read by SwingAscendAbility.on_room_enter().
        # Contains every (col, row) that is a valid chain-attachment point in the
        # current room.  Rebuilt on each room change.
        self._anchor_cells: set[tuple[int, int]] = set()
        # Last computed deco map — retained for debug overlay.
        self._last_deco: dict[tuple[int, int], str] = {}
        # Delegate structural tiles to a shared ImageTilesetProvider so all the
        # floor/wall/ceiling asset-loading logic isn't duplicated here.
        self._image_provider = ImageTilesetProvider(
            "guardian_gothic", tileset_path, npc_art
        )

    # ── Image loading ─────────────────────────────────────────────────────────

    def _load(self, filename: str) -> "pygame.Surface | None":
        if filename in self._img_cache:
            return self._img_cache[filename]
        full = self.tileset_path / filename
        if not full.exists():
            self._img_cache[filename] = None
            return None
        try:
            surf = pygame.image.load(str(full)).convert()
            self._img_cache[filename] = surf
            return surf
        except Exception:
            self._img_cache[filename] = None
            return None

    # ── TileArtProvider protocol — structural tiles via ImageTilesetProvider ──

    def bg_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self._image_provider.bg_tile(tile_w, tile_h)

    def floor_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self._image_provider.floor_tile(tile_w, tile_h)

    def floor_slab_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self._image_provider.floor_slab_tile(tile_w, tile_h)

    def floor_left_edge_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self._image_provider.floor_left_edge_tile(tile_w, tile_h)

    def floor_right_edge_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self._image_provider.floor_right_edge_tile(tile_w, tile_h)

    def platform_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self._image_provider.platform_tile(tile_w, tile_h)

    def ghost_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self._image_provider.ghost_tile(tile_w, tile_h)

    def wall_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self._image_provider.wall_tile(tile_w, tile_h)

    def wall_right_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self._image_provider.wall_right_tile(tile_w, tile_h)

    def ceiling_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self._image_provider.ceiling_tile(tile_w, tile_h)

    def background(self, biome: str, width: int, height: int) -> pygame.Surface:
        return self._image_provider.background(biome, width, height)

    # ── Decorative tiles (procedural fallback for swing ornaments) ────────────

    def decorative_tile(self, role: str, tile_w: int, tile_h: int) -> "pygame.Surface | None":
        """
        Render a swing-specific decorative tile.

        Tries to load a PNG from the tileset directory first (e.g. pulley_node.png).
        Falls back to a procedural surface keyed on _PROC_TILES when the file is
        absent — this keeps anchor cells visually distinct during development.

        ground_foliage uses a procedural green smear regardless; it intentionally
        has no image backing because FragonardGardenFlow draws foliage particles on
        top of whatever the tileset places here.
        """
        spec = self._PROC_TILES.get(role)
        if spec is None:
            return None

        fill_rgb, accent_rgb, shape = spec
        surf = pygame.Surface((tile_w, tile_h), pygame.SRCALPHA)

        if role == "ground_foliage":
            # Translucent dark-green smear — very low opacity; the style layer
            # draws rich foliage particles on top.
            surf.fill((*fill_rgb, 80))
            return surf

        surf.fill((*fill_rgb, 210))
        cx, cy = tile_w // 2, tile_h // 2
        r = min(tile_w, tile_h) // 3

        if shape == "circle":
            pygame.draw.circle(surf, (*accent_rgb, 230), (cx, cy), r)
            # Ring outline — suggests a metal chain ring / pulley bracket
            pygame.draw.circle(surf, (*accent_rgb, 120), (cx, cy), r, 2)
        elif shape == "diamond":
            pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
            pygame.draw.polygon(surf, (*accent_rgb, 220), pts)
        elif shape == "rect":
            pad = max(2, tile_w // 5)
            pygame.draw.rect(surf, (*accent_rgb, 200),
                             (pad, pad, tile_w - pad * 2, tile_h - pad * 2))

        return surf

    def air_layout(
        self,
        solid_tiles: "set[tuple[int,int]]",
        cols: int,
        rows: int,
        seed: int,
    ) -> "dict[tuple[int,int], str]":
        """Build the swing-anchor decoration map and populate _anchor_cells."""
        deco, anchor_cells  = _guardian_air_layout(solid_tiles, cols, rows, seed)
        self._anchor_cells  = anchor_cells
        self._last_deco     = deco
        return deco

    # ── Character delegation ──────────────────────────────────────────────────

    def npc_sprite(self, npc_id: str, width: int, height: int) -> pygame.Surface:
        return self.npc_art.npc_sprite(npc_id, width, height)

    def player_sprite(self, width: int, height: int) -> pygame.Surface:
        return self.npc_art.player_sprite(width, height)

    def objective_sprite(self, size: int) -> pygame.Surface:
        return self.npc_art.objective_sprite(size)

    def updraft_band(self, width: int, height: int, alpha_frac: float) -> pygame.Surface:
        return self.npc_art.updraft_band(width, height, alpha_frac)


# ── Klimt Vine Tileset ────────────────────────────────────────────────────────

# Vine tile port definitions: which edges carry a vine connection.
# Two adjacent cells are valid only if both share a port on their shared edge.
_VINE_PORTS: dict[str, frozenset[str]] = {
    "vine_ns":       frozenset({"N", "S"}),
    "vine_ew":       frozenset({"E", "W"}),
    "vine_ne":       frozenset({"N", "E"}),
    "vine_nw":       frozenset({"N", "W"}),
    "vine_se":       frozenset({"S", "E"}),
    "vine_sw":       frozenset({"S", "W"}),
    "vine_whorl":    frozenset({"N", "S", "E", "W"}),
    "vine_branch":   frozenset({"N", "S", "E"}),
    "vine_branch_w": frozenset({"N", "S", "W"}),
}
# Reverse lookup: port set → tile role
_PORTS_TO_VINE: dict[frozenset[str], str] = {v: k for k, v in _VINE_PORTS.items()}

_OPPOSITE = {"N": "S", "S": "N", "E": "W", "W": "E"}
_DELTA    = {"N": (0, -1), "S": (0, 1), "E": (1, 0), "W": (-1, 0)}

# Roles that must never be marked climbable regardless of anchor proximity.
_ALWAYS_DECORATIVE: frozenset[str] = frozenset({
    "vine_eye", "vine_triangle",
    "vine_tendril",          # non-climbable curl ends
    "mosaic_filler",
    "jewel_cluster",
    "klimt_stair_left", "klimt_stair_right", "klimt_stair_landing",
})


def _compute_anchored_vine_cells(
    layout: "dict[tuple[int,int], str]",
    solid: "set[tuple[int,int]]",
    climbable_roles: "frozenset[str]",
) -> "tuple[set[tuple[int,int]], set[tuple[int,int]]]":
    """
    Flood-fill from vine cells that are directly adjacent to solid structure.

    Returns (anchored_cells, anchor_source_cells) where:
      anchor_source_cells — vine cells touching at least one solid tile neighbour
                            (these are the ROOTED / WALL_ATTACHED / CEILING seeds).
      anchored_cells      — every vine cell reachable from any seed through
                            vine-to-vine adjacency (BFS through the vine graph).

    tree_trunk cells are always anchored seeds because they sit on or grow from
    the floor; the BFS then propagates climbability outward through all connected
    vine connector tiles.

    Any vine cell that is NOT in anchored_cells should be reclassified as
    vine_tendril (decorative, non-climbable).
    """
    vine_cells = {
        cell for cell, role in layout.items()
        if role in climbable_roles and role not in _ALWAYS_DECORATIVE
    }

    # Seeds: vine cells adjacent to at least one solid neighbour
    anchor_sources: set[tuple[int, int]] = set()
    for cell in vine_cells:
        c, r = cell
        for dc, dr in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            if (c + dc, r + dr) in solid:
                anchor_sources.add(cell)
                break

    # BFS outward from seeds through vine adjacency
    visited: set[tuple[int, int]] = set(anchor_sources)
    queue: list[tuple[int, int]] = list(anchor_sources)
    while queue:
        cell = queue.pop()
        c, r = cell
        for dc, dr in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nb = (c + dc, r + dr)
            if nb in vine_cells and nb not in visited:
                visited.add(nb)
                queue.append(nb)

    return visited, anchor_sources


def _grow_vine(
    vine_edges: dict,
    occupied: set,
    cols: int,
    rows: int,
    start_col: int,
    start_row: int,
    incoming: str,
    max_len: int,
    rng: random.Random,
    straight_bias: float = 0.62,
) -> None:
    """
    Grow a vine path starting at (start_col, start_row) where the vine enters
    from the `incoming` direction.

    Mutates vine_edges in place — each reached cell gets a set of port directions.
    Mutates occupied so subsequent vines don't cross or overlap.
    Terminates when max_len is reached, the path hits a wall, or no exits remain.

    straight_bias: probability (0–1) of continuing straight rather than turning.
    Use a high value (≥0.85) for wall-runner vines that must travel far horizontally.
    """
    col, row = start_col, start_row
    travelling = _OPPOSITE[incoming]

    for _ in range(max_len):
        if (col, row) in occupied:
            break
        if not (1 <= col <= cols - 2 and 1 <= row <= rows - 2):
            break

        if (col, row) not in vine_edges:
            vine_edges[(col, row)] = set()
        vine_edges[(col, row)].add(incoming)
        occupied.add((col, row))

        candidates = []
        for d in ("N", "S", "E", "W"):
            if d == incoming:
                continue
            dc, dr = _DELTA[d]
            nc, nr = col + dc, row + dr
            if (nc, nr) not in occupied and 1 <= nc <= cols - 2 and 1 <= nr <= rows - 2:
                candidates.append(d)

        if not candidates:
            break

        if travelling in candidates and rng.random() < straight_bias:
            chosen = travelling
        else:
            chosen = rng.choice(candidates)

        vine_edges[(col, row)].add(chosen)

        dc, dr = _DELTA[chosen]
        col, row = col + dc, row + dr
        incoming   = _OPPOSITE[chosen]
        travelling = chosen


def _klimt_air_layout(
    solid: "set[tuple[int,int]]",
    cols: int,
    rows: int,
    seed: int,
) -> "dict[tuple[int,int], str]":
    """
    Generate the Klimt vine decoration map for all air cells.

    Composition:
      1. Main tree trunk: vertical column one-third from right wall.
      2. Platform trunks: one tree_trunk column per freestanding elevated
         platform, centred on the platform's horizontal span, dropping from
         the platform bottom to the floor.
      3. Vine network:
           - East and west wall-runner vines from the trunk midpoint (high
             straight_bias so they reliably cross to the nearest wall).
           - Wall-touching vines at two extra heights per side: each starts
             at the wall boundary (col 1 or col cols-2) and grows inward,
             giving the impression of vines emerging from the stone walls.
           - Secondary vines seeded from random free cells for organic fill.
      4. Whorl focal ornament: vine_whorl placed in the left-centre region;
         four vines grow outward from it in every cardinal direction.
      5. Vine-edge→tile mapping with eye/triangle special promotions.
      6. Stair run (ascending left) with "The Kiss" landing cap.
    """
    rng = random.Random(seed ^ 0xC0FFEE01)
    floor_row = rows - 3

    # Cells that cannot receive any decoration.
    forbidden: set[tuple[int, int]] = set(solid)
    for r in range(rows):
        forbidden.add((0, r))
        forbidden.add((cols - 1, r))
    for c in range(cols):
        forbidden.add((c, 0))

    layout: dict[tuple[int, int], str] = {}

    # ── 1. Main tree trunk ────────────────────────────────────────────────────
    trunk_col = cols * 2 // 3
    trunk_top = 2
    trunk_bot = floor_row - 1

    for r in range(trunk_top, trunk_bot + 1):
        cell = (trunk_col, r)
        if cell not in forbidden:
            layout[cell] = "tree_trunk"
            forbidden.add(cell)

    # ── 2. Platform trunks ────────────────────────────────────────────────────
    # For every freestanding elevated platform find its horizontal centre and
    # drop a tree_trunk column from just below the platform to the floor.
    # Platforms whose bottom sits directly above the floor (no gap) are skipped.
    def _find_platform_trunks() -> list[tuple[int, int]]:
        """Return (centre_col, bottom_row) for each elevated platform cluster."""
        elevated = {(c, r) for c, r in solid if r < floor_row}
        visited: set[tuple[int, int]] = set()
        results: list[tuple[int, int]] = []

        for start in sorted(elevated):
            if start in visited:
                continue
            # BFS flood-fill to find connected solid component
            component: list[tuple[int, int]] = []
            queue = [start]
            in_queue = {start}
            while queue:
                cell = queue.pop(0)
                if cell in visited or cell not in elevated:
                    continue
                visited.add(cell)
                component.append(cell)
                cc, cr = cell
                for nc, nr in [(cc + 1, cr), (cc - 1, cr), (cc, cr + 1), (cc, cr - 1)]:
                    if (nc, nr) not in in_queue and (nc, nr) not in visited and (nc, nr) in elevated:
                        queue.append((nc, nr))
                        in_queue.add((nc, nr))

            if not component:
                continue

            all_c = [c for c, _ in component]
            all_r = [r for _, r in component]
            centre = (min(all_c) + max(all_c)) // 2
            bottom = max(all_r)

            # Skip if the trunk would have no room (platform slab is directly
            # above the floor) or if the centre lands on the main trunk column.
            if bottom + 1 >= floor_row or centre == trunk_col:
                continue

            results.append((centre, bottom))
        return results

    for plat_centre, plat_bottom in _find_platform_trunks():
        for r in range(plat_bottom + 1, floor_row):
            cell = (plat_centre, r)
            if cell not in forbidden:
                layout[cell] = "tree_trunk"
                forbidden.add(cell)

    # ── 3. Vine network ───────────────────────────────────────────────────────
    vine_edges: dict[tuple[int, int], set[str]] = {}
    occupied = set(forbidden)

    mid_row = (trunk_top + trunk_bot) // 2

    # 3a. Primary upward vine from trunk top
    up_start = (trunk_col, trunk_top - 1)
    if trunk_top > 1 and up_start not in occupied:
        _grow_vine(vine_edges, occupied, cols, rows,
                   up_start[0], up_start[1], incoming="S", max_len=5, rng=rng)

    # 3b. East wall-runner from trunk — high straight_bias so it crosses to
    #     the right wall, giving a continuous horizontal vine line.
    east_start = (trunk_col + 1, mid_row)
    if east_start not in occupied:
        _grow_vine(vine_edges, occupied, cols, rows,
                   east_start[0], east_start[1], incoming="W",
                   max_len=cols, straight_bias=0.88, rng=rng)

    # 3c. West wall-runner from trunk — same idea toward left wall.
    west_start = (trunk_col - 1, mid_row)
    if west_start not in occupied:
        _grow_vine(vine_edges, occupied, cols, rows,
                   west_start[0], west_start[1], incoming="E",
                   max_len=cols, straight_bias=0.88, rng=rng)

    # 3d. Wall-touching vines at two extra heights per side.
    #     Each starts AT the wall boundary (col 1 / col cols-2) and grows
    #     inward — creates the impression of vines emerging from stone walls.
    for vr_offset in (floor_row // 4, 3 * floor_row // 4):
        vr = max(2, min(floor_row - 2, vr_offset))
        # Left wall (col 1, entering from west = the wall)
        if (1, vr) not in occupied:
            _grow_vine(vine_edges, occupied, cols, rows, 1, vr,
                       incoming="W", max_len=rng.randint(6, 12), rng=rng)
        # Right wall (col cols-2, entering from east = the wall)
        if (cols - 2, vr) not in occupied:
            _grow_vine(vine_edges, occupied, cols, rows, cols - 2, vr,
                       incoming="E", max_len=rng.randint(6, 12), rng=rng)

    # 3e. Secondary random vines for organic background fill
    for _ in range(6):
        sc = rng.randint(2, cols - 3)
        sr = rng.randint(2, floor_row - 1)
        if (sc, sr) not in occupied:
            _grow_vine(vine_edges, occupied, cols, rows, sc, sr,
                       incoming=rng.choice(["N", "S", "E", "W"]),
                       max_len=rng.randint(4, 9), rng=rng)

    # ── 4. Whorl focal ornament ───────────────────────────────────────────────
    # Place the grand spiral in the left-centre open area, then grow a vine
    # outward in all four cardinal directions so every port is truly connected.
    whorl_col = cols // 3
    whorl_row = floor_row // 2
    whorl_placed: tuple[int, int] | None = None

    for dr in range(-2, 3):
        for dc in range(-2, 3):
            wc, wr = whorl_col + dc, whorl_row + dr
            if (wc, wr) not in occupied and 1 <= wc <= cols - 2 and 1 <= wr <= rows - 2:
                whorl_placed = (wc, wr)
                occupied.add((wc, wr))
                break
        else:
            continue
        break

    if whorl_placed is not None:
        wc, wr = whorl_placed
        for direction in ("N", "S", "E", "W"):
            dc, dr = _DELTA[direction]
            nc, nr = wc + dc, wr + dr
            if ((nc, nr) not in occupied
                    and 1 <= nc <= cols - 2
                    and 1 <= nr <= rows - 2):
                _grow_vine(vine_edges, occupied, cols, rows, nc, nr,
                           incoming=_OPPOSITE[direction],
                           max_len=rng.randint(4, 8), rng=rng)

    # ── 5. Map vine edge-sets to tile roles ───────────────────────────────────
    for cell, edges in vine_edges.items():
        if cell in forbidden:
            continue
        ports = frozenset(edges)
        tile  = _PORTS_TO_VINE.get(ports)

        if tile is None:
            tile = "vine_ns" if ("N" in ports or "S" in ports) else "vine_ew"

        # vine_eye and vine_triangle are replaced with the plain vine_ns fill
        # (they were the "red square" tiles marked for replacement in the
        # tileset annotation — the standalone eye/triangle read as isolated
        # squares that break the vine network's visual continuity).

        layout[cell] = tile

    # Place whorl last so it overrides any vine tile the mapper assigned there
    if whorl_placed is not None:
        layout[whorl_placed] = "vine_whorl"

    # ── 6. Stair run — ascending left ─────────────────────────────────────────
    stair_start_col = rng.randint(cols // 5, cols // 3)
    stair_start_row = floor_row - 2
    stair_len       = rng.randint(3, 5)

    prev_stair: tuple[int, int] | None = None
    for i in range(stair_len):
        sc = stair_start_col - i
        sr = stair_start_row - i
        if (sc, sr) in occupied or not (1 <= sc <= cols - 2 and 1 <= sr <= rows - 2):
            break
        layout[(sc, sr)] = "klimt_stair_left"
        occupied.add((sc, sr))
        prev_stair = (sc, sr)

    if prev_stair is not None:
        lc = prev_stair[0] - 1
        lr = prev_stair[1] - 1
        if (lc, lr) not in occupied and 1 <= lc <= cols - 2 and 1 <= lr <= rows - 2:
            layout[(lc, lr)] = "klimt_stair_landing"

    # ── 7. Ceiling vine droop (green tiles) ───────────────────────────────────
    # Grow short drops of vine_ns_ceil downward from the ceiling row.
    # vine_ns_ceil is vine_ns flipped vertically — spirals hang downward,
    # giving the impression of vines growing OUT of the ceiling.
    # Seeded at the main trunk column plus two random well-spaced columns.
    ceil_drop_cols: list[int] = [trunk_col]
    pool = [c for c in range(2, cols - 2) if (c, 1) not in occupied]
    for _ in range(2):
        if not pool:
            break
        cc = rng.choice(pool)
        ceil_drop_cols.append(cc)
        # Keep ceiling drops at least 4 columns apart so they don't clump.
        pool = [c for c in pool if abs(c - cc) > 4]

    for cc in ceil_drop_cols:
        # Drop up to 3 cells downward from the ceiling (row 1 is just below
        # the solid ceiling border at row 0, which anchors the vine).
        drop_len = rng.randint(2, 4)
        for r in range(1, min(1 + drop_len, floor_row)):
            cell = (cc, r)
            if cell in occupied or cell in forbidden:
                break
            layout[cell] = "vine_ns_ceil"
            occupied.add(cell)
            forbidden.add(cell)

    return layout


class KlimtTilesetProvider:
    """
    Tileset provider for klimt_dining.

    Loads tiles from the klimtTile directory (flat filenames, no subdirs).
    Air cells are decorated with a topologically-consistent vine network
    grown from a central tree trunk, evoking Klimt's gold-leaf botanical motifs.

    Unlike ImageTilesetProvider's auto-contrast path, Klimt images are kept in
    full colour — auto-contrast would desaturate the warm gold palette.
    """

    # Map role keys → filenames inside the klimtTile directory
    _FILE_MAP: dict[str, str] = {
        # Structural tiles
        "floor_surface":    "TILE 12 — KLIMT_FLOOR_SURFACE.png",
        "floor_slab":       "TILE 13 — KLIMT_FLOOR_SLAB.png",
        "floor_left_edge":  "TILE 14 — KLIMT_FLOOR_LEFT_EDGE.png",
        "floor_right_edge": "TILE 15 — KLIMT_FLOOR_RIGHT_EDGE.png",
        "ceiling":          "TILE 16 — KLIMT_CEILING_SURFACE.png",
        "wall_left":        "TILE 17 — KLIMT_WALL_LEFT.png",
        "wall_right":       "TILE 18 — KLIMT_WALL_RIGHT.png",
        # Vine connector tiles — roles match _VINE_PORTS keys
        "vine_ns":          "TILE 01 — KLIMT_VOID_NS.png",
        "vine_ew":          "TILE 02 — KLIMT_VOID_EW.png",
        "vine_ne":          "TILE 03 — KLIMT_VOID_NE.png",
        "vine_nw":          "TILE 04 — KLIMT_VOID_NW.png",
        "vine_se":          "TILE 05 — KLIMT_VOID_SE.png",
        "vine_sw":          "TILE 06 — KLIMT_VOID_SW.png",
        "vine_whorl":       "TILE 07 — KLIMT_VOID_WHORL.png",
        "vine_branch":      "TILE 08 — KLIMT_VOID_BRANCH.png",
        "vine_branch_w":    "TILE 09 — KLIMT_VOID_BRANCH_WEST.png",
        "vine_eye":         "TILE 10 — KLIMT_VOID_EYE.png",
        "vine_triangle":    "TILE 11 — KLIMT_VOID_TRIANGLE.png",
        # Feature tiles
        "tree_trunk":            "TILE 22 — KLIMT_TREE_TRUNK.png",
        "klimt_stair_left":      "TILE 20 — KLIMT_STAIR_ASCENDING_LEFT.png",
        "klimt_stair_right":     "TILE 19 — KLIMT_STAIR_ASCENDING_RIGHT.png",
        "klimt_stair_landing":   "TILE 21 — KLIMT_STAIR_LANDING.png",
        # ── Anchor tiles (visual connectors: vine → solid structure) ─────────
        # root_anchor: golden root mass where trunk base meets the floor.
        "root_anchor":           "TILE 23 — KLIMT_ROOT_ANCHOR.png",
        # wall_anchor: ornamental vine knot attaching to left or right wall.
        "wall_anchor_left":      "TILE 24 — KLIMT_WALL_ANCHOR_LEFT.png",
        "wall_anchor_right":     "TILE 25 — KLIMT_WALL_ANCHOR_RIGHT.png",
        # ceiling_anchor: hanging vine origin from the ceiling edge.
        "ceiling_anchor":        "TILE 26 — KLIMT_CEILING_ANCHOR.png",
        # vine_junction: branching ornamental node where multiple vines meet.
        "vine_junction":         "TILE 27 — KLIMT_VINE_JUNCTION.png",
        # ── Decorative-only tiles (non-climbable) ────────────────────────────
        # vine_tendril: non-climbable curl end; only valid as child of anchored vine.
        "vine_tendril":          "TILE 28 — KLIMT_VINE_TENDRIL.png",
        # mosaic_filler: gold-leaf pattern tile for visual gap-filling.
        "mosaic_filler":         "TILE 29 — KLIMT_MOSAIC_FILLER.png",
        # jewel_cluster: turquoise/amber/ivory accent near vine junctions.
        "jewel_cluster":         "TILE 30 — KLIMT_JEWEL_CLUSTER.png",
        # platform_lip: gameplay platform edge with gold/purple ornament.
        "platform_lip":          "TILE 31 — KLIMT_PLATFORM_LIP.png",
    }

    # Vine tile roles that are valid climbing surfaces.
    # tree_trunk is always climbable (the main structural anchor).
    # Anchor tiles (root_anchor, wall_anchor_*) are climbable — they are the
    # literal contact point between vine and solid structure, so of course the
    # player can grab them.  Including them here also keeps them in the BFS
    # flood-fill so the climbability chain is never broken at an anchor tile.
    # Connector vines are climbable only when connected to an anchored system
    # (tracked by _vine_climbable_cells after air_layout() runs).
    _CLIMBABLE_ROLES: frozenset[str] = frozenset({
        "tree_trunk",
        "root_anchor",
        "wall_anchor_left", "wall_anchor_right",
        "ceiling_anchor",
        "vine_ns", "vine_ew",
        "vine_ne", "vine_nw", "vine_se", "vine_sw",
        "vine_branch", "vine_branch_w",
        "vine_whorl",
        "vine_junction",
        # Ceiling-anchored vertical vine — vine_ns flipped vertically so
        # the spirals hang downward from the ceiling.
        "vine_ns_ceil",
    })

    def __init__(self, tileset_path: Path, npc_art) -> None:
        self.tileset_path = Path(tileset_path)
        self.npc_art      = npc_art
        self.palette      = PALETTES.get("klimt_dining", _DEFAULT_PALETTE)
        self._img_cache: dict[str, pygame.Surface | None] = {}
        # Populated by air_layout() — the VineAnchorClimb ability reads this.
        # Every (col, row) in this set is a valid vine-climbing cell for the
        # current room.  Rebuilt on each air_layout() call.
        # Only cells reachable from solid-adjacent seeds are included (anchor-
        # validated).  Floating vines with no structural connection are excluded.
        self._vine_climbable_cells: set[tuple[int, int]] = set()
        # Direct anchor sources (vine cells touching solid) — used by debug overlay
        # to show anchor points as a separate colour from generic climbable cells.
        self._vine_anchor_cells: set[tuple[int, int]] = set()
        # Last computed deco map — held for debug overlay's tendril highlighting.
        self._last_deco: dict[tuple[int, int], str] = {}

    # ── Image loading ─────────────────────────────────────────────────────────

    def _load(self, filename: str) -> pygame.Surface | None:
        """Load and cache a raw image by filename. Returns None if absent."""
        if filename in self._img_cache:
            return self._img_cache[filename]
        full = self.tileset_path / filename
        if not full.exists():
            self._img_cache[filename] = None
            return None
        try:
            surf = pygame.image.load(str(full)).convert()
            self._img_cache[filename] = surf
            return surf
        except Exception:
            self._img_cache[filename] = None
            return None

    def _scaled(self, role: str, w: int, h: int) -> pygame.Surface | None:
        """Load and scale a tile by role key. No auto-contrast — preserve gold hues."""
        filename = self._FILE_MAP.get(role)
        if not filename:
            return None
        raw = self._load(filename)
        if raw is None:
            return None
        return pygame.transform.smoothscale(raw, (w, h))

    # ── TileArtProvider protocol ──────────────────────────────────────────────

    def bg_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        """Plain warm-gold background for air cells that carry no vine."""
        surf = pygame.Surface((tile_w, tile_h))
        # Base amber
        surf.fill((198, 152, 18))
        # Light central highlight — imitates the gold-leaf sheen
        for y in range(tile_h):
            alpha = int(18 * math.sin(math.pi * y / max(1, tile_h)))
            r = min(255, 198 + alpha)
            g = min(255, 152 + alpha // 2)
            pygame.draw.line(surf, (r, g, 18), (0, y), (tile_w, y))
        return surf

    def floor_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        s = self._scaled("floor_surface", tile_w, tile_h)
        if s:
            return s
        surf = pygame.Surface((tile_w, tile_h))
        surf.fill(self.palette.floor_body)
        pygame.draw.line(surf, self.palette.floor_top, (0, 0), (tile_w, 0), 2)
        return surf

    def floor_slab_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        s = self._scaled("floor_slab", tile_w, tile_h)
        if s:
            return s
        surf = pygame.Surface((tile_w, tile_h))
        surf.fill(self.palette.floor_body)
        return surf

    def floor_left_edge_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        s = self._scaled("floor_left_edge", tile_w, tile_h)
        if s:
            return s
        surf = self.floor_tile(tile_w, tile_h)
        pygame.draw.line(surf, self.palette.floor_top, (0, 0), (0, tile_h))
        return surf

    def floor_right_edge_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        s = self._scaled("floor_right_edge", tile_w, tile_h)
        if s:
            return s
        surf = self.floor_tile(tile_w, tile_h)
        pygame.draw.line(surf, self.palette.floor_top, (tile_w - 1, 0), (tile_w - 1, tile_h))
        return surf

    def platform_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        return self.floor_tile(tile_w, tile_h)

    def ghost_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        surf = pygame.Surface((tile_w, tile_h), pygame.SRCALPHA)
        surf.fill(self.palette.ghost_color)
        return surf

    def wall_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        s = self._scaled("wall_left", tile_w, tile_h)
        if s:
            return s
        surf = pygame.Surface((tile_w, tile_h))
        surf.fill(self.palette.wall_color)
        return surf

    def wall_right_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        s = self._scaled("wall_right", tile_w, tile_h)
        if s:
            return s
        return self.wall_tile(tile_w, tile_h)

    def ceiling_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        s = self._scaled("ceiling", tile_w, tile_h)
        if s:
            return s
        surf = pygame.Surface((tile_w, tile_h))
        surf.fill(self.palette.wall_color)
        pygame.draw.line(surf, self.palette.floor_top, (0, tile_h - 1), (tile_w, tile_h - 1))
        return surf

    def background(self, biome: str, width: int, height: int) -> pygame.Surface:
        surf = pygame.Surface((width, height))
        surf.fill(self.palette.bg_color)
        return surf

    # Procedural fallback palettes for new tile categories.
    # Used when the corresponding PNG file is absent from klimtTile/.
    _PROC_TILES: dict[str, tuple] = {
        # (fill_rgb, accent_rgb, shape)  shape: "circle", "rect", "diamond", "none"
        "root_anchor":       ((90, 46, 10),  (212, 175, 55), "diamond"),
        "wall_anchor_left":  ((60, 30, 5),   (184, 121, 10), "circle"),
        "wall_anchor_right": ((60, 30, 5),   (184, 121, 10), "circle"),
        "ceiling_anchor":    ((50, 25, 5),   (199, 138, 26), "diamond"),
        "vine_junction":     ((30, 18, 5),   (212, 175, 55), "circle"),
        "vine_tendril":      ((80, 55, 10),  (140, 100, 20), "none"),
        "mosaic_filler":     ((168, 128, 15),(220, 185, 60), "rect"),
        "jewel_cluster":     ((30, 120, 140),(180, 220, 225),"circle"),
        "platform_lip":      ((61, 28, 2),   (212, 160, 23), "rect"),
    }

    def decorative_tile(self, role: str, tile_w: int, tile_h: int) -> pygame.Surface | None:
        """
        Load any vine/feature tile by role key for air-cell decoration.

        Falls back to a procedural surface when the PNG file is absent —
        this keeps new tile categories visually distinct during development
        before the full art set is delivered.

        Special transform rules (applied after scaling):
          vine_ns_ceil  — vine_ns flipped vertically; spirals hang downward
                          from the ceiling (green annotation).
          klimt_stair_* — rotated 90° so the decorative vertical border
                          becomes a horizontal top-edge, matching the floor
                          line visual (blue annotation).
        """
        # ── vine_ns_ceil: vertically flipped vine_ns (ceiling droop) ─────────
        if role == "vine_ns_ceil":
            img = self._scaled("vine_ns", tile_w, tile_h)
            if img is not None:
                return pygame.transform.flip(img, False, True)
            return None

        # ── Stair tiles: rotate 90° so the decorative column reads horizontal ─
        # stair_left has its decorative border on the right edge; rotating 90°
        # CCW (angle=+90) brings that border to the top — matches floor line.
        # stair_right has its border on the left; rotating 90° CW (angle=−90)
        # likewise brings it to the top.
        if role == "klimt_stair_left":
            img = self._scaled(role, tile_w, tile_h)
            if img is not None:
                return pygame.transform.rotate(img, 90)
            return None
        if role == "klimt_stair_right":
            img = self._scaled(role, tile_w, tile_h)
            if img is not None:
                return pygame.transform.rotate(img, -90)
            return None

        # Try image file first
        img = self._scaled(role, tile_w, tile_h)
        if img is not None:
            return img

        # Procedural fallback for known new tile categories
        spec = self._PROC_TILES.get(role)
        if spec is None:
            return None   # unknown role, let renderer fall back to bg

        fill_rgb, accent_rgb, shape = spec
        surf = pygame.Surface((tile_w, tile_h), pygame.SRCALPHA)
        surf.fill((*fill_rgb, 200))

        cx, cy = tile_w // 2, tile_h // 2
        r = min(tile_w, tile_h) // 3

        if shape == "circle":
            pygame.draw.circle(surf, (*accent_rgb, 220), (cx, cy), r)
        elif shape == "diamond":
            pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
            pygame.draw.polygon(surf, (*accent_rgb, 220), pts)
        elif shape == "rect":
            pad = max(2, tile_w // 5)
            pygame.draw.rect(surf, (*accent_rgb, 200),
                             (pad, pad, tile_w - pad * 2, tile_h - pad * 2))

        return surf

    def air_layout(
        self,
        solid_tiles: "set[tuple[int,int]]",
        cols: int,
        rows: int,
        seed: int,
    ) -> "dict[tuple[int,int], str]":
        deco = _klimt_air_layout(solid_tiles, cols, rows, seed)

        # ── Anchor validation ─────────────────────────────────────────────────
        # Compute which vine cells are actually reachable from solid structure.
        # Floating vine cells (no path to a solid-adjacent seed) are removed
        # from the layout entirely — the renderer falls back to bg_tile() (warm
        # Klimt gold) so they disappear visually rather than showing as a dark
        # vine_tendril procedural fallback.
        anchored, anchor_sources = _compute_anchored_vine_cells(
            deco, solid_tiles, self._CLIMBABLE_ROLES
        )
        for cell, role in list(deco.items()):
            if role in self._CLIMBABLE_ROLES and cell not in anchored:
                del deco[cell]

        self._vine_climbable_cells = anchored
        self._vine_anchor_cells    = anchor_sources
        self._last_deco            = deco   # cached for debug overlay
        return deco

    # Characters always delegate to npc_art
    def npc_sprite(self, npc_id: str, width: int, height: int) -> pygame.Surface:
        return self.npc_art.npc_sprite(npc_id, width, height)

    def player_sprite(self, width: int, height: int) -> pygame.Surface:
        return self.npc_art.player_sprite(width, height)

    def objective_sprite(self, size: int) -> pygame.Surface:
        return self.npc_art.objective_sprite(size)

    def updraft_band(self, width: int, height: int, alpha_frac: float) -> pygame.Surface:
        return self.npc_art.updraft_band(width, height, alpha_frac)
