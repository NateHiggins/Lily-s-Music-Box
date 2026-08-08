"""
games/lilys_music_box/styles/klimt.py
--------------------------------------
KLIMT_GOLD_LEAF_FLOW visual effect.

When the klimt_dining tileset is active, Lily's sprite is replaced by an
animated paint event.  No anatomy is rendered.  Presence is communicated
through motion, rhythm, and the accumulation of pigment falling from above.

PAINT HEAD (live player)
  Pre-baked on a canvas 3× the hitbox so pigment can bloom outward.
  Composed of: indigo/purple central mass, gold ribbon crown, decorative
  Klimt circles, purple arc sweeps.  Bucketed by (phase_step, speed_bucket,
  facing_right) so no surface is allocated during gameplay.

PAINT DROPS
  Slow colour drops fall from the top of the screen toward Lily's position,
  drifting slightly as they descend.  Each drop is rendered as a teardrop
  (round body + tapered tail) in Klimt palette colours.

  When a drop reaches its splash altitude it permanently marks the canvas
  with a radial impasto burst — flat splatter strokes radiating outward,
  plus a central blob and Klimt accent ornaments.

  The effect reads as slow heavy paint falling under gravity and detonating
  in place, gradually covering the room in colour as Lily moves through it.

PERMANENT SPLASH CANVAS
  A single SRCALPHA canvas the size of the screen accumulates all splash
  impacts.  draw_trail() blits it in one call — zero per-frame iteration.
  Cleared on room transition.

PERFORMANCE CONTRACT
  draw_trail()   — one Surface.blit() + N small drop surface blits (N ≤ 40).
  draw_player()  — one blit from pre-baked frame cache; no allocations.
  update()       — drop physics, spawn logic, splash commit to canvas.
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

# ── Screen dimensions (canvas size) ───────────────────────────────────────────

_CANVAS_W = ROOM_COLS * TILE_W   # 1280
_CANVAS_H = ROOM_ROWS * TILE_H   # 720


# ── Palette ────────────────────────────────────────────────────────────────────

GOLD_1   = (212, 175,  55)
GOLD_2   = (230, 198,  92)
GOLD_3   = (240, 216, 120)
AMBER_1  = (184, 121,  10)
AMBER_2  = (199, 138,  26)
PURPLE_1 = ( 90,  46, 138)
PURPLE_2 = (115,  64, 168)
PURPLE_3 = (138,  92, 199)
INDIGO   = ( 59,  47, 107)
IVORY    = (255, 248, 231)
BLACK_A  = ( 21,  10,   0)

# Ordered palette used by accent ornaments — index stored on each child.
_PALETTE: tuple[tuple[int, int, int], ...] = (
    GOLD_1, GOLD_2, GOLD_3, AMBER_1, AMBER_2,
    PURPLE_1, PURPLE_2, PURPLE_3, INDIGO,
)

# Brushstroke colour triples (body, highlight, shadow) cycled per drop.
# Each trio is chosen to feel like a physically coherent pigment mix.
_STROKE_SEQUENCE: tuple[tuple, ...] = (
    (GOLD_1,   GOLD_3,            AMBER_1),
    (PURPLE_2, PURPLE_3,          INDIGO),
    (AMBER_2,  GOLD_2,            (90,  50,  4)),
    (GOLD_2,   IVORY,             AMBER_2),
    (PURPLE_1, PURPLE_2,          INDIGO),
    (AMBER_1,  GOLD_3,            AMBER_2),
    (GOLD_3,   IVORY,             GOLD_1),
    (PURPLE_3, (160, 120, 220),   PURPLE_1),
)


def _s(n: float) -> int:
    """Scale a legacy 1-px value by TILE_SCALE (1.25 at standard resolution)."""
    return max(1, round(n * TILE_SCALE))


def _lighten(c: tuple[int, int, int], amt: int) -> tuple[int, int, int]:
    return (min(255, c[0] + amt), min(255, c[1] + amt), min(255, c[2] + amt))


def _darken(c: tuple[int, int, int], amt: int) -> tuple[int, int, int]:
    return (max(0, c[0] - amt), max(0, c[1] - amt), max(0, c[2] - amt))


# ── Trail smear constants ──────────────────────────────────────────────────────

SAMPLE_INTERVAL = 0.055     # seconds between smear deposits while moving
IDLE_INTERVAL   = 0.30      # slower deposit rate while standing still
MAX_STROKE_W    = 16        # maximum brushstroke width in px
MIN_STROKE_W    = 5         # minimum brushstroke width in px

# ── Drop behaviour constants ───────────────────────────────────────────────────

DROP_SPAWN_INTERVAL  = 0.32     # seconds between new drops spawning
DROP_FALL_SPEED_MIN  = 75.0     # slowest drop fall (px / s)
DROP_FALL_SPEED_MAX  = 150.0    # fastest drop fall (px / s)
DROP_DRIFT_MAX       = 22.0     # max horizontal drift per second
DROP_X_JITTER        = 45       # random x offset from Lily centre on spawn
DROP_SIZE_MIN        = 4        # min drop radius (px)
DROP_SIZE_MAX        = 8        # max drop radius (px)
DROP_MAX             = 40       # cap live drops to avoid performance spikes

# How far above Lily's foot the drop splashes — keeps splatter near the ground
SPLASH_Y_OFFSET      = 0        # 0 = splash right at Lily's vertical centre


# ── Ornament surfaces ─────────────────────────────────────────────────────────

_ORN_CACHE: dict[tuple, pygame.Surface] = {}


def _bake_ornament(
    kind: str, size: int, color: tuple[int, int, int], alpha: int
) -> pygame.Surface:
    """Render one ornament type at the given alpha onto a fresh SRCALPHA surface."""
    dim = size * 2 + 6
    surf = pygame.Surface((dim, dim), pygame.SRCALPHA)
    cx, cy = dim // 2, dim // 2
    r, g, b = color
    rgba = (r, g, b, alpha)

    if kind == "circle":
        pygame.draw.circle(surf, rgba, (cx, cy), size)
        if size >= 4:
            pygame.draw.circle(
                surf, (*BLACK_A, alpha // 3), (cx, cy), size, max(1, size // 4)
            )

    elif kind == "square":
        half = size
        pygame.draw.rect(surf, rgba, (cx - half, cy - half, half * 2, half * 2))
        hi_a = min(255, alpha + 50)
        pygame.draw.rect(
            surf, (*GOLD_2, hi_a),
            (cx - half, cy - half, half * 2, half * 2),
            max(1, half // 4),
        )

    elif kind == "fleck":
        pygame.draw.ellipse(
            surf, rgba,
            (cx - size, cy - max(1, size // 2), size * 2, max(2, size)),
        )

    elif kind == "arc":
        steps = max(6, size * 2)
        for i in range(steps):
            t = i / steps
            angle = t * math.pi * 1.5
            r_arc = size * (0.35 + 0.65 * t)
            ax = cx + r_arc * math.cos(angle)
            ay = cy + r_arc * math.sin(angle)
            dot_r = max(1, round(size * 0.30 * (1.0 - t * 0.5)))
            dot_a = int(alpha * (0.9 - t * 0.25))
            pygame.draw.circle(surf, (r, g, b, dot_a), (round(ax), round(ay)), dot_r)

    elif kind == "mosaic":
        half = size
        pygame.draw.rect(surf, rgba, (cx - half, cy - half, half * 2, half * 2))
        inner = max(1, half - 2)
        diamond = [
            (cx, cy - inner), (cx + inner, cy),
            (cx, cy + inner), (cx - inner, cy),
        ]
        pygame.draw.polygon(surf, (*GOLD_3, min(255, alpha + 30)), diamond)

    return surf


def _get_ornament(kind: str, size: int, color_idx: int, alpha: int) -> pygame.Surface:
    key = (kind, size, color_idx % len(_PALETTE), alpha)
    if key not in _ORN_CACHE:
        _ORN_CACHE[key] = _bake_ornament(
            kind, size, _PALETTE[color_idx % len(_PALETTE)], alpha
        )
    return _ORN_CACHE[key]


_KINDS = ("circle", "square", "fleck", "arc", "mosaic")

_KIND_SIZES: dict[str, tuple[int, int]] = {
    "circle": (3, 7),
    "square": (2, 5),
    "fleck":  (2, 4),
    "arc":    (4, 9),
    "mosaic": (2, 5),
}

_KIND_COLORS: dict[str, tuple[int, ...]] = {
    "circle": (0, 1, 2, 3, 4),
    "square": (5, 6, 7, 8),
    "fleck":  (0, 1, 2),
    "arc":    (0, 5, 6),
    "mosaic": (3, 4, 5, 6),
}


# ── Canvas painting helpers ───────────────────────────────────────────────────

def _smear_taper(t: float) -> float:
    """
    Width profile for a trail smear: quick swell then long, slow taper.

    0 → 0.25 : 20 % → 100 %  (brush biting into canvas)
    0.25 → 1  : 100 % → ~5 %  (brush lifting away, slow power-curve)

    The exponent 0.65 keeps the stroke wide for a long time before it pinches,
    matching how a loaded brush drags pigment across canvas.
    """
    if t < 0.25:
        return 0.20 + 0.80 * (t / 0.25)
    return 0.05 + 0.95 * ((1.0 - t) / 0.75) ** 0.65


def _paint_smear(
    canvas: pygame.Surface,
    x1: float, y1: float,
    x2: float, y2: float,
    width: int,
    body_col: tuple[int, int, int],
    hi_col:   tuple[int, int, int],
    sh_col:   tuple[int, int, int],
    body_alpha: int = 215,
    rng: "random.Random | None" = None,
) -> None:
    """
    Persistent trail smear: tapered brushstroke with a gentle loving curve.

    Uses _smear_taper() so the stroke starts narrow, swells quickly, then
    tapers slowly to a fine point — matching a loaded brush dragging pigment.

    Wobble is intentionally subtle (3–12 % of stroke width) so each smear
    reads as a deliberate, graceful brushstroke rather than a chaotic scribble.
    Shading (highlight + shadow strips) gives impasto body depth.
    """
    dx = x2 - x1
    dy = y2 - y1
    length = math.hypot(dx, dy)

    if length < 0.5:
        r = max(1, round(width * 0.3))
        cx_, cy_ = round(x1), round(y1)
        pygame.draw.circle(canvas, (*body_col, body_alpha), (cx_, cy_), r)
        if r > 2:
            pygame.draw.circle(canvas, (*hi_col, min(255, body_alpha + 30)),
                               (cx_ - max(1, r // 4), cy_ - max(1, r // 4)),
                               max(1, r // 3))
        return

    ux = dx / length
    uy = dy / length
    px_vec = -uy
    py_vec =  ux

    N = max(6, min(28, round(length / 2.2)))

    # Gentle wobble — sine wave perpendicular to stroke direction.
    # Amplitude capped at 3–12 % of stroke width for a loving, controlled curve.
    if rng is not None:
        wob_freq  = rng.uniform(0.8, 2.0)
        wob_phase = rng.uniform(0.0, 2 * math.pi)
        wob_amp   = width * rng.uniform(0.03, 0.12)
    else:
        wob_freq = wob_phase = wob_amp = 0.0

    left_body:  list[tuple[float, float]] = []
    right_body: list[tuple[float, float]] = []
    left_hi:    list[tuple[float, float]] = []
    right_hi:   list[tuple[float, float]] = []
    left_sh:    list[tuple[float, float]] = []
    right_sh:   list[tuple[float, float]] = []

    for i in range(N + 1):
        t  = i / N
        hw = width * _smear_taper(t) / 2

        wob = wob_amp * math.sin(wob_freq * t * math.pi * 2.0 + wob_phase)
        cx = x1 + t * dx + px_vec * wob
        cy = y1 + t * dy + py_vec * wob

        left_body.append( (cx + px_vec * hw,  cy + py_vec * hw))
        right_body.append((cx - px_vec * hw,  cy - py_vec * hw))

        hi_off = hw * 0.52
        hi_w   = max(0.5, hw * 0.36)
        left_hi.append( (cx + px_vec * (hi_off + hi_w), cy + py_vec * (hi_off + hi_w)))
        right_hi.append((cx + px_vec * (hi_off - hi_w), cy + py_vec * (hi_off - hi_w)))
        left_sh.append( (cx - px_vec * (hi_off - hi_w), cy - py_vec * (hi_off - hi_w)))
        right_sh.append((cx - px_vec * (hi_off + hi_w), cy - py_vec * (hi_off + hi_w)))

    body_pts = left_body + list(reversed(right_body))
    if len(body_pts) >= 3:
        pygame.draw.polygon(canvas, (*body_col, body_alpha), body_pts)

    hi_pts = left_hi + list(reversed(right_hi))
    if len(hi_pts) >= 3:
        pygame.draw.polygon(canvas, (*hi_col, min(255, body_alpha + 35)), hi_pts)

    sh_pts = left_sh + list(reversed(right_sh))
    if len(sh_pts) >= 3:
        pygame.draw.polygon(canvas, (*sh_col, max(0, body_alpha - 35)), sh_pts)


def _paint_stroke_segment(
    canvas: pygame.Surface,
    x1: float, y1: float,
    x2: float, y2: float,
    width: int,
    body_col: tuple[int, int, int],
    hi_col:   tuple[int, int, int],
    sh_col:   tuple[int, int, int],
    body_alpha: int = 215,
    rng: "random.Random | None" = None,
) -> None:
    """
    Draw a tapered impasto brushstroke from (x1,y1) to (x2,y2).

    Used for splash arms radiating outward from a paint drop impact.
    Shading (highlight + shadow strips) gives the impasto raised-paint look.
    When rng is provided a sine-wave wobble adds organic hand-tremor character.
    """
    dx = x2 - x1
    dy = y2 - y1
    length = math.hypot(dx, dy)

    if length < 0.5:
        r = max(1, round(width * 0.3))
        cx_, cy_ = round(x1), round(y1)
        pygame.draw.circle(canvas, (*body_col, body_alpha), (cx_, cy_), r)
        if r > 2:
            pygame.draw.circle(canvas, (*hi_col, min(255, body_alpha + 30)),
                               (cx_ - max(1, r // 4), cy_ - max(1, r // 4)),
                               max(1, r // 3))
        return

    ux = dx / length
    uy = dy / length
    px_vec = -uy
    py_vec =  ux

    N = max(5, min(20, round(length / 2.5)))

    if rng is not None:
        wob_freq  = rng.uniform(1.0, 3.2)
        wob_phase = rng.uniform(0.0, 2 * math.pi)
        wob_amp   = width * rng.uniform(0.08, 0.28)
    else:
        wob_freq = wob_phase = wob_amp = 0.0

    left_body:  list[tuple[float, float]] = []
    right_body: list[tuple[float, float]] = []
    left_hi:    list[tuple[float, float]] = []
    right_hi:   list[tuple[float, float]] = []
    left_sh:    list[tuple[float, float]] = []
    right_sh:   list[tuple[float, float]] = []

    for i in range(N + 1):
        t = i / N
        # Flat taper for splash arms: wide at origin, thin at tip
        hw = width * max(0.05, (1.0 - t) ** 0.6) / 2

        wob = wob_amp * math.sin(wob_freq * t * math.pi * 2.0 + wob_phase)
        cx = x1 + t * dx + px_vec * wob
        cy = y1 + t * dy + py_vec * wob

        left_body.append( (cx + px_vec * hw,  cy + py_vec * hw))
        right_body.append((cx - px_vec * hw,  cy - py_vec * hw))

        hi_off = hw * 0.52
        hi_w   = max(0.5, hw * 0.36)
        left_hi.append( (cx + px_vec * (hi_off + hi_w), cy + py_vec * (hi_off + hi_w)))
        right_hi.append((cx + px_vec * (hi_off - hi_w), cy + py_vec * (hi_off - hi_w)))
        left_sh.append( (cx - px_vec * (hi_off - hi_w), cy - py_vec * (hi_off - hi_w)))
        right_sh.append((cx - px_vec * (hi_off + hi_w), cy - py_vec * (hi_off + hi_w)))

    body_pts = left_body + list(reversed(right_body))
    if len(body_pts) >= 3:
        pygame.draw.polygon(canvas, (*body_col, body_alpha), body_pts)

    hi_pts = left_hi + list(reversed(right_hi))
    if len(hi_pts) >= 3:
        pygame.draw.polygon(canvas, (*hi_col, min(255, body_alpha + 35)), hi_pts)

    sh_pts = left_sh + list(reversed(right_sh))
    if len(sh_pts) >= 3:
        pygame.draw.polygon(canvas, (*sh_col, max(0, body_alpha - 35)), sh_pts)


def _paint_accent_ornaments(
    canvas: pygame.Surface,
    x: float, y: float,
    vx: float, vy: float,
    rng: random.Random,
    n: int = 2,
) -> None:
    """Paint n Klimt vocabulary ornaments near (x, y) onto the canvas."""
    speed = math.hypot(vx, vy) + 0.001
    perp_x = -vy / speed
    perp_y =  vx / speed

    for _ in range(n):
        kind = rng.choice(_KINDS)
        lo, hi = _KIND_SIZES[kind]
        size = rng.randint(lo, hi)
        color_idx = rng.choice(_KIND_COLORS[kind])

        offset_perp  = rng.uniform(-13, 13)
        offset_along = rng.uniform(-7, 7)
        ox = x + perp_x * offset_perp + (vx / speed) * offset_along
        oy = y + perp_y * offset_perp + (vy / speed) * offset_along

        alpha = rng.randint(155, 210)
        orn = _get_ornament(kind, size, color_idx, alpha)
        canvas.blit(orn, (round(ox - orn.get_width() // 2),
                          round(oy - orn.get_height() // 2)))


# ── Live drop surface cache ────────────────────────────────────────────────────
# Drops are drawn per-frame on the game surface (not the permanent canvas).
# We cache the teardrop surface per (size, elongation_step, color_idx) to avoid
# allocating a new surface every frame for every drop.
#
# Elongation is bucketed into 6 steps so the cache stays small.

_DROP_CACHE: dict[tuple, pygame.Surface] = {}
_ELONG_STEPS = 6


def _drop_surface(
    size: int,
    elong_step: int,                          # 0..5
    body_col: tuple[int, int, int],
    hi_col:   tuple[int, int, int],
    alpha: int,
) -> pygame.Surface:
    """
    Bake a teardrop surface: round belly at the bottom, tapered tail at the top.

    The teardrop is centred so its round belly sits at (surf_w//2, tail_h + size).
    Callers blit it so the belly centre aligns with the drop's screen position.
    """
    key = (size, elong_step, body_col, hi_col, alpha)
    if key in _DROP_CACHE:
        return _DROP_CACHE[key]

    elongation = 1.0 + elong_step * 0.35     # 1.0 … 2.75
    tail_h = max(3, round(size * elongation))
    surf_w = size * 2 + 4
    surf_h = tail_h + size * 2 + 4

    surf = pygame.Surface((surf_w, surf_h), pygame.SRCALPHA)
    cx = surf_w // 2
    belly_cy = surf_h - size - 2            # belly centre y (round bottom)

    # ── Round belly ────────────────────────────────────────────────────────────
    pygame.draw.circle(surf, (*body_col, alpha), (cx, belly_cy), size)
    # Highlight: small brighter spot upper-left of belly
    h_r = max(1, size // 3)
    pygame.draw.circle(surf, (*hi_col, min(255, alpha + 40)),
                       (cx - max(1, size // 4), belly_cy - max(1, size // 4)), h_r)

    # ── Tapered tail pointing upward ───────────────────────────────────────────
    # Polygon: two base corners at the shoulder of the belly, tip at top.
    shoulder_y = belly_cy - size + 2         # where tail meets belly
    tip_y      = belly_cy - size - tail_h   # pointed top
    half_base  = max(2, size - 1)
    tail_pts = [
        (cx - half_base, shoulder_y),
        (cx + half_base, shoulder_y),
        (cx,             tip_y),
    ]
    pygame.draw.polygon(surf, (*body_col, max(0, alpha - 25)), tail_pts)

    # Thin highlight line down the centre of the tail
    mid_alpha = min(255, alpha + 20)
    tail_mid = max(1, int((tail_h + 2) * 0.5))
    pygame.draw.line(
        surf, (*hi_col, mid_alpha),
        (cx, tip_y + 2),
        (cx, shoulder_y - 1),
        max(1, size // 5),
    )

    _DROP_CACHE[key] = surf
    return surf


# ── PaintDrop ─────────────────────────────────────────────────────────────────

@dataclass
class PaintDrop:
    """A single live paint drop falling toward its splash altitude."""
    x:         float
    y:         float          # current screen y (increases downward)
    target_y:  float          # splash altitude; drop commits to canvas when y ≥ this
    vx:        float          # horizontal drift (px / s)
    vy:        float          # fall speed (px / s, positive = downward)
    body_col:  tuple[int, int, int]
    hi_col:    tuple[int, int, int]
    sh_col:    tuple[int, int, int]
    size:      int            # belly radius (px)



# ── Liquid orb — surface-wave physics ────────────────────────────────────────────
#
# Lily's body is a single deformable liquid orb: a circle whose radius varies
# continuously around its perimeter.  N_BLOB radial control points are each
# governed by a damped spring that pulls them back to the rest radius.
# Adjacent points couple via a surface-tension term (discrete Laplacian) so
# disturbances propagate as waves rather than dying locally — the blob sloshes.
#
# When Lily accelerates the inertia term projects the acceleration onto each
# point's outward direction, bulging the surface opposite to the motion and
# creating a trailing squish that recovers as she continues.
#
# A slow breathing wave keeps the orb alive at idle so it never looks frozen.

N_BLOB      = 28          # control points — more = smoother silhouette
BLOB_REST_R = 18          # resting radius (px)
BLOB_MIN_R  = 7           # floor — prevents inversion on extreme squish
BLOB_MAX_R  = 30          # ceiling — caps explosive deformation
_LIQ_SURF_R = 40          # head-surface half-size; must exceed BLOB_MAX_R + shadow

# ── Rubber-ball squash / stretch constants ────────────────────────────────────
# The spring drives squash toward a STATE-DEPENDENT target each frame:
#   ground  — slightly wide/short (gravity pressing the ball into the surface)
#   falling — narrow/tall (elongated by air resistance and speed blur)
#   rising  — neutral (impact kick overshoots, spring brings back)
#
# Event kicks (landing, takeoff) throw the current value to an extreme; the
# spring then bounces it back to the current state target with natural overshoot.
SQUASH_SPRING_K  = 22.0    # spring stiffness
SQUASH_DAMPING   = 5.5     # lower = more bouncy overshoot
SQUASH_SCALE_MIN = 0.45    # floor on any axis (prevents inversion)
SQUASH_SCALE_MAX = 1.80    # ceiling on any axis

# Continuous state targets — what the spring rests at when nothing exciting happens.
SQUASH_GROUND_X  =  1.14   # slightly wide when resting on the ground
SQUASH_GROUND_Y  =  0.86   # correspondingly short (gravity weight)
SQUASH_FALL_X    =  0.80   # narrow while falling (speed elongation)
SQUASH_FALL_Y    =  1.28   # tall while falling

# Event kicks — instantaneous deformation on state transitions.
# Values <1 = compressed on that axis; >1 = stretched.
SQUASH_LAND_X    =  1.65   # wide horizontal slam on landing
SQUASH_LAND_Y    =  0.52   # vertical compression on landing
SQUASH_JUMP_X    =  0.78   # narrow on takeoff
SQUASH_JUMP_Y    =  1.32   # tall on takeoff

# Minimum vy (px/s downward) before the ball switches to its "falling" shape.
# Below this threshold (ascending or at peak) the spring targets neutral (1, 1).
SQUASH_FALL_THRESHOLD = 60.0


def _make_liquid() -> tuple[list[float], list[float]]:
    """Return (radii, vr) initialised to a perfect circle at rest."""
    return ([float(BLOB_REST_R)] * N_BLOB, [0.0] * N_BLOB)


def _step_liquid(
    radii:  list[float],
    vr:     list[float],
    dt:     float,
    ax:     float,
    ay:     float,
    t:      float,
) -> None:
    """
    Advance the liquid surface by one physics step.

    Forces on each radial control point i (angle = 2pi*i/N):
      Spring  — pulls radius back toward rest + slow breathing offset.
      Tension — discrete Laplacian couples neighbours so disturbances travel
               as surface waves that slosh around the blob.
      Damping — bleeds energy so the blob settles rather than ringing forever.
      Inertia — projects player acceleration outward so the blob bulges
               opposite to sudden motion changes.
    """
    N          = N_BLOB
    spring_k   = 48.0
    tension_k  = 22.0
    damping    = 5.8
    inertia_sc = 0.30
    breath_amp = 1.2

    forces = [0.0] * N
    for i in range(N):
        angle  = 2.0 * math.pi * i / N
        r      = radii[i]
        target = BLOB_REST_R + breath_amp * math.sin(t * 1.0 + angle * 2.0)
        forces[i] += -spring_k * (r - target)
        forces[i] += -damping * vr[i]
        r_prev = radii[(i - 1) % N]
        r_next = radii[(i + 1) % N]
        forces[i] += tension_k * (r_prev + r_next - 2.0 * r) * 0.5
        forces[i] += -inertia_sc * (ax * math.cos(angle) + ay * math.sin(angle))

    for i in range(N):
        vr[i]    += forces[i] * dt
        radii[i] += vr[i] * dt
        radii[i]  = max(BLOB_MIN_R, min(BLOB_MAX_R, radii[i]))


def _draw_liquid(
    surface:      "pygame.Surface",
    radii:        list[float],
    cx:           int,
    cy:           int,
    phase:        float,
    squash_x:     float = 1.0,
    squash_y:     float = 1.0,
    facing_right: bool  = True,
) -> None:
    """
    Draw the liquid orb centred at (cx, cy).

    squash_x / squash_y scale the rendered surface so the orb deforms as a
    rubber ball on landing (wide/short) and takeoff (narrow/tall).
    facing_right flips the specular highlight so it tracks which way Lily faces.

    Layers (back to front):
      shadow     — offset polygon, dark indigo, soft alpha.
      body       — full polygon in PURPLE_2.
      inner glow — scaled + shifted polygon in lighter purple.
      rim        — thin outline in deep indigo.
      specular   — small bright circle (glossy reflection spot, side-biased).
      crown      — eight gold Klimt dots on the deformed surface rim.
    """
    import pygame as _pg
    N = N_BLOB
    R = _LIQ_SURF_R

    pts: list[tuple[float, float]] = []
    for i in range(N):
        angle = 2.0 * math.pi * i / N
        pts.append((R + radii[i] * math.cos(angle), R + radii[i] * math.sin(angle)))

    head = _pg.Surface((R * 2, R * 2), _pg.SRCALPHA)

    # Shadow
    _pg.draw.polygon(head, (*INDIGO,   85), [(x + 2, y + 3) for x, y in pts])
    # Body
    _pg.draw.polygon(head, (*PURPLE_2, 220), pts)
    # Inner glow
    glow_pts = [(R + (x - R) * 0.54 - 3, R + (y - R) * 0.50 - 5) for x, y in pts]
    _pg.draw.polygon(head, (*PURPLE_3, 95), glow_pts)
    # Rim outline
    _pg.draw.polygon(head, (*INDIGO,   175), pts, 2)

    # Specular — offset toward whichever side Lily is facing so the glint
    # appears to track a light source on that side.
    spec_r  = max(2, round(BLOB_REST_R * 0.24))
    spec_ox = -int(BLOB_REST_R * 0.30)   # default: upper-left (facing right)
    if not facing_right:
        spec_ox = -spec_ox               # mirror to upper-right when facing left
    spec_x = R + spec_ox
    spec_y = round(R - BLOB_REST_R * 0.38)
    _pg.draw.circle(head, (*GOLD_3, 185), (spec_x,     spec_y    ), spec_r)
    _pg.draw.circle(head, (*IVORY,  210), (spec_x - 1, spec_y - 1), max(1, spec_r // 2))

    # Gold Klimt crown dots sitting on the deformed surface
    crown_n = 8
    for k in range(crown_n):
        angle  = phase * 0.15 + 2.0 * math.pi * k / crown_n
        a_norm = angle % (2.0 * math.pi)
        frac   = a_norm / (2.0 * math.pi) * N
        i0     = int(frac) % N
        i1     = (i0 + 1) % N
        t_i    = frac - int(frac)
        r_dot  = radii[i0] * (1.0 - t_i) + radii[i1] * t_i
        dot_x  = round(R + r_dot * math.cos(angle))
        dot_y  = round(R + r_dot * math.sin(angle))
        col    = GOLD_1 if k % 2 == 0 else GOLD_3
        alpha  = 225 if math.sin(angle) < 0 else 145
        _pg.draw.circle(head, (*col, alpha), (dot_x, dot_y), 3 if k % 3 == 0 else 2)

    # ── Apply squash/stretch by scaling the baked head surface ────────────────
    # Scale the head surface and bottom-anchor the result so the ball sits on
    # the ground rather than floating.  When squash = 1.0 the dimensions are
    # unchanged and the blit lands at the same position as the unscaled version.
    new_w = max(4, round(R * 2 * squash_x))
    new_h = max(4, round(R * 2 * squash_y))
    if new_w != R * 2 or new_h != R * 2:
        head = _pg.transform.smoothscale(head, (new_w, new_h))
    # Bottom of the orb sits at cy + R regardless of vertical scale.
    blit_x = cx - new_w // 2
    blit_y = cy + R - new_h
    surface.blit(head, (blit_x, blit_y))


# ── KlimtGoldLeafFlow ─────────────────────────────────────────────────────────

class KlimtGoldLeafFlow:
    """
    KLIMT_GOLD_LEAF_FLOW — RoomStyle for klimt_dining.

    Replaces Lily's sprite with an animated paint-head.  Colour drops fall
    slowly from the top of the screen toward Lily's position, drifting as they
    descend.  Each drop splashes permanently onto the canvas on impact, leaving
    a radial impasto burst of pigment and Klimt ornaments.

    Drop lifecycle
    ──────────────
      Spawn  — at y=0 above Lily's horizontal centre, with small x jitter.
      Fall   — vy 75–150 px/s; gentle horizontal drift; teardrop silhouette.
      Splash — when y reaches target_y: paint radial arms + blob + ornaments
               permanently onto the SRCALPHA canvas.  Drop removed.

    Visual anatomy of a splash
    ──────────────────────────
      Arms    — 6–10 short tapered strokes radiating outward (flattened
                vertically so they read as surface splatter, not aerial burst).
      Blob    — central filled circle with highlight in drop's colour.
      Halo    — faint translucent ring in a complementary palette colour.
      Ornaments — 2–3 Klimt vocabulary marks (circles, arcs, flecks).
    """

    def __init__(self) -> None:
        # Persistent splash canvas — None until first splash; cleared on room change.
        self._canvas:  pygame.Surface | None = None

        self._drops:        list[PaintDrop] = []
        self._drop_timer:   float = 0.0      # accumulates toward DROP_SPAWN_INTERVAL

        self._game_time:    float = 0.0
        self._phase:        float = 0.0
        self._last_px:      float = 0.0
        self._last_py:      float = 0.0
        self._speed:        float = 0.0
        self._rng:          random.Random = random.Random(42)
        self._color_idx:    int   = 0        # cycles through _STROKE_SEQUENCE

        # Trail smear state
        self._spawn_timer:    float = 0.0
        self._idle_timer:     float = 0.0
        self._last_stroke_x:  float | None = None
        self._last_stroke_y:  float | None = None
        self._stroke_count:   int   = 0

        # Liquid orb physics state
        self._radii, self._vr = _make_liquid()
        self._liq_t:    float = 0.0     # monotonic time for breathing wave phase
        self._prev_vx:  float = 0.0     # player vx last frame (for acceleration)
        self._prev_vy:  float = 0.0     # player vy last frame

        # Rubber-ball squash/stretch state (one spring per axis)
        self._squash_x:   float = SQUASH_GROUND_X  # start in grounded shape
        self._squash_y:   float = SQUASH_GROUND_Y
        self._squash_vx:  float = 0.0              # spring velocity on x-scale
        self._squash_vy:  float = 0.0              # spring velocity on y-scale
        self._facing_right: bool = True             # flipped based on movement direction
        # on_ground flickers every other frame due to integer rect precision; we
        # count consecutive grounded frames so triggers ignore the single-frame
        # false-negative that occurs on every standing frame.
        self._grounded_frames: int = 2             # start as if solidly grounded

    # ── RoomStyle protocol ────────────────────────────────────────────────────

    def update(
        self,
        dt: float,
        player: "PlayerEntity",
        state: "GameState",
        layout=None,
    ) -> None:
        self._game_time += dt
        self._phase     += dt * 2.8
        self._liq_t     += dt

        px = player.body.px + PLAYER_W // 2
        py = player.body.py + PLAYER_H // 2
        vx = player.body.vx
        vy = player.body.vy

        dx = px - self._last_px
        dy = py - self._last_py
        frame_speed     = math.hypot(dx, dy) / max(dt, 0.001)
        self._speed     = self._speed * 0.75 + frame_speed * 0.25
        self._last_px   = px
        self._last_py   = py

        # Player acceleration this frame (capped to avoid explosive kicks on
        # teleport / room spawn where vx jumps discontinuously).
        prev_vy       = self._prev_vy   # last frame's vy — used by squash triggers below
        ax = min(1800.0, max(-1800.0, (vx - self._prev_vx) / max(dt, 0.001)))
        ay = min(1800.0, max(-1800.0, (vy - prev_vy)       / max(dt, 0.001)))
        self._prev_vx = vx
        self._prev_vy = vy

        _step_liquid(self._radii, self._vr, dt, ax, ay, self._liq_t)

        # ── Trail smears ───────────────────────────────────────────────────────
        moving = frame_speed > 1.5
        if moving:
            self._spawn_timer += dt
            while self._spawn_timer >= SAMPLE_INTERVAL:
                self._spawn_timer -= SAMPLE_INTERVAL
                self._deposit_smear(px, py, vx, vy)
        else:
            self._idle_timer += dt
            if self._idle_timer >= IDLE_INTERVAL:
                self._idle_timer -= IDLE_INTERVAL
                self._deposit_idle(px, py)

        # on_ground read once; used by both landing burst and squash triggers below.
        grounded = getattr(player.body, "on_ground", True)

        # ── Rubber-ball squash/stretch ────────────────────────────────────────
        # on_ground flickers every other frame (integer rect precision): after
        # landing, vy=0, gravity adds ~28 px/s, new_py rounds to same integer
        # so rects only touch → collision missed → on_ground=False for one frame.
        # Using on_ground transitions as triggers therefore fires landing AND
        # takeoff events on alternate frames while the player stands still.
        #
        # Fix: use a consecutive-frames counter for grounded state, and detect
        # events via vy rather than on_ground transitions:
        #   Takeoff = vy crossed below -200 (JUMP_VELOCITY = -625; flicker vy ≈ +28)
        #   Landing = prev_vy was falling fast (>100) and now vy ≈ 0 (collision zeroed it)
        if grounded:
            self._grounded_frames = min(self._grounded_frames + 1, 10)
        else:
            self._grounded_frames = max(self._grounded_frames - 1, 0)

        # "Solidly grounded" = at least 2 consecutive grounded frames.
        # This ignores the single false-negative flicker frame.
        solid_ground = self._grounded_frames >= 2

        # State-based spring target — what the ball looks like in steady state.
        if solid_ground:
            target_sx, target_sy = SQUASH_GROUND_X, SQUASH_GROUND_Y
        elif vy > SQUASH_FALL_THRESHOLD:
            target_sx, target_sy = SQUASH_FALL_X, SQUASH_FALL_Y
        else:
            target_sx, target_sy = 1.0, 1.0

        # Event kicks via vy — immune to on_ground flicker.
        # prev_vy was captured before self._prev_vy was updated earlier this frame.
        jumped  = (vy < -200.0 and prev_vy >= -200.0)          # crossed jump threshold
        landed  = (prev_vy > 100.0 and vy < 50.0 and grounded) # was falling, now stopped

        if landed:
            self._squash_x  = SQUASH_LAND_X
            self._squash_y  = SQUASH_LAND_Y
            self._squash_vx = 0.0
            self._squash_vy = 0.0
            # Paint landing burst — same event, same gate, no flickering
            self._spawn_landing_burst(px, py)
            self._deposit_landing_bloom(px, py, vx, vy)
        elif jumped:
            self._squash_x  = SQUASH_JUMP_X
            self._squash_y  = SQUASH_JUMP_Y
            self._squash_vx = 0.0
            self._squash_vy = 0.0

        # Damped spring: F = -k*(x - target) - damping*v
        self._squash_vx += (-SQUASH_SPRING_K * (self._squash_x - target_sx)
                            - SQUASH_DAMPING  * self._squash_vx) * dt
        self._squash_vy += (-SQUASH_SPRING_K * (self._squash_y - target_sy)
                            - SQUASH_DAMPING  * self._squash_vy) * dt
        self._squash_x = max(SQUASH_SCALE_MIN,
                             min(SQUASH_SCALE_MAX, self._squash_x + self._squash_vx * dt))
        self._squash_y = max(SQUASH_SCALE_MIN,
                             min(SQUASH_SCALE_MAX, self._squash_y + self._squash_vy * dt))

        # Update facing direction when moving with enough horizontal speed.
        # Dead zone (|vx| > 5) avoids flipping on tiny physics drift at rest.
        if abs(vx) > 5.0:
            self._facing_right = vx > 0

        # Regular drop spawning (capped to DROP_MAX live drops at once)
        self._drop_timer += dt
        while self._drop_timer >= DROP_SPAWN_INTERVAL:
            self._drop_timer -= DROP_SPAWN_INTERVAL
            if len(self._drops) < DROP_MAX:
                self._spawn_drop(px, py)

        # Simulate all live drops; splash those that have reached target altitude
        canvas   = self._get_canvas()
        surviving: list[PaintDrop] = []
        for drop in self._drops:
            drop.y += drop.vy * dt
            drop.x += drop.vx * dt
            if drop.y >= drop.target_y:
                self._splash(canvas, drop)
            else:
                surviving.append(drop)
        self._drops = surviving

    def on_room_change(self) -> None:
        """Discard accumulated splashes and all live drops on room transition."""
        self._canvas        = None
        self._drops         = []
        self._drop_timer    = 0.0
        self._speed         = 0.0
        self._color_idx     = 0
        self._spawn_timer   = 0.0
        self._idle_timer    = 0.0
        self._last_stroke_x = None
        self._last_stroke_y = None
        self._stroke_count  = 0
        self._prev_vx       = 0.0
        self._prev_vy       = 0.0
        # Reset blobs to home positions so they don't carry mid-air velocity
        # across the transition.
        self._radii, self._vr = _make_liquid()
        # Reset squash spring to neutral — no bounce artefacts on room entry.
        self._squash_x      = SQUASH_GROUND_X   # start in grounded shape
        self._squash_y      = SQUASH_GROUND_Y
        self._squash_vx     = 0.0
        self._squash_vy     = 0.0
        self._grounded_frames = 2               # start solidly grounded

    def draw_trail(self, surface: pygame.Surface) -> None:
        """
        Draw the accumulated splash canvas then all live drops on top.

        Canvas blit is one call.  Each live drop is a small pre-baked surface
        blit — typically 4–15 drops visible at once.
        """
        if self._canvas is not None:
            surface.blit(self._canvas, (0, 0))

        for drop in self._drops:
            self._draw_drop(surface, drop)

    def draw_player(
        self,
        surface: pygame.Surface,
        player: "PlayerEntity",
        tick: int,
    ) -> None:
        cx = round(player.body.px) + PLAYER_W // 2
        cy = round(player.body.py) + PLAYER_H // 2
        _draw_liquid(
            surface, self._radii, cx, cy, self._phase,
            squash_x=self._squash_x,
            squash_y=self._squash_y,
            facing_right=self._facing_right,
        )

    # ── Internal helpers ──────────────────────────────────────────────────────

    def _get_canvas(self) -> pygame.Surface:
        """Return the persistent splash canvas, creating it on first call."""
        if self._canvas is None:
            self._canvas = pygame.Surface((_CANVAS_W, _CANVAS_H), pygame.SRCALPHA)
        return self._canvas

    def _next_colors(self) -> tuple:
        """Return (body, highlight, shadow) and advance the colour cycle."""
        triple = _STROKE_SEQUENCE[self._color_idx % len(_STROKE_SEQUENCE)]
        self._color_idx += 1
        return triple

    # ── Trail smear helpers ───────────────────────────────────────────────────

    def _smear_width(self, speed: float) -> int:
        """Stroke width scales with speed; slow = thin, fast = thick."""
        norm  = min(1.0, speed / 220.0)
        width = MIN_STROKE_W + (MAX_STROKE_W - MIN_STROKE_W) * norm
        width += self._rng.uniform(-1.5, 1.5)
        return max(MIN_STROKE_W, round(width))

    def _deposit_smear(self, x: float, y: float, vx: float, vy: float) -> None:
        """
        Paint one tapered brushstroke onto the persistent canvas.

        Strokes connect to the previous sample so they form continuous ribbon
        lines as Lily moves.  Wobble is kept gentle so each mark reads as an
        intentional, lovingly placed brushstroke.
        """
        canvas = self._get_canvas()
        rng    = self._rng
        speed  = math.hypot(vx, vy)
        width  = self._smear_width(speed)
        body_col, hi_col, sh_col = _STROKE_SEQUENCE[self._stroke_count % len(_STROKE_SEQUENCE)]

        x1 = self._last_stroke_x if self._last_stroke_x is not None else x
        y1 = self._last_stroke_y if self._last_stroke_y is not None else y

        _paint_smear(canvas, x1, y1, x, y, width,
                     body_col, hi_col, sh_col, rng=rng)

        # 1–2 small Klimt ornaments near the stroke tip
        _paint_accent_ornaments(
            canvas, x, y, vx if abs(vx) > 0.5 else 1.0, vy, rng, n=rng.randint(1, 2)
        )

        self._last_stroke_x = x
        self._last_stroke_y = y
        self._stroke_count += 1

    def _deposit_idle(self, x: float, y: float) -> None:
        """Small ornament deposited while standing still — the canvas breathes."""
        canvas    = self._get_canvas()
        rng       = self._rng
        kind      = rng.choice(("circle", "fleck", "arc"))
        lo, hi    = _KIND_SIZES[kind]
        size      = rng.randint(lo, max(lo, hi - 1))
        color_idx = rng.choice(_KIND_COLORS.get(kind, (0, 1, 2)))
        alpha     = rng.randint(140, 190)
        orn = _get_ornament(kind, size, color_idx, alpha)
        canvas.blit(
            orn,
            (round(x + rng.uniform(-10, 10) - orn.get_width() // 2),
             round(y + rng.uniform(-10, 10) - orn.get_height() // 2)),
        )

    def _deposit_landing_bloom(
        self, x: float, y: float, vx: float, vy: float
    ) -> None:
        """
        Radial burst of short smear strokes on landing — impasto splatter.

        Each arm is a short tapered stroke radiating outward, using the same
        gentle-wobble smear function so blooms match the trail character.
        """
        canvas = self._get_canvas()
        rng    = self._rng
        n      = rng.randint(5, 9)
        for _ in range(n):
            angle  = rng.uniform(0, 2 * math.pi)
            radius = rng.uniform(4, 18)
            bx     = x + radius * math.cos(angle)
            by     = y + radius * math.sin(angle)
            body_col, hi_col, sh_col = _STROKE_SEQUENCE[self._stroke_count % len(_STROKE_SEQUENCE)]
            width  = rng.randint(MIN_STROKE_W, MAX_STROKE_W - 3)
            _paint_smear(canvas, x, y, bx, by, width,
                         body_col, hi_col, sh_col,
                         body_alpha=rng.randint(180, 225), rng=rng)
            self._stroke_count += 1

    def _spawn_drop(self, lily_x: float, lily_y: float) -> None:
        """Spawn one drop at the top of the screen aimed at Lily's altitude."""
        rng = self._rng
        body_col, hi_col, sh_col = self._next_colors()
        self._drops.append(PaintDrop(
            x        = lily_x + rng.uniform(-DROP_X_JITTER, DROP_X_JITTER),
            y        = 0.0,
            target_y = lily_y + SPLASH_Y_OFFSET + rng.uniform(-4, 8),
            vx       = rng.uniform(-DROP_DRIFT_MAX, DROP_DRIFT_MAX),
            vy       = rng.uniform(DROP_FALL_SPEED_MIN, DROP_FALL_SPEED_MAX),
            body_col = body_col,
            hi_col   = hi_col,
            sh_col   = sh_col,
            size     = rng.randint(DROP_SIZE_MIN, DROP_SIZE_MAX),
        ))

    def _spawn_landing_burst(self, lily_x: float, lily_y: float) -> None:
        """
        On landing: spawn 3–5 low-altitude drops that splash almost immediately.

        These fill in the dramatic landing moment without waiting for the
        regular spawn timer.
        """
        rng = self._rng
        n = rng.randint(3, 5)
        for _ in range(n):
            if len(self._drops) >= DROP_MAX:
                break
            body_col, hi_col, sh_col = self._next_colors()
            # Start just above Lily so they reach her quickly
            start_y  = max(0.0, lily_y - rng.uniform(60, 180))
            self._drops.append(PaintDrop(
                x        = lily_x + rng.uniform(-DROP_X_JITTER * 1.4, DROP_X_JITTER * 1.4),
                y        = start_y,
                target_y = lily_y + rng.uniform(0, 12),
                vx       = rng.uniform(-DROP_DRIFT_MAX * 0.5, DROP_DRIFT_MAX * 0.5),
                vy       = rng.uniform(180.0, 280.0),   # faster — they're close
                body_col = body_col,
                hi_col   = hi_col,
                sh_col   = sh_col,
                size     = rng.randint(DROP_SIZE_MIN + 1, DROP_SIZE_MAX + 2),
            ))

    def _draw_drop(self, surface: pygame.Surface, drop: PaintDrop) -> None:
        """
        Blit a teardrop silhouette for a live falling drop.

        Elongation increases with fall speed so fast drops look stretched.
        The belly (round part) is anchored at the drop's screen position.
        """
        elong_step = min(
            _ELONG_STEPS - 1,
            round((drop.vy - DROP_FALL_SPEED_MIN)
                  / max(1, DROP_FALL_SPEED_MAX - DROP_FALL_SPEED_MIN)
                  * (_ELONG_STEPS - 1))
        )
        alpha = 195
        drop_surf = _drop_surface(drop.size, elong_step, drop.body_col, drop.hi_col, alpha)

        # Belly centre = drop.x, drop.y
        belly_cy_in_surf = drop_surf.get_height() - drop.size - 2
        blit_x = round(drop.x) - drop_surf.get_width() // 2
        blit_y = round(drop.y) - belly_cy_in_surf
        surface.blit(drop_surf, (blit_x, blit_y))

    def _splash(self, canvas: pygame.Surface, drop: PaintDrop) -> None:
        """
        Commit a drop impact permanently to the canvas.

        Splash anatomy:
          • 6–10 short tapered arms radiating outward, flattened vertically
            (paint hitting a flat surface splashes sideways more than up).
          • Central blob with highlight.
          • Faint halo ring in a contrasting palette colour.
          • 2–3 Klimt accent ornaments near the centre.
        """
        rng  = self._rng
        x    = drop.x
        y    = drop.target_y
        size = drop.size

        # ── Splash arms ───────────────────────────────────────────────────────
        n_arms = rng.randint(6, 10)
        for _ in range(n_arms):
            angle  = rng.uniform(0.0, 2.0 * math.pi)
            # Flatten angle so arms spread mostly sideways (vertical squash 0.35)
            radius = rng.uniform(size * 1.5, size * 4.5)
            arm_x  = x + radius * math.cos(angle)
            arm_y  = y + radius * math.sin(angle) * 0.35   # flatten vertically
            width  = rng.randint(2, max(3, size - 1))
            _paint_stroke_segment(
                canvas, x, y, arm_x, arm_y, width,
                drop.body_col, drop.hi_col, drop.sh_col,
                body_alpha=rng.randint(165, 220),
                rng=rng,
            )

        # ── Central blob ──────────────────────────────────────────────────────
        blob_r = size + rng.randint(1, 3)
        pygame.draw.circle(canvas, (*drop.body_col, 210), (round(x), round(y)), blob_r)
        # Highlight spot (slightly off-centre)
        h_off = max(1, blob_r // 4)
        pygame.draw.circle(
            canvas, (*drop.hi_col, 240),
            (round(x) - h_off, round(y) - h_off),
            max(1, blob_r // 3),
        )

        # ── Faint halo in contrasting colour ──────────────────────────────────
        halo_col = _STROKE_SEQUENCE[(self._color_idx + 3) % len(_STROKE_SEQUENCE)][0]
        pygame.draw.circle(
            canvas, (*halo_col, 40),
            (round(x), round(y)),
            blob_r + rng.randint(3, 7),
        )

        # ── Klimt accent ornaments ─────────────────────────────────────────────
        _paint_accent_ornaments(canvas, x, y, 1.0, 0.0, rng, n=rng.randint(2, 3))
