"""
games/lilys_music_box/styles/escher.py
---------------------------------------
ESCHER_RELATIVITY_WALK visual effect.

When the escher_foyer tileset is active, Lily's sprite is replaced by an
ivory-white architectural mannequin rendered in Escher lithograph style:
  - Articulated limbs drawn as rotated polygon segments
  - Ink-outline joints as solid circles
  - Walk animation driven by a continuous phase counter
  - Ghost trail of up to MAX_GHOSTS past positions with 5 aging alpha stages
  - Trail length proportional to escher_fatigue (0→1) — longer as player tires
  - Hatching overlay on ghost stages 2–4 replicates lithograph plate texture

Performance contract:
  - Ghost SRCALPHA surfaces are pre-baked at spawn time (5 alpha variants each).
  - draw_trail() performs only blit() calls — no per-frame alpha math.
  - update() spawns at most one ghost per GHOST_SPAWN_RATE interval.
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

import pygame

from engine.physics import PLAYER_W, PLAYER_H
from engine.room_graph import TILE_W, TILE_H, ROOM_COLS, ROOM_ROWS

if TYPE_CHECKING:
    from engine.entities import PlayerEntity
    from engine.state import GameState

# ── Palette ───────────────────────────────────────────────────────────────────

IVORY      = (245, 240, 228)
IVORY_BACK = (210, 205, 193)   # slightly darker for back-facing limbs
INK        = (22, 18, 14)

# ── Trail constants ───────────────────────────────────────────────────────────

MAX_GHOSTS       = 14          # absolute cap on simultaneously visible ghosts
GHOST_SPAWN_RATE = 0.13        # seconds between ghost samples (when moving)
STAGE_DURATION   = 0.85        # seconds each ghost spends at one alpha stage
STAGE_ALPHAS     = [220, 168, 112, 64, 24]   # stages 0→4 (newest to oldest)
TRAIL_BASE       = 3           # minimum visible ghosts even when escher_fatigue=0
SINE_AMPLITUDE   = 2.2         # px — gentle levitation on oldest ghosts
SINE_FREQUENCY   = 0.45        # cycles per second

# ── Shadow / hatch constants ─────────────────────────────────────────────────

SHADOW_HATCH_INTERVAL  = 0.04   # seconds between new mark bursts
SHADOW_MARKS_PER_TICK  = 3      # marks cast per interval (density)
SHADOW_RAY_STEP        = 2      # px per march step
SHADOW_RAY_MAX_STEPS   = 400    # cap to avoid marching off-screen
HATCH_LEN_MIN          = 12     # px — shortest pen stroke
HATCH_LEN_MAX          = 52     # px — longest pen stroke
HATCH_ANGLE_JITTER     = 45.0   # degrees — max deviation from stroke axis
HATCH_POS_JITTER       = 9      # px — random offset from ray hit point
HATCH_ALPHA_MIN        = 110    # lowest per-stroke opacity
HATCH_ALPHA_MAX        = 210    # highest per-stroke opacity

# ── Pen-stroke colour palettes ────────────────────────────────────────────────
# Warm strokes originate from the top-right corner and travel toward bottom-left.
# Palette echoes the amber, ochre, and coral tones in the Escher tessellation.
_WARM: list[tuple[int, int, int]] = [
    (255, 185,  55),   # amber
    (255, 135,  65),   # coral-orange
    (240, 205,  80),   # warm yellow
    (220,  95,  40),   # burnt orange
    (255, 160,  90),   # peach
    (205, 145,  50),   # ochre
    (240, 115,  55),   # vermillion
    (255, 200, 100),   # pale gold
]
# Cool strokes originate from the bottom-left corner and travel toward top-right.
# Palette echoes the teals, indigos, and muted purples of the tessellation shadows.
_COOL: list[tuple[int, int, int]] = [
    ( 55,  90, 165),   # cobalt
    ( 38, 118, 135),   # deep teal
    ( 92,  68, 155),   # violet-grey
    ( 48,  78, 148),   # indigo
    ( 62, 135, 158),   # muted cyan
    ( 82,  58, 125),   # dusky purple
    ( 42, 102, 115),   # slate teal
    ( 70, 110, 175),   # periwinkle
]

# ── Light source positions ────────────────────────────────────────────────────
# Warm light sits at the top-right screen corner; its shadow rays travel
# toward bottom-left.  Cool light sits at bottom-left; rays travel top-right.
# Positions are in pixel space and fixed for the lifetime of the module.
_BW = ROOM_COLS * TILE_W
_BH = ROOM_ROWS * TILE_H
_LIGHT_WARM: tuple[float, float] = (float(_BW), 0.0)
_LIGHT_COOL: tuple[float, float] = (0.0,        float(_BH))

# ── Fatigue constants ─────────────────────────────────────────────────────────

FATIGUE_RATE      = 0.22       # escher_fatigue increase per second while moving
STILL_RESET_RATE  = 0.55       # escher_fatigue decrease per second while still
FATIGUE_MAX       = 1.0

# ── Animation constants ───────────────────────────────────────────────────────

ANIM_FPS         = 8.0         # mannequin walk-cycle frames per second
WALK_FRAMES      = 8           # distinct phase steps in one stride cycle
IDLE_BREATHE_AMP = 0.10        # subtle idle chest-bob amplitude (fraction of h)

# ── Limb swing amplitudes (degrees) ──────────────────────────────────────────

UPPER_LEG_AMP    = 32.0
LOWER_LEG_BEND   = 20.0        # maximum knee bend added on trailing leg
UPPER_ARM_AMP    = 22.0
LOWER_ARM_DANGLE = 14.0        # forearm always hangs slightly forward

# ── Proportions (fractions of PLAYER_W / PLAYER_H) ───────────────────────────

_W = PLAYER_W
_H = PLAYER_H

HEAD_RX      = round(_W * 0.200)    # head half-width
HEAD_RY      = round(_H * 0.090)    # head half-height
NECK_LEN     = round(_H * 0.060)
SHOULDER_Y   = round(_H * 0.240)    # y from top
SHOULDER_SPR = round(_W * 0.260)    # half-spread from center
TORSO_LEN    = round(_H * 0.280)
HIP_Y        = round(_H * 0.525)    # y from top
HIP_SPR      = round(_W * 0.155)    # half-spread from center

UPPER_LEG_LEN = round(_H * 0.255)
LOWER_LEG_LEN = round(_H * 0.235)
UPPER_ARM_LEN = round(_H * 0.225)
LOWER_ARM_LEN = round(_H * 0.200)

JOINT_R      = max(3, round(_W * 0.046))   # radius of joint circles
HEAD_CENTER_Y = round(_H * 0.090)          # y from top of sprite to head centre


# ── Low-level drawing helpers ─────────────────────────────────────────────────

def _rotated_endpoint(
    ox: float, oy: float, angle_deg: float, length: float
) -> tuple[float, float]:
    """Return the far endpoint of a limb segment rooted at (ox, oy)."""
    rad = math.radians(angle_deg)
    return ox + math.sin(rad) * length, oy + math.cos(rad) * length


def _limb(
    surf: pygame.Surface,
    ox: float,
    oy: float,
    angle_deg: float,
    length: float,
    width: int,
    fill: tuple[int, int, int],
    outline: tuple[int, int, int] = INK,
    outline_w: int = 2,
) -> tuple[float, float]:
    """
    Draw a rotated rectangle segment (limb) and return the far endpoint.

    The segment is approximated as a thin polygon perpendicular to the limb axis.
    Returns (far_x, far_y) so callers can chain segments.
    """
    rad  = math.radians(angle_deg)
    ex   = ox + math.sin(rad) * length
    ey   = oy + math.cos(rad) * length

    # Perpendicular unit vector for width
    perp_x = math.cos(rad) * (width / 2)
    perp_y = -math.sin(rad) * (width / 2)

    pts = [
        (ox + perp_x, oy + perp_y),
        (ox - perp_x, oy - perp_y),
        (ex - perp_x, ey - perp_y),
        (ex + perp_x, ey + perp_y),
    ]
    pygame.draw.polygon(surf, fill, pts)
    if outline_w > 0:
        pygame.draw.polygon(surf, outline, pts, outline_w)
    return ex, ey


def _ball(
    surf: pygame.Surface,
    cx: float,
    cy: float,
    r: int,
    fill: tuple[int, int, int] = IVORY,
    outline: tuple[int, int, int] = INK,
) -> None:
    pygame.draw.circle(surf, fill,  (round(cx), round(cy)), r)
    pygame.draw.circle(surf, outline, (round(cx), round(cy)), r, max(1, r // 3))


def _hatch_overlay(surf: pygame.Surface, spacing: int = 7, alpha: int = 60) -> None:
    """
    Draw diagonal hatch lines over the entire surface at the given alpha.
    Replicates the cross-hatch shading of a lithograph print.
    Lines run at 45° (top-left → bottom-right).
    """
    w, h = surf.get_size()
    hatch = pygame.Surface((w, h), pygame.SRCALPHA)
    ink_a = (*INK, alpha)
    for start in range(-(h), w, spacing):
        x0 = max(0, start)
        y0 = max(0, -start)
        x1 = min(w, start + h)
        y1 = min(h, h - start)
        if x0 < w and y0 < h:
            pygame.draw.line(hatch, ink_a, (x0, y0), (x1, y1))
    surf.blit(hatch, (0, 0))


# ── Mannequin draw ────────────────────────────────────────────────────────────

def _draw_mannequin(
    surf: pygame.Surface,
    w: int,
    h: int,
    walk_phase: float,
    facing_right: bool,
) -> None:
    """
    Draw a full articulated mannequin on `surf` (SRCALPHA, w×h).

    walk_phase is a continuous radian value; limb angles are derived from
    sin/cos of this phase to produce a smooth gait cycle.
    facing_right flips the horizontal layout of front/back limbs.
    """
    cx = w / 2
    swing = math.sin(walk_phase)
    cos_p = math.cos(walk_phase)

    # Sign convention: positive angle = limb leans right (screen-right)
    # Facing direction mirrors the left/right distinction.
    flip = 1.0 if facing_right else -1.0

    # Upper-leg angles (from vertical, +ve = forward for right leg)
    r_ul_a =  swing * UPPER_LEG_AMP * flip
    l_ul_a = -swing * UPPER_LEG_AMP * flip

    # Knee bend: trailing leg bends more (always positive to keep foot behind hip)
    r_ll_extra = max(0.0, math.cos(walk_phase + 0.4) * LOWER_LEG_BEND)
    l_ll_extra = max(0.0, math.cos(walk_phase + math.pi + 0.4) * LOWER_LEG_BEND)
    r_ll_a = r_ul_a + r_ll_extra
    l_ll_a = l_ul_a + l_ll_extra

    # Arms swing opposite to legs
    r_ua_a = -swing * UPPER_ARM_AMP * flip
    l_ua_a =  swing * UPPER_ARM_AMP * flip
    # Forearms dangle forward with slight counter-swing
    r_fa_a = r_ua_a - LOWER_ARM_DANGLE + math.sin(walk_phase + math.pi) * 8 * flip
    l_fa_a = l_ua_a - LOWER_ARM_DANGLE + math.sin(walk_phase) * 8 * flip

    # ── Joint anchor points ───────────────────────────────────────────────────
    head_cy = HEAD_CENTER_Y
    neck_b  = head_cy + HEAD_RY + NECK_LEN        # base of neck / top of torso
    r_shoulder = (cx + SHOULDER_SPR * flip, SHOULDER_Y)
    l_shoulder = (cx - SHOULDER_SPR * flip, SHOULDER_Y)
    r_hip = (cx + HIP_SPR * flip, HIP_Y)
    l_hip = (cx - HIP_SPR * flip, HIP_Y)

    limb_w = max(5, round(w * 0.13))   # limb stroke width

    # ── Draw order: back limbs → torso → front limbs ──────────────────────────

    # Back upper leg
    r_knee = _limb(surf, *r_hip, r_ul_a, UPPER_LEG_LEN, limb_w, IVORY_BACK)[:]
    # Back lower leg
    r_foot = _limb(surf, *r_knee, r_ll_a, LOWER_LEG_LEN, limb_w, IVORY_BACK)[:]

    # Back upper arm
    r_elbow = _limb(surf, *r_shoulder, r_ua_a, UPPER_ARM_LEN, limb_w, IVORY_BACK)[:]
    # Back forearm
    _limb(surf, *r_elbow, r_fa_a, LOWER_ARM_LEN, limb_w, IVORY_BACK)

    # Torso
    _limb(surf, cx, neck_b, 0, TORSO_LEN, round(w * 0.35), IVORY)

    # Neck
    _limb(surf, cx, head_cy + HEAD_RY, 0, NECK_LEN, max(4, round(w * 0.12)), IVORY)

    # Head
    pygame.draw.ellipse(surf, IVORY,
                        (round(cx - HEAD_RX), round(head_cy - HEAD_RY),
                         HEAD_RX * 2, HEAD_RY * 2))
    pygame.draw.ellipse(surf, INK,
                        (round(cx - HEAD_RX), round(head_cy - HEAD_RY),
                         HEAD_RX * 2, HEAD_RY * 2), 2)

    # Shoulder joints
    _ball(surf, *r_shoulder, JOINT_R)
    _ball(surf, *l_shoulder, JOINT_R)

    # Front upper leg
    l_knee = _limb(surf, *l_hip, l_ul_a, UPPER_LEG_LEN, limb_w, IVORY)[:]
    # Front lower leg
    _limb(surf, *l_knee, l_ll_a, LOWER_LEG_LEN, limb_w, IVORY)

    # Knee joints
    _ball(surf, r_knee[0], r_knee[1], JOINT_R, IVORY_BACK)
    _ball(surf, l_knee[0], l_knee[1], JOINT_R)

    # Front upper arm
    l_elbow = _limb(surf, *l_shoulder, l_ua_a, UPPER_ARM_LEN, limb_w, IVORY)[:]
    # Front forearm
    _limb(surf, *l_elbow, l_fa_a, LOWER_ARM_LEN, limb_w, IVORY)

    # Elbow joints
    _ball(surf, r_elbow[0], r_elbow[1], JOINT_R, IVORY_BACK)
    _ball(surf, l_elbow[0], l_elbow[1], JOINT_R)

    # Hip joints
    _ball(surf, *r_hip, JOINT_R, IVORY_BACK)
    _ball(surf, *l_hip, JOINT_R)


def _bake_ghost_stages(
    frame: pygame.Surface,
    hatch_from_stage: int = 2,
) -> list[pygame.Surface]:
    """
    Pre-bake 5 SRCALPHA copies of `frame` with scaled alpha channels.

    Stage 0 is newest (highest alpha), stage 4 is oldest (lowest + hatch).
    Uses surfarray for O(n) alpha scaling without per-pixel Python loops.
    Returns a list of 5 ready-to-blit surfaces.
    """
    stages: list[pygame.Surface] = []
    for i, alpha in enumerate(STAGE_ALPHAS):
        baked = frame.copy()
        pa = pygame.surfarray.pixels_alpha(baked)
        # Scale existing per-pixel alpha by the stage fraction
        pa[:] = (pa.astype(int) * alpha // 255).clip(0, 255)
        del pa   # release the lock before blitting
        if i >= hatch_from_stage:
            _hatch_overlay(baked, spacing=6 + i, alpha=45 + i * 8)
        stages.append(baked)
    return stages


# ── Ghost dataclass ───────────────────────────────────────────────────────────

@dataclass
class EscherTrailGhost:
    """One past-position snapshot of the mannequin, aging through 5 stages."""
    stage_surfs: list[pygame.Surface]   # pre-baked; len == 5
    x: float
    y: float
    stage: int = 0
    stage_timer: float = 0.0
    index: int = 0                      # used for staggered sine offset



# ── EscherVisualEffect ────────────────────────────────────────────────────────

class EscherVisualEffect:
    """
    ESCHER_RELATIVITY_WALK effect — RoomStyle implementation for escher_foyer.

    Replaces Lily's sprite with an articulated ivory mannequin and spawns
    ghost-trail copies that age through 5 opacity stages, with hatching on
    older stages to evoke lithograph plate texture.

    escher_fatigue (0→1) grows while Lily moves and resets while standing.
    Trail length scales with fatigue: longer trail as exhaustion increases.
    """

    def __init__(self) -> None:
        self._walk_phase: float = 0.0
        self._spawn_timer: float = 0.0
        self._game_time: float = 0.0
        self._ghost_index: int = 0
        self._ghosts: list[EscherTrailGhost] = []
        self._escher_fatigue: float = 0.0
        self._still_timer: float = 0.0
        self._last_px: float = 0.0
        self._facing_right: bool = True
        # Cached mannequin frames — keyed by (facing_right, phase_bucket)
        self._frame_cache: dict[tuple[bool, int], list[pygame.Surface]] = {}
        # ── Shadow / hatch system ─────────────────────────────────────────────
        # A single SRCALPHA canvas accumulates ink hatch marks permanently for
        # the lifetime of the room.  Marks are cast along the shadow ray from a
        # fixed light source (random top-edge point) through the mannequin's foot
        # onto the nearest solid surface below the ray.
        self._rng: random.Random = random.Random()
        # Light positions are module-level constants (_LIGHT_WARM / _LIGHT_COOL).
        self._shadow_canvas: pygame.Surface | None = None
        self._hatch_timer: float = 0.0
        self._solid_tiles: frozenset[tuple[int, int]] = frozenset()

    # ── RoomStyle protocol ────────────────────────────────────────────────────

    def update(
        self,
        dt: float,
        player: "PlayerEntity",
        state: "GameState",
        layout=None,
    ) -> None:
        # Cache solid tiles whenever the layout is available so the shadow
        # caster always has an up-to-date surface map.
        if layout is not None and layout.solid_tiles is not self._solid_tiles:
            self._solid_tiles = frozenset(layout.solid_tiles)

        self._game_time += dt
        px = player.body.px
        moving = abs(px - self._last_px) > 0.5
        self._last_px = px
        self._facing_right = player.facing_right

        # Advance walk phase when moving
        if moving:
            self._walk_phase += dt * ANIM_FPS * (2 * math.pi / WALK_FRAMES)
            self._still_timer = 0.0
            self._escher_fatigue = min(
                FATIGUE_MAX, self._escher_fatigue + dt * FATIGUE_RATE
            )
        else:
            self._still_timer += dt
            self._escher_fatigue = max(
                0.0, self._escher_fatigue - dt * STILL_RESET_RATE
            )

        # Age existing ghosts
        for ghost in self._ghosts:
            ghost.stage_timer += dt
            while ghost.stage_timer >= STAGE_DURATION and ghost.stage < len(STAGE_ALPHAS) - 1:
                ghost.stage_timer -= STAGE_DURATION
                ghost.stage += 1

        # Cull fully expired ghosts (lingered past final stage duration)
        self._ghosts = [
            g for g in self._ghosts
            if not (g.stage == len(STAGE_ALPHAS) - 1
                    and g.stage_timer >= STAGE_DURATION)
        ]

        # Spawn new ghost when moving, respecting trail-length cap
        max_ghosts = TRAIL_BASE + round(self._escher_fatigue * (MAX_GHOSTS - TRAIL_BASE))
        if moving and len(self._ghosts) < max_ghosts:
            self._spawn_timer += dt
            if self._spawn_timer >= GHOST_SPAWN_RATE:
                self._spawn_timer -= GHOST_SPAWN_RATE
                self._spawn_ghost(player)

        # ── Shadow hatch ──────────────────────────────────────────────────────
        # Marks are drawn directly onto the canvas and never erased — they
        # accumulate continuously, building up a dense coloured pen texture.
        if self._solid_tiles and self._shadow_canvas is not None:
            self._hatch_timer += dt
            if self._hatch_timer >= SHADOW_HATCH_INTERVAL:
                self._hatch_timer -= SHADOW_HATCH_INTERVAL
                for _ in range(SHADOW_MARKS_PER_TICK):
                    self._cast_shadow_hatch(player, _LIGHT_WARM, _WARM)
                    self._cast_shadow_hatch(player, _LIGHT_COOL, _COOL)

    def on_room_change(self) -> None:
        self._ghosts.clear()
        self._spawn_timer = 0.0
        self._escher_fatigue = 0.0
        self._still_timer = 0.0
        self._shadow_canvas = None
        self._hatch_timer   = 0.0
        self._solid_tiles   = frozenset()

    def draw_trail(self, surface: pygame.Surface) -> None:
        # Lazily allocate the shadow canvas to match the display surface size.
        if self._shadow_canvas is None:
            w, h = surface.get_size()
            self._shadow_canvas = pygame.Surface((w, h), pygame.SRCALPHA)

        # Shadow hatch marks are the lowest layer — drawn before ghosts.
        surface.blit(self._shadow_canvas, (0, 0))

        for ghost in self._ghosts:
            y_off = math.sin(self._game_time * 2 * math.pi * SINE_FREQUENCY
                             + ghost.index * 0.7) * SINE_AMPLITUDE
            surface.blit(
                ghost.stage_surfs[ghost.stage],
                (round(ghost.x), round(ghost.y + y_off)),
            )

    def draw_player(
        self,
        surface: pygame.Surface,
        player: "PlayerEntity",
        tick: int,
    ) -> None:
        # Vertical flip when inside an updraft zone: gravity appears inverted.
        # Horizontal flip tracks last direction of movement (set by _Session.update).
        flipped_v = player.body.in_updraft
        frame = self._get_frame(player.facing_right, self._walk_phase, flipped_v=flipped_v)
        surface.blit(frame, (round(player.body.px), round(player.body.py)))

    # ── Internal ──────────────────────────────────────────────────────────────

    def _cast_shadow_hatch(
        self,
        player: "PlayerEntity",
        light: tuple[float, float],
        palette: list[tuple[int, int, int]],
    ) -> None:
        """
        Cast a shadow ray from *light* through the mannequin's foot, find the
        first solid surface the ray enters, and draw one chaotic pen stroke
        directly onto the shadow canvas.

        light determines the base stroke direction — the ray vector from light
        to the player's foot is the axis every stroke centres on before jitter.
        Warm strokes originate from the top-right corner (travel BL).
        Cool strokes originate from the bottom-left corner (travel TR).

        Jitter up to ±HATCH_ANGLE_JITTER degrees rotates each stroke
        independently so the family reads as loose hand-drawn lines rather than
        a mechanical grid.  Marks accumulate without clearing.
        """
        if self._shadow_canvas is None:
            return

        fx = player.body.px + PLAYER_W * 0.5
        fy = player.body.py + PLAYER_H
        lx, ly = light
        dx = fx - lx
        dy = fy - ly
        dist = math.hypot(dx, dy)
        if dist < 1.0:
            return
        dx /= dist
        dy /= dist

        rx, ry = fx, fy
        prev_col = int(fx / TILE_W)
        prev_row = int(fy / TILE_H)
        for _ in range(SHADOW_RAY_MAX_STEPS):
            rx += dx * SHADOW_RAY_STEP
            ry += dy * SHADOW_RAY_STEP
            col = int(rx / TILE_W)
            row = int(ry / TILE_H)
            if not (0 <= col < ROOM_COLS and 0 <= row < ROOM_ROWS):
                return
            if (col, row) in self._solid_tiles:
                # Anchor point at the face boundary the ray crossed.
                if row > prev_row:
                    ax, ay = rx, float(row * TILE_H)
                elif row < prev_row:
                    ax, ay = rx, float((row + 1) * TILE_H)
                elif col > prev_col:
                    ax, ay = float(col * TILE_W), ry
                else:
                    ax, ay = float((col + 1) * TILE_W), ry

                # Rotate the base direction by a random amount within the jitter cone.
                jitter_rad = math.radians(
                    self._rng.uniform(-HATCH_ANGLE_JITTER, HATCH_ANGLE_JITTER)
                )
                cos_j = math.cos(jitter_rad)
                sin_j = math.sin(jitter_rad)
                mdx = dx * cos_j - dy * sin_j
                mdy = dx * sin_j + dy * cos_j

                length = self._rng.uniform(HATCH_LEN_MIN, HATCH_LEN_MAX)
                ax += self._rng.uniform(-HATCH_POS_JITTER, HATCH_POS_JITTER)
                ay += self._rng.uniform(-HATCH_POS_JITTER, HATCH_POS_JITTER)
                r, g, b = self._rng.choice(palette)
                alpha  = self._rng.randint(HATCH_ALPHA_MIN, HATCH_ALPHA_MAX)
                width  = self._rng.choice((1, 1, 2))

                pygame.draw.line(
                    self._shadow_canvas,
                    (r, g, b, alpha),
                    (round(ax), round(ay)),
                    (round(ax + mdx * length), round(ay + mdy * length)),
                    width,
                )
                return
            prev_col, prev_row = col, row

    def _get_frame(
        self,
        facing_right: bool,
        phase: float,
        flipped_v: bool = False,
    ) -> pygame.Surface:
        """
        Return a full-alpha mannequin surface for the live player sprite.

        Phase is bucketed to WALK_FRAMES discrete steps to keep the cache small.
        flipped_v=True produces a vertically mirrored frame for updraft zones.
        Also pre-bakes the 5 ghost alpha stages on first access so _spawn_ghost
        can look them up instantly without re-rendering.
        """
        bucket = round(phase / (2 * math.pi / WALK_FRAMES)) % WALK_FRAMES
        key_live   = (facing_right, bucket, flipped_v, "live")
        key_stages = (facing_right, bucket, flipped_v, "stages")
        if key_live not in self._frame_cache:
            surf = pygame.Surface((PLAYER_W, PLAYER_H), pygame.SRCALPHA)
            _draw_mannequin(surf, PLAYER_W, PLAYER_H,
                            bucket * (2 * math.pi / WALK_FRAMES), facing_right)
            if flipped_v:
                surf = pygame.transform.flip(surf, False, True)
            self._frame_cache[key_live]   = [surf]
            self._frame_cache[key_stages] = _bake_ghost_stages(surf)
        return self._frame_cache[key_live][0]

    def _spawn_ghost(self, player: "PlayerEntity") -> None:
        """
        Snapshot the current player frame, look up pre-baked stages, add ghost.

        flipped_v is captured at spawn time so ghosts baked while in an updraft
        zone remain upside-down as they age — the trail correctly records the
        orientation at each past position.
        """
        facing   = player.facing_right
        flipped_v = player.body.in_updraft
        phase    = self._walk_phase
        bucket   = round(phase / (2 * math.pi / WALK_FRAMES)) % WALK_FRAMES
        key_stages = (facing, bucket, flipped_v, "stages")

        if key_stages not in self._frame_cache:
            # Trigger frame + stage baking for this orientation
            self._get_frame(facing, phase, flipped_v=flipped_v)

        stage_surfs = self._frame_cache[key_stages]   # pre-baked by _get_frame
        ghost = EscherTrailGhost(
            stage_surfs=stage_surfs,
            x=player.body.px,
            y=player.body.py,
            index=self._ghost_index,
        )
        self._ghost_index += 1
        self._ghosts.append(ghost)
