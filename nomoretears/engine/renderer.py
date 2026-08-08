"""
engine/renderer.py
------------------
Draws one room frame. Asks TileArtProvider for surfaces when available;
falls back to ThemeDefinition colors when art is None.

Dialogue rendering shows the current node's text and numbered choices.
"""
from __future__ import annotations

import math
import pygame

from engine.room_graph import TILE_W, TILE_H, ROOM_COLS, ROOM_ROWS, TILE_SCALE
from engine.proc_gen import GeneratedLayout
from engine.theme import ThemeDefinition
from engine.state import GameState
from engine.entities import PlayerEntity, NPCEntity, ObjectiveEntity
from engine.dialogue import DialogueRunner
from engine.bundle import TileArtProvider

SCREEN_W = ROOM_COLS * TILE_W   # 3840 at 4K
SCREEN_H = ROOM_ROWS * TILE_H   # 2160 at 4K

_FLOOR_ROW = ROOM_ROWS - 3   # row 15 — top of the solid floor


def _s(n: float) -> int:
    """Scale a legacy 32-px-tile UI value to current tile size."""
    return max(1, round(n * TILE_SCALE))


# ── Tile role classification ───────────────────────────────────────────────────

def _classify_tile(
    col: int, row: int, solid: "set[tuple[int, int]]"
) -> str:
    """
    Assign a visual role to a solid tile based on its neighbors.

    Rules (evaluated in order):
      wall_left / wall_right — boundary columns, always full-height wall art.
      floor_slab             — solid tile directly above → buried interior block.
      floor_left_edge        — surface tile with open space to its left.
      floor_right_edge       — surface tile with open space to its right.
      floor_surface          — all other surface tiles (interior or isolated).

    "Open space to the left/right" excludes the boundary wall columns so that
    a platform butting against a wall is not incorrectly flagged as an edge.
    """
    if col == 0:
        return "wall_left"
    if col == ROOM_COLS - 1:
        return "wall_right"
    # Buried interior: a solid tile sits directly above this one
    if (col, row - 1) in solid:
        return "floor_slab"
    # Surface tile — inspect horizontal run edges
    # A tile is a left-edge if its left neighbour is empty AND not a wall
    left_open  = col > 1            and (col - 1, row) not in solid
    right_open = col < ROOM_COLS - 2 and (col + 1, row) not in solid
    if left_open and not right_open:
        return "floor_left_edge"
    if right_open and not left_open:
        return "floor_right_edge"
    return "floor_surface"


# Map role → art-provider method name
_ROLE_METHOD: dict[str, str] = {
    "bg":              "bg_tile",
    "wall_left":       "wall_tile",
    "wall_right":      "wall_right_tile",
    "ceiling":         "ceiling_tile",
    "floor_surface":   "floor_tile",
    "floor_left_edge": "floor_left_edge_tile",
    "floor_right_edge":"floor_right_edge_tile",
    "floor_slab":      "floor_slab_tile",
    "ghost":           "ghost_tile",
}


class Renderer:
    """Stateless room renderer — call draw() each frame."""

    def __init__(
        self,
        theme: ThemeDefinition,
        bundle: "GameBundle",
    ) -> None:
        from engine.bundle import GameBundle  # local import avoids circular
        self.theme = theme
        self.bundle = bundle
        self.art: TileArtProvider | None = bundle.art   # resolved each frame
        self._font: pygame.font.Font | None = None
        self._small_font: pygame.font.Font | None = None
        # Surface caches — cleared whenever the active tileset changes.
        self._surf_cache: dict[str, pygame.Surface] = {}
        self._active_tileset: str = ""   # sentinel — forces first-frame resolve
        # Decoration layout: (col,row) → role for air cells. Regenerated when
        # the room layout or active tileset changes.
        self._deco_layout: dict[tuple[int, int], str] = {}
        self._deco_key: tuple = (None, None, None)   # (seed, fill_density, tileset)
        # Tileset-switch flash banner — shown for a short duration on [T] press.
        self._flash_text: str = ""
        self._flash_timer: float = 0.0
        self._flash_font: pygame.font.Font | None = None

    # ── Public API ─────────────────────────────────────────────────────────────

    def draw(
        self,
        surface: pygame.Surface,
        layout: GeneratedLayout,
        player: PlayerEntity,
        npcs: list[NPCEntity],
        objectives: list[ObjectiveEntity],
        state: GameState,
        tick: int,
        dialogue_runner: DialogueRunner | None = None,
    ) -> None:
        # Resolve active tileset — clear caches when it changes so new art
        # takes effect immediately across all tile types.
        requested = getattr(state, "active_tileset", "")
        if requested != self._active_tileset:
            self._surf_cache.clear()
            self._deco_layout = {}          # force deco regeneration on tileset swap
            self._deco_key = (None, None, None)
            self._active_tileset = requested
            self.art = (
                self.bundle.tilesets.get(requested)
                or self.bundle.art
            )

        # Resolve active room style (may be None for tilesets without one).
        style = self.bundle.room_styles.get(self._active_tileset)

        self._draw_tilemap(surface, layout)
        self._draw_ghost_platforms(surface, layout, tick)
        self._draw_updraft(surface, layout, tick)
        self._draw_objectives(surface, objectives, tick)
        # Trail renders behind NPCs so ghosts feel part of the architecture.
        if style is not None:
            style.draw_trail(surface)
        self._draw_npcs(surface, npcs, state)
        if style is not None:
            style.draw_player(surface, player, tick)
        else:
            self._draw_player(surface, player, tick)
        # Active ability affordances draw on top of the world, below the HUD.
        ruleset = self.bundle.rulesets.get(self._active_tileset)
        if ruleset and ruleset.ability:
            ruleset.ability.render_ability_layer(surface)
        self._draw_hud(surface, state)
        self._draw_exit_hints(surface, state)
        if dialogue_runner and dialogue_runner.active:
            self._draw_dialogue(surface, dialogue_runner, state)
        if self._flash_timer > 0:
            self._draw_flash(surface)
        if getattr(self.bundle, "dev_mode", False):
            self._draw_debug_overlay(surface, state, player, layout)

    # ── Helpers ────────────────────────────────────────────────────────────────

    def _font_main(self) -> pygame.font.Font:
        if self._font is None:
            self._font = pygame.font.SysFont("monospace", self.theme.hud.font_size)
        return self._font

    def _font_small(self) -> pygame.font.Font:
        if self._small_font is None:
            self._small_font = pygame.font.SysFont("monospace", _s(13))
        return self._small_font

    def _get_surf(self, key: str, make) -> pygame.Surface:
        if key not in self._surf_cache:
            self._surf_cache[key] = make()
        return self._surf_cache[key]

    # ── Unified tile-surface dispatch ─────────────────────────────────────────

    def _tile_surf(self, role: str) -> pygame.Surface:
        """Return the cached surface for a tile role, building it on first use."""
        return self._get_surf(f"t_{role}", lambda: self._make_tile(role))

    def _make_tile(self, role: str) -> pygame.Surface:
        """
        Build one tile surface.

        Dispatch order:
          1. Named protocol method (standard structural tiles via _ROLE_METHOD).
          2. Generic decorative_tile() — handles ornamental roles (pillars, stairs,
             arches) loaded from file by the tileset provider.
          3. Theme-colour procedural fallback (no art, or image missing).
        """
        if self.art is not None:
            # Standard tile: protocol method
            method_name = _ROLE_METHOD.get(role)
            if method_name:
                method = getattr(self.art, method_name, None)
                if method:
                    return method(TILE_W, TILE_H)
            # Ornamental tile: generic loader
            deco_method = getattr(self.art, "decorative_tile", None)
            if deco_method:
                surf = deco_method(role, TILE_W, TILE_H)
                if surf is not None:
                    return surf
        return self._fallback_tile(role)

    def _fallback_tile(self, role: str) -> pygame.Surface:
        """Theme-colour procedural tile used when no art provider is set."""
        t = self.theme.tiles
        if role == "bg":
            s = pygame.Surface((TILE_W, TILE_H))
            s.fill(t.background)
            return s
        if role in ("wall_left", "wall_right"):
            s = pygame.Surface((TILE_W, TILE_H))
            s.fill(t.wall)
            return s
        if role == "ceiling":
            s = pygame.Surface((TILE_W, TILE_H))
            s.fill(t.wall)
            # Bottom edge highlight faces downward into the room
            pygame.draw.rect(s, tuple(min(255, c + 30) for c in t.wall),
                             (0, TILE_H - 2, TILE_W, 2))
            return s
        if role == "floor_slab":
            s = pygame.Surface((TILE_W, TILE_H))
            s.fill(t.floor_body)
            return s
        if role == "ghost":
            s = pygame.Surface((TILE_W, TILE_H), pygame.SRCALPHA)
            s.fill(t.ghost_fill)
            pygame.draw.rect(s, t.ghost_border, (0, 0, TILE_W, _s(3)))
            return s
        if role in ("floor_surface", "floor_left_edge", "floor_right_edge"):
            s = pygame.Surface((TILE_W, TILE_H))
            s.fill(t.floor_body)
            pygame.draw.rect(s, t.floor_top, (0, 0, TILE_W, _s(5)))
            if role == "floor_left_edge":
                pygame.draw.line(s, t.floor_top, (0, 0), (0, TILE_H))
            elif role == "floor_right_edge":
                pygame.draw.line(s, t.floor_top, (TILE_W - 1, 0), (TILE_W - 1, TILE_H))
            return s
        # Any ornamental/unknown role (pillar_top, stair_right, arch_left, …)
        # falls back to a plain bg tile so missing assets are invisible rather
        # than garish.
        s = pygame.Surface((TILE_W, TILE_H))
        s.fill(t.background)
        return s

    def _player_surf(self) -> pygame.Surface:
        def make():
            if self.art:
                from engine.physics import PLAYER_W, PLAYER_H
                return self.art.player_sprite(PLAYER_W, PLAYER_H)
            from engine.physics import PLAYER_W, PLAYER_H
            s = pygame.Surface((PLAYER_W, PLAYER_H))
            pv = self.theme.player
            s.fill(pv.body_color)
            pygame.draw.rect(s, pv.accent_color, (_s(4), _s(4), PLAYER_W - _s(8), _s(10)))
            return s
        return self._get_surf("player", make)

    def _npc_surf(self, npc_id: str) -> pygame.Surface:
        key = f"npc_{npc_id}"
        def make():
            nv = self.theme.npc
            if self.art:
                return self.art.npc_sprite(npc_id, nv.width, nv.height)
            s = pygame.Surface((nv.width, nv.height))
            s.fill(nv.body_color)
            pygame.draw.rect(s, nv.accent_color, (_s(3), _s(3), nv.width - _s(6), _s(10)))
            return s
        return self._get_surf(key, make)

    def _objective_surf(self, size: int) -> pygame.Surface:
        key = f"obj_{size}"
        def make():
            if self.art:
                return self.art.objective_sprite(size)
            ov = self.theme.objective
            s = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.rect(s, (*ov.color, 220), (0, 0, size, size))
            pygame.draw.rect(s, (*ov.glow_color[:3], 120), (2, 2, size - 4, size - 4))
            return s
        return self._get_surf(key, make)

    # ── Full tilemap ───────────────────────────────────────────────────────────
    #
    # Every screen cell is drawn as a classified tile — there is no separate
    # background blit.  Role priority (evaluated in order):
    #   wall column (col 0 / ROOM_COLS-1)  → wall_left / wall_right
    #   ceiling row (row 0, interior col)  → ceiling
    #   solid tile                         → classify by neighbor context
    #   empty cell                         → bg  (void / air tile)
    #
    # Ghost platforms are drawn in a separate pass on top so their animated
    # alpha doesn't interfere with the cached tile surfaces here.

    def _draw_tilemap(self, surface: pygame.Surface, layout: GeneratedLayout) -> None:
        solid = layout.solid_tiles

        # Rebuild decoration map when room or tileset changes.
        deco_key = (layout.seed, layout.fill_density, self._active_tileset)
        if deco_key != self._deco_key:
            art = self.art
            if art is not None and hasattr(art, "air_layout"):
                self._deco_layout = art.air_layout(
                    solid, ROOM_COLS, ROOM_ROWS, layout.seed
                )
            else:
                self._deco_layout = {}
            self._deco_key = deco_key

        deco = self._deco_layout

        # ImageTilesetProvider sets _tess_surf in __init__ (initially None).
        # Its presence signals that this tileset wants a positional tessellation
        # base drawn under every cell so transparent-white structural and
        # ornamental tiles reveal the pattern rather than the raw screen buffer.
        # The attribute exists from construction, so this check is frame-stable
        # even before the image is lazily loaded on first use.
        use_tess_base = hasattr(self.art, "_tess_surf")

        for row in range(ROOM_ROWS):
            for col in range(ROOM_COLS):
                x, y = col * TILE_W, row * TILE_H

                if use_tess_base:
                    # Always draw tessellation first; _tile_surf loads the image
                    # lazily on the very first call so frame 1 is never black.
                    surface.blit(self._tile_surf(f"tess:{col}:{row}"), (x, y))

                if col == 0:
                    role = "wall_left"
                elif col == ROOM_COLS - 1:
                    role = "wall_right"
                elif row == 0:
                    role = "ceiling"
                elif (col, row) in solid:
                    role = _classify_tile(col, row, solid)
                else:
                    # Air cell: ornamental deco on top of tessellation base.
                    role = deco.get((col, row), "bg")
                    if use_tess_base and role.startswith("tess:"):
                        continue   # base already covers this cell
                surface.blit(self._tile_surf(role), (x, y))

    # ── Ghost platforms ────────────────────────────────────────────────────────

    def _draw_ghost_platforms(
        self, surface: pygame.Surface, layout: GeneratedLayout, tick: int
    ) -> None:
        if not self.theme.show_ghost_platforms:
            return
        # Build per-frame copy so set_alpha doesn't mutate the cached surface
        gs = self._tile_surf("ghost").copy()
        alpha = 45 + int(20 * math.sin(tick * 0.04))
        gs.set_alpha(alpha)
        for (col, row) in layout.ghost_tiles:
            surface.blit(gs, (col * TILE_W, row * TILE_H))

    # ── Updraft ────────────────────────────────────────────────────────────────

    def _draw_updraft(
        self, surface: pygame.Surface, layout: GeneratedLayout, tick: int
    ) -> None:
        # Updraft zones are an Escher-only mechanic — only render when that
        # tileset is active so other tileset rooms don't show mystery air columns.
        if self._active_tileset != "escher_foyer":
            return
        if layout.updraft is None:
            return
        ucol, rtop, rbot = layout.updraft
        uv = self.theme.updraft
        x = (ucol - 1) * TILE_W
        y_top = rtop * TILE_H
        y_bot = (rbot + 1) * TILE_H
        width = uv.width_tiles * TILE_W
        height = y_bot - y_top

        bands = 10
        for i in range(bands):
            frac = i / bands
            alpha_frac = 1.0 - frac
            band_h = height // bands + 1
            band_y = y_top + int(frac * height)
            if self.art:
                band_surf = self.art.updraft_band(width, band_h, alpha_frac)
            else:
                alpha = int(uv.color_bottom[3] * alpha_frac)
                r = int(uv.color_bottom[0] * (1 - frac) + uv.color_top[0] * frac)
                g = int(uv.color_bottom[1] * (1 - frac) + uv.color_top[1] * frac)
                b = int(uv.color_bottom[2] * (1 - frac) + uv.color_top[2] * frac)
                band_surf = pygame.Surface((width, band_h), pygame.SRCALPHA)
                band_surf.fill((r, g, b, alpha))
            surface.blit(band_surf, (x, band_y))

        # Particles
        for i in range(6):
            phase = (tick * 2 + i * 40) % 360
            px_off = int(_s(4) * math.sin(math.radians(phase + i * 60)))
            py_off = y_bot - int(((tick * 1.5 + i * 22) % max(1, height)))
            pygame.draw.circle(surface, uv.particle_color,
                               (x + width // 2 + px_off, py_off), _s(2))

    # ── Objectives ─────────────────────────────────────────────────────────────

    def _draw_objectives(
        self, surface: pygame.Surface, objectives: list[ObjectiveEntity], tick: int
    ) -> None:
        ov = self.theme.objective
        pulse = int(ov.size * (0.8 + 0.2 * math.sin(tick * 0.08)))
        obj_surf = self._objective_surf(pulse)
        for obj in objectives:
            if obj.collected:
                continue
            cx = obj.col * TILE_W + (TILE_W - pulse) // 2
            cy = obj.row * TILE_H - TILE_H + (TILE_H - pulse) // 2
            surface.blit(obj_surf, (cx, cy))

    # ── NPCs ───────────────────────────────────────────────────────────────────

    def _draw_npcs(
        self, surface: pygame.Surface, npcs: list[NPCEntity], state: GameState
    ) -> None:
        font = self._font_small()
        for npc in npcs:
            nv = self.theme.npc
            ns = self._npc_surf(npc.npc_id)
            rx = int(npc.col * TILE_W + (TILE_W - nv.width) // 2)
            ry = int(npc.row * TILE_H - nv.height)
            surface.blit(ns, (rx, ry))
            if state.is_npc_solved(npc.npc_id):
                check = font.render("✓", True, (150, 220, 150))
                surface.blit(check, (rx + nv.width + _s(2), ry))
            elif npc.near_player:
                hint = font.render("[E] talk", True, nv.accent_color)
                surface.blit(hint, (rx - _s(8), ry - _s(18)))

    # ── Player ─────────────────────────────────────────────────────────────────

    def _draw_player(
        self, surface: pygame.Surface, player: PlayerEntity, tick: int
    ) -> None:
        ps = self._player_surf()
        # Horizontal flip tracks the player's last direction of movement.
        # Vertical flip simulates gravity inversion inside updraft zones.
        flip_h = not player.facing_right
        flip_v = player.body.in_updraft
        if flip_h or flip_v:
            ps = pygame.transform.flip(ps, flip_h, flip_v)
        surface.blit(ps, (int(player.body.px), int(player.body.py)))
        if player.body.in_updraft:
            pad = _s(10)
            glow = pygame.Surface((ps.get_width() + pad, ps.get_height() + pad), pygame.SRCALPHA)
            glow.fill((100, 180, 255, 55))
            surface.blit(glow, (int(player.body.px) - pad // 2, int(player.body.py) - pad // 2))

    # ── HUD ────────────────────────────────────────────────────────────────────

    def _draw_hud(self, surface: pygame.Surface, state: GameState) -> None:
        hv = self.theme.hud
        font = self._font_main()

        bar_w, bar_h = _s(200), _s(14)
        bar_x, bar_y = SCREEN_W - bar_w - _s(16), _s(12)
        frac = max(0.0, state.fatigue_remaining / state.game_def.fatigue_seconds)
        bar_color = hv.fatigue_full if frac > 0.35 else hv.fatigue_low

        bg = pygame.Surface((bar_w + _s(4), bar_h + _s(20)), pygame.SRCALPHA)
        bg.fill(hv.bg_color)
        surface.blit(bg, (bar_x - _s(2), bar_y - _s(2)))
        pygame.draw.rect(surface, (40, 40, 50), (bar_x, bar_y, bar_w, bar_h))
        pygame.draw.rect(surface, bar_color, (bar_x, bar_y, int(bar_w * frac), bar_h))
        label = font.render("fatigue", True, hv.text_color)
        surface.blit(label, (bar_x, bar_y + bar_h + _s(2)))

        room = state.game_def.graph.get(state.current_room_id)
        if room:
            name_surf = font.render(room.display_name, True, hv.text_color)
            surface.blit(name_surf, (_s(16), _s(12)))

        # Tileset indicator — show active name and cycle hint
        ts_id = getattr(state, "active_tileset", "")
        ts_name = self.bundle.tileset_display_names.get(ts_id) if ts_id else None
        if ts_name is None and ts_id:
            ts_name = ts_id.replace("_", " ").title()
        if ts_name:
            small = self._font_small()
            ts_surf = small.render(f"[T] {ts_name}", True, (130, 120, 155))
            surface.blit(ts_surf, (_s(16), _s(30) + font.get_height()))

        if state.solved_npcs:
            txt = font.render(
                "solved: " + ", ".join(sorted(state.solved_npcs)),
                True, (150, 220, 150),
            )
            surface.blit(txt, (_s(16), SCREEN_H - _s(28)))

    # ── Exit hints ─────────────────────────────────────────────────────────────

    def _draw_exit_hints(self, surface: pygame.Surface, state: GameState) -> None:
        room = state.game_def.graph.get(state.current_room_id)
        if not room:
            return
        font = self._font_small()
        floor_y = _FLOOR_ROW * TILE_H
        for ex in room.exits:
            open_ = state.is_gate_open(ex.gate_id)
            color = (160, 210, 160) if open_ else (160, 70, 70)
            lbl = font.render(f"[{ex.direction}]", True, color)
            if ex.trigger_col is not None and ex.trigger_row is not None:
                # Draw hint at the trigger tile position, offset slightly upward
                hx = ex.trigger_col * TILE_W
                hy = ex.trigger_row * TILE_H - _s(20)
                surface.blit(lbl, (hx, hy))
            elif ex.direction == "west":
                surface.blit(lbl, (TILE_W + _s(2), floor_y - _s(20)))
            elif ex.direction == "east":
                surface.blit(lbl, (SCREEN_W - TILE_W * 2 - _s(30), floor_y - _s(20)))
            elif ex.direction == "upper_east":
                surface.blit(lbl, (SCREEN_W - TILE_W * 2 - _s(30), (_FLOOR_ROW - 8) * TILE_H))
            elif ex.direction == "upper_west":
                surface.blit(lbl, (TILE_W + _s(2), (_FLOOR_ROW - 8) * TILE_H))

    # ── Dialogue tree ──────────────────────────────────────────────────────────

    def _draw_dialogue(
        self,
        surface: pygame.Surface,
        runner: DialogueRunner,
        state: GameState,
    ) -> None:
        node = runner.current_node()
        if not node:
            return

        font = self._font_main()
        small = self._font_small()
        hv = self.theme.hud

        choices = runner.visible_choices()
        has_choices = bool(choices)
        line_h = font.get_height() + _s(4)
        choice_h = font.get_height() + _s(8)
        box_h = _s(100) + len(choices) * choice_h
        box_w = SCREEN_W - _s(60)
        box_x, box_y = _s(30), SCREEN_H - box_h - _s(16)

        # Background
        bg = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
        bg.fill((8, 6, 18, 220))
        surface.blit(bg, (box_x, box_y))
        pygame.draw.rect(surface, (90, 80, 110), (box_x, box_y, box_w, box_h), _s(2))

        # Word-wrap body text
        words = node.text.split()
        lines: list[str] = []
        cur = ""
        for word in words:
            test = (cur + " " + word).strip()
            if font.size(test)[0] > box_w - _s(24):
                lines.append(cur)
                cur = word
            else:
                cur = test
        if cur:
            lines.append(cur)

        ty = box_y + _s(10)
        for line in lines[:4]:
            surface.blit(font.render(line, True, hv.text_color), (box_x + _s(12), ty))
            ty += line_h

        ty += _s(6)

        if has_choices:
            for idx, (_, choice) in enumerate(choices):
                key_color = (200, 180, 100)
                txt_color = hv.text_color
                key_surf = font.render(f"[{idx + 1}]", True, key_color)
                txt_surf = font.render(f" {choice.text}", True, txt_color)
                surface.blit(key_surf, (box_x + _s(12), ty))
                surface.blit(txt_surf, (box_x + _s(12) + key_surf.get_width(), ty))
                ty += choice_h
        else:
            # Linear node — show advance hint
            hint = small.render("[Space] continue   [E] close", True, (120, 110, 140))
            surface.blit(hint, (box_x + _s(12), ty))

    # ── Debug overlay (dev_mode only) ─────────────────────────────────────────

    def _draw_debug_overlay(
        self,
        surface: pygame.Surface,
        state: GameState,
        player: "PlayerEntity",
        layout: "GeneratedLayout",
    ) -> None:
        """
        Unobtrusive debug overlay shown in dev_mode.

        Top-left corner shows:
          • active ruleset and ability name
          • ability availability and current status
          • vine_anchor state
          • player tile position
        Vine-climbable cells are highlighted with a translucent green rect.
        Invalid/floating vines (no climbable tag) are tinted orange.
        """
        small = self._font_small()
        lh    = small.get_height() + 2
        x, y  = _s(4), _s(50)   # below the room name in the HUD

        # Background strip
        bg = pygame.Surface((_s(220), lh * 6 + _s(4)), pygame.SRCALPHA)
        bg.fill((0, 0, 0, 140))
        surface.blit(bg, (x - _s(2), y - _s(2)))

        ts_id   = self._active_tileset or "(none)"
        ruleset = self.bundle.rulesets.get(ts_id)
        ability_name   = ruleset.ability_name if ruleset else "—"
        ability_status = {}
        if ruleset and ruleset.ability:
            try:
                ability_status = ruleset.ability.get_debug_status()
            except Exception:
                ability_status = {}

        lines = [
            f"ruleset: {ts_id}",
            f"ability: {ability_name}",
            f"vine_anchor: {player.body.vine_anchor}",
            f"on_ground:   {player.body.on_ground}",
            f"tile: ({player.col}, {player.row})",
        ]
        if ability_status:
            for k, v in list(ability_status.items())[:3]:
                lines.append(f"  {k}: {v}")

        for line in lines:
            surf = small.render(line, True, (160, 240, 160))
            surface.blit(surf, (x, y))
            y += lh

        # Highlight vine-climbable cells (green) and anchor sources (amber)
        if ruleset and ruleset.ability and hasattr(ruleset.ability, "_climbable_cells"):
            cells: "set[tuple[int,int]]" = getattr(ruleset.ability, "_climbable_cells", set())
            vine_surf = pygame.Surface((TILE_W, TILE_H), pygame.SRCALPHA)
            vine_surf.fill((0, 200, 80, 38))
            for (c, r) in cells:
                surface.blit(vine_surf, (c * TILE_W, r * TILE_H))

        # Show anchor source cells from the tileset provider (amber overlay)
        tileset_provider = self.bundle.tilesets.get(ts_id)
        if tileset_provider is not None:
            anchor_cells = getattr(tileset_provider, "_vine_anchor_cells", set())
            if anchor_cells:
                anch_surf = pygame.Surface((TILE_W, TILE_H), pygame.SRCALPHA)
                anch_surf.fill((240, 160, 20, 60))
                for (c, r) in anchor_cells:
                    surface.blit(anch_surf, (c * TILE_W, r * TILE_H))
            # Show unanchored (tendril) vine cells in orange-red
            tendril_cells = {
                cell for cell, role in getattr(tileset_provider, "_last_deco", {}).items()
                if role == "vine_tendril"
            }
            if tendril_cells:
                tend_surf = pygame.Surface((TILE_W, TILE_H), pygame.SRCALPHA)
                tend_surf.fill((220, 60, 20, 45))
                for (c, r) in tendril_cells:
                    surface.blit(tend_surf, (c * TILE_W, r * TILE_H))

    # ── Tileset flash banner ───────────────────────────────────────────────────

    def show_flash(self, text: str, duration: float = 2.0) -> None:
        """Display a large centred tileset-name banner for `duration` seconds."""
        self._flash_text  = text
        self._flash_timer = duration

    def tick_flash(self, dt: float) -> None:
        """Advance the flash timer — call once per frame from the session."""
        if self._flash_timer > 0:
            self._flash_timer = max(0.0, self._flash_timer - dt)

    def _draw_flash(self, surface: pygame.Surface) -> None:
        """Render the centred tileset-switch banner, fading out in the last 0.5s."""
        if self._flash_timer <= 0 or not self._flash_text:
            return
        if self._flash_font is None:
            size = max(16, round(28 * TILE_SCALE))
            self._flash_font = pygame.font.SysFont("monospace", size, bold=True)

        # Alpha: fully opaque for most of the duration, fade out in final 0.5s
        fade = min(1.0, self._flash_timer / 0.5)
        alpha = int(255 * fade)

        banner_font = self._flash_font
        text_surf = banner_font.render(self._flash_text, True, (255, 240, 180))

        pad_x, pad_y = _s(20), _s(10)
        bw = text_surf.get_width()  + pad_x * 2
        bh = text_surf.get_height() + pad_y * 2
        bx = (SCREEN_W - bw) // 2
        by = SCREEN_H // 3 - bh // 2

        bg = pygame.Surface((bw, bh), pygame.SRCALPHA)
        bg.fill((10, 8, 20, min(200, alpha)))
        pygame.draw.rect(bg, (120, 100, 160, alpha), (0, 0, bw, bh), _s(2))
        surface.blit(bg, (bx, by))

        text_surf.set_alpha(alpha)
        surface.blit(text_surf, (bx + pad_x, by + pad_y))
