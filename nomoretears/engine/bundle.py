"""
engine/bundle.py
----------------
GameBundle: everything the engine needs to run one game module.
TileArtProvider: protocol a module implements to supply procedural/asset art.

The engine never imports from a specific game module — it only knows GameBundle.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Protocol, runtime_checkable

if TYPE_CHECKING:
    import pygame
    from engine.dialogue import DialogueTree
    from engine.room_graph import GameDefinition
    from engine.ruleset import ArtRuleset
    from engine.theme import ThemeDefinition
    from engine.room_style import RoomStyle


# ── Art provider protocol ─────────────────────────────────────────────────────

@runtime_checkable
class TileArtProvider(Protocol):
    """
    Supplies pygame Surfaces for tiles, sprites, and backgrounds.
    The engine calls these once and caches results; providers may be stateful
    (e.g. pre-rendering a spritesheet) but must be callable after pygame.init().

    All methods receive pixel dimensions so the provider can scale to TILE_W/H.
    biome is the RoomDef.biome string — lets art vary per-room type.
    """

    def background(self, biome: str, width: int, height: int) -> "pygame.Surface":
        """Full-room background surface (width × height pixels)."""
        ...

    def bg_tile(self, tile_w: int, tile_h: int) -> "pygame.Surface":
        """Single air/void tile drawn at every empty cell."""
        ...

    def floor_tile(self, tile_w: int, tile_h: int) -> "pygame.Surface":
        """One solid floor/ground tile."""
        ...

    def platform_tile(self, tile_w: int, tile_h: int) -> "pygame.Surface":
        """One elevated platform tile (same size, different art)."""
        ...

    def ghost_tile(self, tile_w: int, tile_h: int) -> "pygame.Surface":
        """Phantom eligible-but-unfilled platform tile (should use SRCALPHA)."""
        ...

    def wall_tile(self, tile_w: int, tile_h: int) -> "pygame.Surface":
        """Left/right wall tile (legacy — used as fallback)."""
        ...

    def wall_right_tile(self, tile_w: int, tile_h: int) -> "pygame.Surface":
        """Right boundary wall face (may mirror wall_tile if no distinct asset)."""
        ...

    def ceiling_tile(self, tile_w: int, tile_h: int) -> "pygame.Surface":
        """Top-row interior ceiling trim strip."""
        ...

    def floor_slab_tile(self, tile_w: int, tile_h: int) -> "pygame.Surface":
        """Interior tile of a floor stack — no top highlight (buried block)."""
        ...

    def floor_left_edge_tile(self, tile_w: int, tile_h: int) -> "pygame.Surface":
        """Leftmost tile of a platform or floor run."""
        ...

    def floor_right_edge_tile(self, tile_w: int, tile_h: int) -> "pygame.Surface":
        """Rightmost tile of a platform or floor run."""
        ...

    def npc_sprite(self, npc_id: str, width: int, height: int) -> "pygame.Surface":
        """Sprite for a specific NPC (width × height pixels)."""
        ...

    def player_sprite(self, width: int, height: int) -> "pygame.Surface":
        """Player sprite."""
        ...

    def objective_sprite(self, size: int) -> "pygame.Surface":
        """Objective marker (size × size, SRCALPHA)."""
        ...

    def updraft_band(self, width: int, height: int, alpha_frac: float) -> "pygame.Surface":
        """One horizontal band of the updraft gradient (SRCALPHA)."""
        ...

    def decorative_tile(self, role: str, tile_w: int, tile_h: int) -> "pygame.Surface | None":
        """
        Load a named ornamental tile (pillar, stair, arch, etc.) for air cells.
        Return None if this provider has no image for the role — renderer falls
        back to the plain bg tile.  Only image-based providers need to implement
        this; procedural providers may leave it returning None.
        """
        return None

    def air_layout(
        self,
        solid_tiles: "set[tuple[int,int]]",
        cols: int,
        rows: int,
        seed: int,
    ) -> "dict[tuple[int,int], str]":
        """
        Return a decoration map: (col, row) → role-name for every air cell that
        should receive an ornamental tile instead of the plain bg tile.
        Called once per room entry; result is cached by the renderer.
        Procedural providers return {} — only tileset providers override this.
        """
        return {}


# ── Game bundle ───────────────────────────────────────────────────────────────

@dataclass
class GameBundle:
    """
    Everything the engine needs to run one game module.

    definition:      world layout, rooms, NPCs, objectives, gates.
    theme:           palette / color fallbacks (used when art is None).
    dialogue_trees:  npc_id → DialogueTree. NPCs with no entry get no dialogue.
    art:             optional TileArtProvider. When None the engine falls back
                     to ThemeDefinition colors for all visuals.
    """
    definition: "GameDefinition"
    theme: "ThemeDefinition"
    dialogue_trees: "dict[str, DialogueTree]" = field(default_factory=dict)
    art: "TileArtProvider | None" = None
    # Named tileset providers keyed by tileset_id.
    # The engine selects the active one from GameState.active_tileset.
    # Falls back to `art` when the requested id is absent.
    tilesets: "dict[str, TileArtProvider]" = field(default_factory=dict)
    # Ordered list of tileset ids for the [T] cycle key.
    # Include the special id "fallback" to expose the base art provider as a
    # selectable option.  Entries not in state.unlocked_tilesets are skipped.
    tileset_cycle: "list[str]" = field(default_factory=list)
    # Human-readable display names shown in the HUD.  Missing ids fall back
    # to title-casing the id with underscores replaced by spaces.
    tileset_display_names: "dict[str, str]" = field(default_factory=dict)
    # Per-tileset visual effect plugins (tileset_id → RoomStyle implementation).
    # When the active tileset has an entry here the renderer delegates player
    # drawing to the style's draw_trail() / draw_player() methods.
    room_styles: "dict[str, RoomStyle]" = field(default_factory=dict)
    # When True the engine pre-unlocks every tileset in tileset_cycle at session
    # start — useful during development to cycle all tilesets without earning them.
    dev_mode: bool = False
    # Per-tileset art rulesets — tileset_id → ArtRuleset.
    # Supplies the platforming ability and env-logic tags for each fine-art context.
    # Tilesets without an entry fall back to no ability (no-op behaviour).
    rulesets: "dict[str, ArtRuleset]" = field(default_factory=dict)

    # Optional per-tileset music tracks.  Keys are tileset_ids (same namespace as
    # `tilesets` and `tileset_cycle`); values are file paths accepted by
    # pygame.mixer.music.load().  Missing keys → silence / no music change on switch.
    # The special key "" (empty string) can map a default ambient track played when
    # no tileset-specific track is registered.
    tileset_music: "dict[str, str]" = field(default_factory=dict)
