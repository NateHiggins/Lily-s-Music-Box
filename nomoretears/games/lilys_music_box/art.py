"""
games/lilys_music_box/art.py
------------------------------
LilyArtProvider: procedural 16-bit-inspired tile and sprite art for
the dream-gallery / music-box aesthetic.

All surfaces are generated from code — no external assets required.
Biome-aware backgrounds shift palette between foyer, gallery, alcove, bedroom.
"""
from __future__ import annotations

import math
import pygame

from engine.room_graph import TILE_W, TILE_H, ROOM_COLS, ROOM_ROWS

# ── Palette ────────────────────────────────────────────────────────────────────

_P = {
    # Floor / platforms
    "oak_light":    (165, 132,  90),
    "oak_dark":     (100,  75,  52),
    "lav_light":    (148, 118, 170),
    "lav_dark":     (88,  65, 112),
    "lav_mid":      (118,  90, 140),
    # Walls
    "wall_dark":    (32,  28,  46),
    "wall_mid":     (48,  42,  64),
    "wall_accent":  (70,  62,  90),
    # Updraft
    "updraft_hi":   (220, 195, 255),
    "updraft_lo":   (160, 130, 220),
    # Player
    "lily_body":    (155, 115, 200),
    "lily_acc":     (215, 185, 255),
    "lily_dark":    (110,  80, 150),
    # NPC – archivist
    "arch_body":    (190, 155, 100),
    "arch_acc":     (240, 210, 130),
    "arch_dark":    (140, 110,  70),
    # Objective star
    "star_gold":    (255, 228,  80),
    "star_glow":    (255, 210,  50),
    # Backgrounds
    "bg_foyer":     (18,  14,  30),
    "bg_gallery":   (14,  10,  26),
    "bg_alcove":    (20,  16,  34),
    "bg_bedroom":   (10,   8,  20),
    "bg_default":   (16,  12,  28),
    # NPC — slime maiden
    "slime_body":   ( 60, 160,  90),
    "slime_acc":    (120, 220, 140),
    "slime_dark":   ( 30,  90,  55),
    # NPC — guardian
    "guard_body":   (110, 115, 145),
    "guard_acc":    (195, 205, 225),
    "guard_dark":   ( 60,  65,  90),
    # NPC — cherry
    "cherry_body":  (210, 110, 150),
    "cherry_acc":   (255, 195, 215),
    "cherry_dark":  (140,  65, 100),
}


def _c(name: str) -> tuple[int, int, int]:
    return _P[name]


# ── Helpers ────────────────────────────────────────────────────────────────────

def _pixel_noise(surf: pygame.Surface, amount: int = 8) -> None:
    """Add subtle grain to a surface for texture."""
    import random
    rng = random.Random(id(surf))
    w, h = surf.get_size()
    for _ in range(w * h // 6):
        x = rng.randint(0, w - 1)
        y = rng.randint(0, h - 1)
        v = rng.randint(-amount, amount)
        col = surf.get_at((x, y))
        r = max(0, min(255, col.r + v))
        g = max(0, min(255, col.g + v))
        b = max(0, min(255, col.b + v))
        surf.set_at((x, y), (r, g, b))


def _draw_wood_grain(surf: pygame.Surface, base: tuple, dark: tuple) -> None:
    """Horizontal grain lines on a tile."""
    w, h = surf.get_size()
    surf.fill(base)
    for y in range(0, h, 4):
        pygame.draw.line(surf, dark, (0, y), (w, y))
    _pixel_noise(surf, 6)


def _draw_stone(surf: pygame.Surface, base: tuple, dark: tuple) -> None:
    """Block pattern for stone/wall tiles."""
    w, h = surf.get_size()
    surf.fill(base)
    pygame.draw.line(surf, dark, (0, h // 2), (w, h // 2))
    pygame.draw.line(surf, dark, (w // 2, 0), (w // 2, h // 2))
    pygame.draw.line(surf, dark, (0, 0), (w, 0))
    _pixel_noise(surf, 5)


# ── TileArtProvider implementation ────────────────────────────────────────────

class LilyArtProvider:
    """Procedural art for Lily's Music Box."""

    def background(self, biome: str, width: int, height: int) -> pygame.Surface:
        base_color = {
            "foyer":   _c("bg_foyer"),
            "gallery": _c("bg_gallery"),
            "alcove":  _c("bg_alcove"),
            "bedroom": _c("bg_bedroom"),
        }.get(biome, _c("bg_default"))

        surf = pygame.Surface((width, height))
        surf.fill(base_color)

        # Subtle vertical gradient — slightly lighter at top
        for y in range(0, height, 2):
            frac = 1.0 - (y / height) * 0.3
            r = min(255, int(base_color[0] * frac + 20 * frac))
            g = min(255, int(base_color[1] * frac + 15 * frac))
            b = min(255, int(base_color[2] * frac + 25 * frac))
            pygame.draw.line(surf, (r, g, b), (0, y), (width, y))

        # Biome-specific details
        if biome == "gallery":
            self._draw_gallery_bg(surf, width, height)
        elif biome == "bedroom":
            self._draw_bedroom_bg(surf, width, height)

        return surf

    def _draw_gallery_bg(self, surf: pygame.Surface, w: int, h: int) -> None:
        """Portrait frames hinting at an art gallery."""
        frame_color = (60, 52, 78)
        inner_color = (30, 24, 44)
        frames = [(80, 60, 120, 90), (300, 40, 100, 130), (560, 70, 90, 110),
                  (720, 50, 110, 80), (200, 200, 80, 100), (500, 180, 100, 120)]
        for fx, fy, fw, fh in frames:
            pygame.draw.rect(surf, frame_color, (fx, fy, fw, fh), 0)
            pygame.draw.rect(surf, inner_color, (fx + 6, fy + 6, fw - 12, fh - 12), 0)
            pygame.draw.rect(surf, (80, 68, 100), (fx, fy, fw, fh), 2)

    def _draw_bedroom_bg(self, surf: pygame.Surface, w: int, h: int) -> None:
        """Starfield for the final bedroom."""
        import random
        rng = random.Random(99)
        for _ in range(80):
            sx = rng.randint(0, w)
            sy = rng.randint(0, h // 2)
            brightness = rng.randint(100, 220)
            pygame.draw.circle(surf, (brightness, brightness, brightness + 20), (sx, sy), 1)

    def bg_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        """Dark void tile for empty air cells — subtle vertical gradient + grain."""
        surf = pygame.Surface((tile_w, tile_h))
        base = _c("bg_default")
        surf.fill(base)
        # Very subtle top-to-bottom lightening so stacked air tiles read as depth
        for y in range(tile_h):
            frac = y / tile_h
            r = max(0, min(255, base[0] + int(8 * frac)))
            g = max(0, min(255, base[1] + int(6 * frac)))
            b = max(0, min(255, base[2] + int(12 * frac)))
            pygame.draw.line(surf, (r, g, b), (0, y), (tile_w, y))
        _pixel_noise(surf, 4)
        return surf

    def floor_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        surf = pygame.Surface((tile_w, tile_h))
        _draw_wood_grain(surf, _c("oak_light"), _c("oak_dark"))
        # Top highlight strip
        pygame.draw.rect(surf, (185, 152, 110), (0, 0, tile_w, 3))
        return surf

    def platform_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        surf = pygame.Surface((tile_w, tile_h))
        _draw_wood_grain(surf, _c("lav_light"), _c("lav_dark"))
        pygame.draw.rect(surf, (168, 138, 190), (0, 0, tile_w, 3))
        return surf

    def ghost_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        surf = pygame.Surface((tile_w, tile_h), pygame.SRCALPHA)
        surf.fill((148, 118, 170, 40))
        pygame.draw.rect(surf, (188, 158, 210, 90), (0, 0, tile_w, 3))
        return surf

    def wall_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        surf = pygame.Surface((tile_w, tile_h))
        _draw_stone(surf, _c("wall_mid"), _c("wall_dark"))
        # Right-edge accent for left wall (faces inward to the right)
        pygame.draw.line(surf, _c("wall_accent"), (tile_w - 1, 0), (tile_w - 1, tile_h))
        return surf

    def wall_right_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        """Right boundary wall — mirror of left wall, accent on left edge."""
        surf = pygame.Surface((tile_w, tile_h))
        _draw_stone(surf, _c("wall_mid"), _c("wall_dark"))
        pygame.draw.line(surf, _c("wall_accent"), (0, 0), (0, tile_h))
        return surf

    def ceiling_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        """Ceiling trim row — stone block with bottom highlight facing downward."""
        surf = pygame.Surface((tile_w, tile_h))
        _draw_stone(surf, _c("wall_dark"), _c("wall_mid"))
        pygame.draw.line(surf, _c("wall_accent"), (0, tile_h - 1), (tile_w, tile_h - 1))
        return surf

    def floor_slab_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        """Interior buried block — wood grain, no surface highlight."""
        surf = pygame.Surface((tile_w, tile_h))
        _draw_wood_grain(surf, _c("oak_dark"), (75, 55, 38))
        return surf

    def floor_left_edge_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        """Leftmost tile of a floor/platform run — surface + left corner cap."""
        surf = self.floor_tile(tile_w, tile_h)
        pygame.draw.line(surf, (185, 152, 110), (0, 0), (0, tile_h))
        return surf

    def floor_right_edge_tile(self, tile_w: int, tile_h: int) -> pygame.Surface:
        """Rightmost tile of a floor/platform run — surface + right corner cap."""
        surf = self.floor_tile(tile_w, tile_h)
        pygame.draw.line(surf, (185, 152, 110), (tile_w - 1, 0), (tile_w - 1, tile_h))
        return surf

    def npc_sprite(self, npc_id: str, width: int, height: int) -> pygame.Surface:
        surf = pygame.Surface((width, height), pygame.SRCALPHA)
        if npc_id == "archivist":
            self._draw_archivist(surf, width, height)
        elif npc_id == "slime_maiden":
            self._draw_slime_maiden(surf, width, height)
        elif npc_id == "guardian":
            self._draw_guardian(surf, width, height)
        elif npc_id == "cherry":
            self._draw_cherry(surf, width, height)
        else:
            self._draw_generic_npc(surf, width, height)
        return surf

    def _draw_archivist(self, surf: pygame.Surface, w: int, h: int) -> None:
        body = _c("arch_body")
        acc  = _c("arch_acc")
        dark = _c("arch_dark")
        # Robe body
        pygame.draw.rect(surf, body, (2, h // 3, w - 4, h * 2 // 3))
        # Head
        pygame.draw.ellipse(surf, body, (w // 4, 0, w // 2, h // 3))
        # Hood accent
        pygame.draw.rect(surf, acc, (2, h // 3, w - 4, 4))
        # Eyes
        pygame.draw.circle(surf, dark, (w // 2 - 3, h // 5), 2)
        pygame.draw.circle(surf, dark, (w // 2 + 3, h // 5), 2)
        # Book
        pygame.draw.rect(surf, dark, (w // 2, h // 2, w // 3, h // 4))
        pygame.draw.rect(surf, acc,  (w // 2 + 1, h // 2 + 1, w // 3 - 2, 2))

    def _draw_slime_maiden(self, surf: pygame.Surface, w: int, h: int) -> None:
        body  = _c("slime_body")
        acc   = _c("slime_acc")
        dark  = _c("slime_dark")
        # Blobby teardrop body — wider at bottom, rounded top
        pygame.draw.ellipse(surf, body, (1, h // 4, w - 2, h * 3 // 4))
        # Rounded head blending into body
        pygame.draw.ellipse(surf, body, (w // 4, 0, w // 2, h // 2))
        # Sheen highlight on upper-left
        pygame.draw.ellipse(surf, acc, (w // 4 + 2, 2, w // 5, h // 6))
        # Drip accent at bottom centre
        pygame.draw.ellipse(surf, dark, (w // 2 - 3, h - 8, 6, 8))
        # Eyes — large and soft
        pygame.draw.circle(surf, dark, (w // 2 - 4, h // 3), 3)
        pygame.draw.circle(surf, dark, (w // 2 + 4, h // 3), 3)
        pygame.draw.circle(surf, (255, 255, 255), (w // 2 - 3, h // 3 - 1), 1)
        pygame.draw.circle(surf, (255, 255, 255), (w // 2 + 5, h // 3 - 1), 1)

    def _draw_guardian(self, surf: pygame.Surface, w: int, h: int) -> None:
        body = _c("guard_body")
        acc  = _c("guard_acc")
        dark = _c("guard_dark")
        # Armoured torso — rectangular, broad
        pygame.draw.rect(surf, body, (1, h // 3, w - 2, h * 2 // 3))
        # Helmet — flat-topped
        pygame.draw.rect(surf, body, (w // 5, 0, w * 3 // 5, h // 3 + 2))
        # Visor slit
        pygame.draw.rect(surf, dark, (w // 4, h // 5, w // 2, 4))
        # Shoulder pauldrons
        pygame.draw.rect(surf, acc, (0, h // 3, 5, h // 5))
        pygame.draw.rect(surf, acc, (w - 5, h // 3, 5, h // 5))
        # Chest plate highlight
        pygame.draw.rect(surf, acc, (w // 3, h // 3 + 4, w // 3, 3))
        # Shield emblem — small diamond on chest
        cx = w // 2
        cy = h * 2 // 3
        pygame.draw.polygon(surf, acc, [(cx, cy - 5), (cx + 4, cy), (cx, cy + 5), (cx - 4, cy)])

    def _draw_cherry(self, surf: pygame.Surface, w: int, h: int) -> None:
        body = _c("cherry_body")
        acc  = _c("cherry_acc")
        dark = _c("cherry_dark")
        # Flowing gown — slightly flared at bottom
        points_gown = [
            (w // 3, h // 3),
            (w * 2 // 3, h // 3),
            (w - 2, h),
            (2, h),
        ]
        pygame.draw.polygon(surf, body, points_gown)
        # Head
        pygame.draw.ellipse(surf, acc, (w // 4, 0, w // 2, h // 3))
        # Hair — dark band across forehead
        pygame.draw.rect(surf, dark, (w // 4, h // 8, w // 2, 4))
        # Collar / neckline
        pygame.draw.rect(surf, acc, (w // 3, h // 3, w // 3, 4))
        # Eyes — delicate
        pygame.draw.circle(surf, dark, (w // 2 - 4, h // 5), 2)
        pygame.draw.circle(surf, dark, (w // 2 + 4, h // 5), 2)
        # Petal motif on gown — three small circles
        petal_y = h * 2 // 3
        for px_off in [-6, 0, 6]:
            pygame.draw.circle(surf, acc, (w // 2 + px_off, petal_y), 3)

    def _draw_generic_npc(self, surf: pygame.Surface, w: int, h: int) -> None:
        pygame.draw.rect(surf, _c("arch_body"), (2, h // 4, w - 4, h * 3 // 4))
        pygame.draw.ellipse(surf, _c("arch_body"), (w // 4, 0, w // 2, h // 3))

    def player_sprite(self, width: int, height: int) -> pygame.Surface:
        surf = pygame.Surface((width, height), pygame.SRCALPHA)
        body = _c("lily_body")
        acc  = _c("lily_acc")
        dark = _c("lily_dark")
        # Dress / body
        pygame.draw.rect(surf, body, (2, height // 3, width - 4, height * 2 // 3))
        # Head
        pygame.draw.ellipse(surf, body, (width // 4, 0, width // 2, height // 3 + 2))
        # Hair accent
        pygame.draw.rect(surf, dark, (0, height // 6, width, 4))
        # Collar
        pygame.draw.rect(surf, acc, (2, height // 3, width - 4, 3))
        # Eyes
        pygame.draw.circle(surf, dark, (width // 2 - 3, height // 6), 2)
        pygame.draw.circle(surf, dark, (width // 2 + 3, height // 6), 2)
        return surf

    def objective_sprite(self, size: int) -> pygame.Surface:
        surf = pygame.Surface((size, size), pygame.SRCALPHA)
        gold = _c("star_gold")
        glow = (*_c("star_glow"), 160)
        cx, cy = size // 2, size // 2
        r_outer = size // 2 - 1
        r_inner = size // 4

        # 5-point star
        points = []
        for i in range(10):
            angle = math.radians(i * 36 - 90)
            r = r_outer if i % 2 == 0 else r_inner
            points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
        if len(points) >= 3:
            pygame.draw.polygon(surf, glow, points)
            pygame.draw.polygon(surf, gold, points, 1)
        return surf

    def decorative_tile(self, role: str, tile_w: int, tile_h: int) -> pygame.Surface | None:
        """Procedural art has no ornamental tile images — let renderer use bg."""
        return None

    def air_layout(self, solid_tiles, cols, rows, seed) -> dict:
        """No architectural decoration for the procedural fallback art."""
        return {}

    def updraft_band(self, width: int, height: int, alpha_frac: float) -> pygame.Surface:
        surf = pygame.Surface((width, height), pygame.SRCALPHA)
        alpha = int(100 * alpha_frac)
        lo = _c("updraft_lo")
        hi = _c("updraft_hi")
        r = int(lo[0] * (1 - alpha_frac) + hi[0] * alpha_frac)
        g = int(lo[1] * (1 - alpha_frac) + hi[1] * alpha_frac)
        b = int(lo[2] * (1 - alpha_frac) + hi[2] * alpha_frac)
        surf.fill((r, g, b, alpha))
        return surf
