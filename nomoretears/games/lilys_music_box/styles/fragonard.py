"""
games/lilys_music_box/styles/fragonard.py
-----------------------------------------
FRAGONARD_GARDEN_FLOW visual effect.

When the guardian_gothic tileset is active Lily's sprite is handled entirely
by this module.  No anatomy is drawn in HIDDEN_GARDEN state.  The garden
reveals Lily's presence only through environmental evidence.

HIDDEN_GARDEN (on ground, invisible)
  Lily's sprite alpha = 0.  A cluster of leaf and petal particles drifts
  upward from her approximate foot position.  A faint circular shadow sits
  on the ground beneath her.  Moving right or left produces a brief
  disturbance wave of leaves.

SWINGING (pendulum active)
  Lily is fully visible seated in an ornate Rococo garden swing.
  Rendered elements:
    chain     — braided golden rope from player head up to the anchor pulley
    seat      — curved wooden plank beneath the player, carved with leaf ornament
    side ropes — thin ropes from each end of the seat up to the pivot
    two garden attendants — silhouette figures flanking the pulley, each with a
                           powdered wig and an arm raised toward the chain end
  The attendants are pure storytelling: they visually explain the lifting
  mechanism without creating any gameplay dependency.

CHAIN_SEEK (brief launch animation)
  The chain extends from the player's head upward at the computed angle.
  Chain length grows from 0 to full over CHAIN_SEEK_TIME seconds.
  The player is visible, slightly crouched (y offset).

FALLING (freefall after Release)
  Lily is drawn with a stretched-upward silhouette suggesting airborne momentum.

BRANCH_PERCH (standing on branch node)
  Lily is drawn normally, slightly smaller with a visible weight-on-branch pose.

PERFORMANCE CONTRACT
  draw_trail()   — foliage canvas blit + active particle blits (N ≤ 60).
  draw_player()  — swing geometry (chain, seat, attendants) + sprite blit.
  update()       — particle physics, spawn logic.
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

import pygame

from engine.physics import PLAYER_W, PLAYER_H
from engine.room_graph import TILE_SCALE, TILE_W, TILE_H, ROOM_COLS, ROOM_ROWS

if TYPE_CHECKING:
    from engine.entities import PlayerEntity
    from engine.state import GameState
    from engine.proc_gen import GeneratedLayout

_CANVAS_W = ROOM_COLS * TILE_W
_CANVAS_H = ROOM_ROWS * TILE_H

# ── Fragonard palette ─────────────────────────────────────────────────────────

BLUSH_1    = (246, 211, 189)
BLUSH_2    = (236, 180, 152)
SAGE_1     = (143, 174, 118)
SAGE_2     = (107, 148,  82)
SAGE_3     = ( 68, 116,  48)
IVORY      = (255, 248, 220)
GOLD_ROPE  = (205, 158,  40)
GOLD_ROPE2 = (230, 185,  72)
BARK_1     = ( 92,  58,  22)
BARK_2     = (124,  80,  30)
SKY_BLUE   = (178, 213, 229)
SHADOW_CLR = (  0,   0,   0, 45)
WIG_WHITE  = (245, 242, 230)
COAT_OLIVE = ( 98, 112,  56)


def _s(n: float) -> int:
    return max(1, round(n * TILE_SCALE))


# ── Foliage particle ──────────────────────────────────────────────────────────

@dataclass
class _Leaf:
    x:     float
    y:     float
    vx:    float
    vy:    float
    size:  int
    color: tuple[int, int, int]
    alpha: int = 220
    life:  float = 1.0    # 0.0 = dead
    rot:   float = 0.0    # rotation angle (radians) for leaf shape
    spin:  float = 0.0    # rotation rate (rad/s)


# Leaf shape types — index into the list
_LEAF_SHAPES = ("oval", "teardrop", "petal")

_LEAF_PALETTE = (SAGE_1, SAGE_2, SAGE_3, BLUSH_1, BLUSH_2, IVORY)


# ── FragonardGardenFlow ───────────────────────────────────────────────────────

class FragonardGardenFlow:
    """
    FRAGONARD_GARDEN_FLOW — the room style for the guardian_gothic tileset.

    The style receives the active SwingAscendAbility via the constructor so it
    can read swing geometry (anchor, chain_len, angle) for rendering the swing
    without duplicating state.
    """

    def __init__(self, swing_ability) -> None:
        """
        swing_ability: SwingAscendAbility instance (same object registered in
        GameBundle.rulesets["guardian_gothic"].ability).
        """
        self._ability = swing_ability

        # Foliage particle system
        self._leaves: list[_Leaf] = []
        self._leaf_timer: float = 0.0
        self._disturbance: float = 0.0   # 0–1, decay from walking in garden

        # Foliage canvas — accumulates permanent leaf silhouettes like Klimt's
        # splash canvas.  Cleared on room transition.
        self._foliage_canvas: pygame.Surface | None = None

        # Pre-baked attendant surfaces (rebuilt once per pygame session)
        self._attendant_surf: pygame.Surface | None = None
        self._seat_surf:      pygame.Surface | None = None

        # RNG seeded per room
        self._rng = random.Random(42)

        # Previous player position for disturbance detection
        self._prev_px: float = 0.0
        self._game_time: float = 0.0

    # ── RoomStyle protocol ────────────────────────────────────────────────────

    def on_room_change(self) -> None:
        """Clear per-room state on room transition."""
        self._leaves.clear()
        self._foliage_canvas = None
        self._leaf_timer     = 0.0
        self._disturbance    = 0.0
        self._game_time      = 0.0

    def update(
        self,
        dt: float,
        player: "PlayerEntity",
        state: "GameState",
        layout: "GeneratedLayout | None" = None,
    ) -> None:
        self._game_time += dt

        # Detect horizontal movement for leaf disturbance
        dx = abs(player.body.px - self._prev_px)
        self._prev_px = player.body.px
        if dx > 2.0 and not self._ability.player_visible:
            self._disturbance = min(1.0, self._disturbance + dx * 0.03)
        self._disturbance = max(0.0, self._disturbance - dt * 0.6)

        # Spawn leaves in HIDDEN_GARDEN state
        hidden = not self._ability.player_visible
        if hidden:
            spawn_rate = 0.12 + self._disturbance * 0.06
            self._leaf_timer += dt
            while self._leaf_timer >= spawn_rate and len(self._leaves) < 60:
                self._leaf_timer -= spawn_rate
                self._spawn_leaf(player.body.center_x, player.body.center_y)

        # Update existing leaves
        for lf in self._leaves:
            lf.x  += lf.vx * dt
            lf.y  += lf.vy * dt
            lf.vy -= 18.0 * dt         # gentle upward drift
            lf.vx += self._rng.uniform(-8.0, 8.0) * dt
            lf.rot += lf.spin * dt
            lf.life -= dt / 2.2
            lf.alpha = int(max(0, min(220, lf.life * 220)))

        self._leaves = [lf for lf in self._leaves if lf.life > 0]

        # Occasionally commit a drifting leaf into the permanent canvas
        if hidden and self._foliage_canvas is None:
            self._foliage_canvas = pygame.Surface(
                (_CANVAS_W, _CANVAS_H), pygame.SRCALPHA
            )

    def draw_trail(self, surface: pygame.Surface) -> None:
        """
        Draw environmental evidence of Lily's presence in the garden.

        In HIDDEN_GARDEN: foliage canvas + active leaf particles.
        In all other states: no trail (Lily is visible, garden reacts to swing).
        """
        if self._ability.player_visible:
            return

        # Permanent leaf silhouettes (committed by previous leaf deaths)
        if self._foliage_canvas is not None:
            surface.blit(self._foliage_canvas, (0, 0))

        # Active particles
        for lf in self._leaves:
            self._draw_leaf(surface, lf)

    def draw_player(
        self,
        surface: pygame.Surface,
        player: "PlayerEntity",
        tick: int,
    ) -> None:
        """
        Draw Lily according to the current swing state.

        All player art is drawn procedurally — no external sprite surface is
        used.  This follows the same contract as KlimtGoldLeafFlow / EscherVisualEffect
        where the style owns the full player render for its tileset.
        """
        state = self._ability._state

        if not self._ability.player_visible:
            # HIDDEN_GARDEN — draw only a soft ground shadow
            self._draw_ground_shadow(surface, player)
            return

        # Draw the swing geometry when swinging / seeking
        if self._ability.is_swinging or state.name == "CHAIN_SEEK":
            self._draw_swing(surface, player)
        elif state.name == "FALLING":
            self._draw_falling_player(surface, player)
        elif state.name == "BRANCH_PERCH":
            self._draw_perch_player(surface, player)
        else:
            # Fallback: standing blush silhouette
            self._draw_standing_player(surface, player)

    # ── Leaf particle internals ────────────────────────────────────────────────

    def _spawn_leaf(self, cx: float, cy: float) -> None:
        spread = 28 + self._disturbance * 18
        x  = cx + self._rng.uniform(-spread, spread)
        y  = cy + self._rng.uniform(-8, 10)
        vx = self._rng.uniform(-22.0, 22.0)
        vy = self._rng.uniform(-35.0, -10.0)
        sz = self._rng.randint(_s(3), _s(7))
        color = self._rng.choice(_LEAF_PALETTE)
        spin  = self._rng.uniform(-2.5, 2.5)
        self._leaves.append(_Leaf(x, y, vx, vy, sz, color, spin=spin))

    def _draw_leaf(self, surface: pygame.Surface, lf: _Leaf) -> None:
        if lf.alpha <= 0 or lf.size < 1:
            return
        sz = lf.size
        leaf_surf = pygame.Surface((sz * 4, sz * 4), pygame.SRCALPHA)
        cx, cy = sz * 2, sz * 2
        r, g, b = lf.color
        rgba = (r, g, b, lf.alpha)

        shape_idx = int(lf.life * 3) % len(_LEAF_SHAPES)
        shape = _LEAF_SHAPES[shape_idx]

        if shape == "oval":
            pygame.draw.ellipse(leaf_surf, rgba,
                                (cx - sz, cy - sz // 2, sz * 2, sz))
        elif shape == "teardrop":
            pts = [(cx, cy - sz), (cx + sz, cy + sz), (cx - sz, cy + sz)]
            pygame.draw.polygon(leaf_surf, rgba, pts)
        else:  # petal
            pygame.draw.ellipse(leaf_surf, rgba,
                                (cx - sz // 2, cy - sz, sz, sz * 2))

        rotated = pygame.transform.rotate(leaf_surf, math.degrees(lf.rot))
        rx = int(lf.x) - rotated.get_width() // 2
        ry = int(lf.y) - rotated.get_height() // 2
        surface.blit(rotated, (rx, ry))

    def _draw_ground_shadow(
        self, surface: pygame.Surface, player: "PlayerEntity"
    ) -> None:
        """Faint oval shadow on the floor — marks Lily's position while hidden."""
        sw, sh = _s(22), _s(6)
        shadow = pygame.Surface((sw * 2, sh * 2), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow, (0, 0, 0, 35),
                            (0, 0, sw * 2, sh * 2))
        sx = int(player.body.px + PLAYER_W / 2 - sw)
        sy = int(player.body.py + PLAYER_H - sh // 2)
        surface.blit(shadow, (sx, sy))

    # ── Swing visual internals ─────────────────────────────────────────────────

    def _draw_swing(
        self, surface: pygame.Surface, player: "PlayerEntity"
    ) -> None:
        """
        Draw the full swing assembly: chain → pulley → attendants, seat, ropes.
        """
        data = self._ability.swing_data
        ac = data["anchor_col"]
        ar = data["anchor_row"]
        chain_len  = data["chain_len"]
        angle      = data["angle"]
        seek_frac  = data["seek_frac"]

        # Anchor pixel centre
        ax = float(ac * TILE_W + TILE_W // 2)
        ay = float(ar * TILE_H + TILE_H // 2)

        # Player head and feet positions
        px = player.body.px + PLAYER_W / 2
        py = player.body.py + PLAYER_H / 2

        # During CHAIN_SEEK, draw only a partial chain extending toward anchor
        if data["is_seek"]:
            partial_x = ax + (px - ax) * (1.0 - seek_frac)
            partial_y = ay + (py - ay) * (1.0 - seek_frac)
            self._draw_rope(surface,
                            int(px), int(py), int(partial_x), int(partial_y))
            # Draw player crouched
            player_surf = self._make_seated_player()
            surface.blit(player_surf,
                         (int(player.body.px), int(player.body.py - _s(4))))
            return

        # Full swing: rope from player head to pulley
        head_x = int(px)
        head_y = int(player.body.py)
        self._draw_rope(surface, head_x, head_y, int(ax), int(ay))

        # Pulley ornament at anchor
        self._draw_pulley(surface, int(ax), int(ay))

        # Two garden attendants flanking the anchor
        self._draw_attendants(surface, int(ax), int(ay))

        # Swing seat (horizontal plank under player)
        seat_y = int(player.body.py + PLAYER_H - _s(4))
        seat_left  = int(px - _s(18))
        seat_right = int(px + _s(18))
        self._draw_seat(surface, seat_left, seat_y, seat_right)

        # Side ropes from seat ends to head
        rope_color = (int(GOLD_ROPE[0] * 0.85), int(GOLD_ROPE[1] * 0.85),
                      int(GOLD_ROPE[2] * 0.85))
        pygame.draw.line(surface, rope_color,
                         (seat_left, seat_y), (head_x, head_y), _s(2))
        pygame.draw.line(surface, rope_color,
                         (seat_right, seat_y), (head_x, head_y), _s(2))

        # Player sprite seated
        player_surf = self._make_seated_player()
        surface.blit(player_surf,
                     (int(player.body.px), int(player.body.py)))

    def _draw_rope(
        self,
        surface: pygame.Surface,
        x1: int, y1: int,
        x2: int, y2: int,
    ) -> None:
        """
        Draw a braided golden rope as two offset lines — the visual weight of
        Rococo garden chains without requiring a separate sprite asset.
        """
        # Outer rope (slightly thicker, darker gold)
        pygame.draw.line(surface, BARK_2, (x1, y1), (x2, y2), _s(4))
        # Inner braid highlight
        offset = 2
        pygame.draw.line(surface, GOLD_ROPE2,
                         (x1 + offset, y1), (x2 + offset, y2), _s(2))
        pygame.draw.line(surface, GOLD_ROPE,
                         (x1 - offset, y1), (x2 - offset, y2), _s(1))

    def _draw_pulley(self, surface: pygame.Surface, cx: int, cy: int) -> None:
        """Ornamental pulley wheel at the anchor point."""
        r = _s(8)
        pygame.draw.circle(surface, BARK_1, (cx, cy), r)
        pygame.draw.circle(surface, GOLD_ROPE, (cx, cy), r, _s(2))
        # Cross-spokes
        for angle in (0, math.pi / 3, 2 * math.pi / 3):
            sx = int(cx + r * 0.7 * math.cos(angle))
            sy = int(cy + r * 0.7 * math.sin(angle))
            ex = int(cx - r * 0.7 * math.cos(angle))
            ey = int(cy - r * 0.7 * math.sin(angle))
            pygame.draw.line(surface, GOLD_ROPE, (sx, sy), (ex, ey), _s(1))
        # Centre hub
        pygame.draw.circle(surface, GOLD_ROPE2, (cx, cy), _s(3))

    def _draw_attendants(
        self, surface: pygame.Surface, cx: int, cy: int
    ) -> None:
        """
        Two garden attendants flanking the pulley.  Silhouette only — they
        exist to explain the chain mechanics through visual storytelling.

        Left attendant: leaning away (right arm raised, pulling chain).
        Right attendant: mirror image.
        """
        for side in (-1, 1):
            ox = cx + side * _s(52)
            oy = cy - _s(8)
            self._draw_single_attendant(surface, ox, oy, facing_right=(side > 0))

    def _draw_single_attendant(
        self,
        surface: pygame.Surface,
        cx: int, cy: int,
        facing_right: bool,
    ) -> None:
        """
        Draw a Rococo silhouette figure: body, wig, raised arm.
        Proportions suggest an 18th-century gentleman in a coat.
        """
        h = _s(38)
        w = _s(14)
        flip = 1 if facing_right else -1

        # Body (torso + legs as filled rect)
        body_top = cy - h // 2
        pygame.draw.rect(surface, COAT_OLIVE,
                         (cx - w // 2, body_top, w, h))
        # Coat edges (highlight)
        pygame.draw.rect(surface, (130, 148, 80),
                         (cx - w // 2, body_top, w, h), _s(1))

        # Head (dark oval)
        hd_cx, hd_cy = cx, body_top - _s(8)
        pygame.draw.ellipse(surface, BARK_1,
                            (hd_cx - _s(5), hd_cy - _s(6), _s(10), _s(12)))

        # Powdered wig (white puff above head)
        wig_y = hd_cy - _s(12)
        wig_surf = pygame.Surface((_s(20), _s(16)), pygame.SRCALPHA)
        pygame.draw.ellipse(wig_surf, (*WIG_WHITE, 210),
                            (0, 0, _s(20), _s(16)))
        surface.blit(wig_surf,
                     (hd_cx - _s(10), wig_y))

        # Raised arm toward the chain (opposite side from body lean)
        arm_x0 = cx + flip * _s(6)
        arm_y0 = body_top + _s(8)
        arm_x1 = cx + flip * _s(22)
        arm_y1 = body_top - _s(18)
        pygame.draw.line(surface, BARK_1,
                         (arm_x0, arm_y0), (arm_x1, arm_y1), _s(4))

    def _draw_seat(
        self,
        surface: pygame.Surface,
        x1: int, y: int, x2: int,
    ) -> None:
        """Carved wooden swing seat — horizontal plank with leaf-end ornaments."""
        w = x2 - x1
        h = _s(6)
        # Main plank
        pygame.draw.rect(surface, BARK_2, (x1, y, w, h))
        # Top highlight
        pygame.draw.line(surface, IVORY, (x1, y), (x2, y), _s(1))
        # Bottom shadow
        pygame.draw.line(surface, BARK_1,
                         (x1, y + h - 1), (x2, y + h - 1), _s(1))
        # Leaf ornament end-caps
        for ex, sign in ((x1, -1), (x2, 1)):
            lx = ex + sign * _s(2)
            pts = [
                (lx, y - _s(4)),
                (lx + sign * _s(7), y + h // 2),
                (lx, y + h + _s(3)),
            ]
            pygame.draw.polygon(surface, SAGE_1, pts)
            pygame.draw.polygon(surface, SAGE_2, pts, _s(1))

    def _make_seated_player(self) -> pygame.Surface:
        """
        Minimal seated Lily silhouette.

        WHY a separate surface: the base player sprite is designed for standing.
        The seated variant is shorter and wider — the player is compressed into
        a sitting position.  We bake it once per call at fixed dimensions.
        """
        w, h = PLAYER_W + _s(6), PLAYER_H - _s(8)
        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        # Body blob — soft blush silhouette
        pygame.draw.ellipse(surf, (*BLUSH_1, 210),
                            (_s(2), _s(4), w - _s(4), h - _s(4)))
        # Head
        hcx, hcy = w // 2, _s(6)
        pygame.draw.circle(surf, (*BLUSH_2, 220), (hcx, hcy), _s(7))
        # Hair suggestion (dark oval on top half)
        pygame.draw.ellipse(surf, (72, 44, 22, 200),
                            (hcx - _s(6), hcy - _s(6), _s(12), _s(7)))
        return surf

    # ── Non-swing player poses ─────────────────────────────────────────────────
    # All poses are drawn as procedural BLUSH silhouettes — no external sprite
    # surface is consumed.  Each pose bakes a tiny Surface, transforms it, and
    # blits.  Sizes stay near PLAYER_W × PLAYER_H so hitbox and visual align.

    def _make_standing_silhouette(self, w: int, h: int) -> pygame.Surface:
        """Upright Lily silhouette at (w, h) — body ellipse + head circle."""
        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        # Body
        pygame.draw.ellipse(surf, (*BLUSH_1, 215),
                            (_s(2), h // 3, w - _s(4), h * 2 // 3))
        # Head
        hcx, hcy = w // 2, h // 5
        pygame.draw.circle(surf, (*BLUSH_2, 220), (hcx, hcy), max(3, w // 4))
        # Hair
        pygame.draw.ellipse(surf, (72, 44, 22, 200),
                            (hcx - w // 4, hcy - max(3, w // 4),
                             w // 2, max(3, w // 4)))
        return surf

    def _draw_standing_player(
        self,
        surface: pygame.Surface,
        player: "PlayerEntity",
    ) -> None:
        """Lily standing — used as fallback when no swing state is active."""
        sil = self._make_standing_silhouette(PLAYER_W, PLAYER_H)
        surface.blit(sil, (int(player.body.px), int(player.body.py)))

    def _draw_falling_player(
        self,
        surface: pygame.Surface,
        player: "PlayerEntity",
    ) -> None:
        """Lily in freefall — stretched upward, arms out."""
        # Taller and narrower than standing (airborne stretch)
        w = max(4, int(PLAYER_W * 0.80))
        h = max(4, int(PLAYER_H * 1.25))
        sil = self._make_standing_silhouette(w, h)
        surface.blit(sil,
                     (int(player.body.px + (PLAYER_W - w) // 2),
                      int(player.body.py - (h - PLAYER_H) // 2)))

    def _draw_perch_player(
        self,
        surface: pygame.Surface,
        player: "PlayerEntity",
    ) -> None:
        """Lily balanced on a branch — wider, shorter crouch pose."""
        # Wider and shorter than standing (weight-on-branch squat)
        w = max(4, int(PLAYER_W * 1.05))
        h = max(4, int(PLAYER_H * 0.90))
        sil = self._make_standing_silhouette(w, h)
        surface.blit(sil,
                     (int(player.body.px),
                      int(player.body.py + (PLAYER_H - h))))
