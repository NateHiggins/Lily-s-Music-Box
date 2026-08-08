"""
engine/physics.py
-----------------
Player physics body: position, velocity, gravity, collision with solid tiles,
one-way platform collision, updraft zones.

Coordinate system: pygame screen coords — y increases downward.
Tile (col, row) maps to pixel rect (col*TILE_W, row*TILE_H, TILE_W, TILE_H).
Player position is stored as pixel floats (center_x, center_y).
"""
from __future__ import annotations

import pygame
from engine.room_graph import TILE_W, TILE_H, ROOM_COLS, ROOM_ROWS, TILE_SCALE
from engine.proc_gen import GeneratedLayout


# All constants are the 32-px-tile originals scaled by TILE_SCALE (1.25).
# Jump height in *tiles* is preserved exactly: v²/(2g) / TILE_H = constant.
GRAVITY         = 1750.0   # px / s²  (1400 × 1.25)
JUMP_VELOCITY   = -625.0   # px / s   (500  × 1.25)
WALK_SPEED      = 225.0    # px / s   (180  × 1.25)
UPDRAFT_FORCE   = -1125.0  # px / s   (900  × 1.25)
MAX_FALL_SPEED  = 750.0    # px / s   (600  × 1.25)

PLAYER_W = 25    # 20 × 1.25
PLAYER_H = 35    # 28 × 1.25

# ── Input timing windows ───────────────────────────────────────────────────────
# Jump buffer: if jump is pressed up to this many seconds before landing, the
# jump fires as soon as the player touches ground — eliminates "missed just before
# landing" misses entirely.
JUMP_BUFFER_TIME = 0.12   # seconds

# Coyote time: after walking off a ledge the player can still jump for this long.
# Eliminates the frustrating "I pressed jump as I stepped off the edge" miss.
COYOTE_TIME = 0.10        # seconds

# Deadzone for analogue stick horizontal axis
JOY_DEADZONE = 0.20


class PhysicsBody:
    """
    AABB player physics body.
    Stores pixel position of the player's top-left corner.

    Jump feel is improved by two timing windows:
      jump_buffer  — remembers a jump press for up to JUMP_BUFFER_TIME so a
                     jump input that arrives slightly before landing still fires.
      coyote_time  — keeps the player "jump eligible" for COYOTE_TIME after
                     walking off a ledge so the first frame in the air still jumps.
    """

    def __init__(self, px: float, py: float) -> None:
        self.px = px          # left edge
        self.py = py          # top edge
        self.vx = 0.0
        self.vy = 0.0
        self.on_ground = False
        self.in_updraft = False
        # vine_anchor: set True each frame by VineAnchorClimb while the player
        # is attached to a climbable vine.  Suppresses gravity and allows the
        # ability to control vy directly.  Cleared to False every frame by the
        # ability so it acts as a "this-frame" signal rather than sticky state.
        self.vine_anchor: bool = False
        self._jump_buffer: float = 0.0   # counts down after jump key pressed
        self._coyote_time: float = 0.0   # counts down after leaving ground

    @property
    def rect(self) -> pygame.Rect:
        return pygame.Rect(int(self.px), int(self.py), PLAYER_W, PLAYER_H)

    @property
    def center_x(self) -> float:
        return self.px + PLAYER_W / 2

    @property
    def center_y(self) -> float:
        return self.py + PLAYER_H / 2

    @property
    def col(self) -> int:
        return int(self.center_x / TILE_W)

    @property
    def row(self) -> int:
        return int((self.py + PLAYER_H) / TILE_H)  # feet tile row

    def tile_col_from_x(self) -> int:
        return int(self.center_x / TILE_W)

    def update(
        self,
        dt: float,
        keys: pygame.key.ScancodeWrapper,
        layout: GeneratedLayout,
        jump_pressed: bool,
        joy_move: float = 0.0,       # analogue horizontal axis, range -1..1
        updraft_active: bool = True, # False when active tileset has no updraft mechanic
    ) -> None:
        # Feed fresh jump press into the buffer; tick both windows.
        if jump_pressed:
            self._jump_buffer = JUMP_BUFFER_TIME
        self._jump_buffer = max(0.0, self._jump_buffer - dt)
        self._coyote_time  = max(0.0, self._coyote_time  - dt)

        was_on_ground = self.on_ground
        self._apply_input(keys, joy_move)
        self._apply_updraft(layout, updraft_active=updraft_active)
        self._apply_gravity(dt, layout)
        self._move(dt, layout)

        # Seed coyote window when the player just left the ground naturally
        # (walked off ledge — not from a jump, which sets vy negative).
        if was_on_ground and not self.on_ground and self.vy >= 0:
            self._coyote_time = COYOTE_TIME

        # Consume jump buffer: fire jump if ground, coyote window, or vine-anchored.
        can_jump = (
            self.on_ground or self.in_updraft
            or self._coyote_time > 0 or self.vine_anchor
        )
        if self._jump_buffer > 0 and can_jump:
            self.vy = JUMP_VELOCITY
            self._jump_buffer = 0.0
            self._coyote_time  = 0.0
            self.vine_anchor   = False   # release vine immediately on jump

    def _apply_input(
        self,
        keys: pygame.key.ScancodeWrapper,
        joy_move: float = 0.0,
    ) -> None:
        # Keyboard horizontal — analogue axis overrides if its magnitude is larger
        kb_move = 0.0
        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            kb_move = -1.0
        if keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            kb_move = 1.0

        move = joy_move if abs(joy_move) > abs(kb_move) else kb_move
        self.vx = move * WALK_SPEED

    def _apply_updraft(
        self, layout: GeneratedLayout, *, updraft_active: bool = True
    ) -> None:
        # Updraft is exclusive to certain tilesets (Escher).  When the active
        # tileset doesn't support it, clear the flag and return immediately so
        # existing updraft zones exert no force and draw no glow.
        if not updraft_active or layout.updraft is None:
            self.in_updraft = False
            return
        ucol, rtop, rbot = layout.updraft
        # Updraft zone spans 2 tiles wide centered on ucol
        ux_left  = (ucol - 1) * TILE_W
        ux_right = (ucol + 2) * TILE_W
        uy_top   = rtop * TILE_H
        uy_bot   = (rbot + 1) * TILE_H
        cx = self.center_x
        cy = self.center_y
        if ux_left <= cx <= ux_right and uy_top <= cy <= uy_bot:
            self.in_updraft = True
            if self.vy > UPDRAFT_FORCE * 0.1:   # only push if falling or slow
                self.vy += UPDRAFT_FORCE * 0.06  # gentle sustained lift
        else:
            self.in_updraft = False

    def _apply_gravity(self, dt: float, layout: GeneratedLayout) -> None:
        # Gravity is suppressed while vine-anchored — the ability owns vy.
        if not self.in_updraft and not self.vine_anchor:
            self.vy += GRAVITY * dt
        self.vy = min(self.vy, MAX_FALL_SPEED)

    def _move(self, dt: float, layout: GeneratedLayout) -> None:
        # Move X then Y, resolving collisions after each axis.
        new_px = self.px + self.vx * dt
        new_px = max(0.0, min(new_px, ROOM_COLS * TILE_W - PLAYER_W))
        self.px = new_px

        new_py = self.py + self.vy * dt
        self.on_ground = False

        # Gather solid tile rects that could collide
        solids = _solid_rects_near(self.px, new_py, layout)
        player_rect = pygame.Rect(int(self.px), int(new_py), PLAYER_W, PLAYER_H)

        for tile_rect in solids:
            if player_rect.colliderect(tile_rect):
                if self.vy >= 0:
                    # Falling — land on top
                    player_rect.bottom = tile_rect.top
                    new_py = float(player_rect.top)
                    self.vy = 0.0
                    self.on_ground = True
                elif self.vy < 0:
                    # Rising — hit ceiling
                    player_rect.top = tile_rect.bottom
                    new_py = float(player_rect.top)
                    self.vy = 0.0

        # Clamp to screen vertically
        new_py = max(0.0, new_py)
        self.py = new_py


def _solid_rects_near(
    px: float, py: float, layout: GeneratedLayout
) -> list[pygame.Rect]:
    """Return solid tile rects within a few tiles of the player position."""
    cx = int((px + PLAYER_W / 2) / TILE_W)
    cy_top = max(0, int(py / TILE_H) - 1)
    cy_bot = min(ROOM_ROWS - 1, int((py + PLAYER_H) / TILE_H) + 1)
    cx_min = max(0, cx - 2)
    cx_max = min(ROOM_COLS - 1, cx + 2)
    rects = []
    for c in range(cx_min, cx_max + 1):
        for r in range(cy_top, cy_bot + 1):
            if layout.is_solid(c, r):
                rects.append(pygame.Rect(c * TILE_W, r * TILE_H, TILE_W, TILE_H))
    return rects


def spawn_position_from_direction(direction: str) -> tuple[float, float]:
    """
    Given entry direction, return pixel (px, py) spawn for the player.
    "center" is used for the start room so the player isn't adjacent to any exit.
    """
    floor_top_y = (ROOM_ROWS - 3) * TILE_H - PLAYER_H
    if direction == "center":
        return (ROOM_COLS * TILE_W / 2 - PLAYER_W / 2, floor_top_y)
    if direction in ("west", "upper_west", "bypass_west"):
        return (TILE_W * 3.0, floor_top_y)
    if direction in ("east", "upper_east", "bypass_east"):
        return (ROOM_COLS * TILE_W - TILE_W * 3 - PLAYER_W, floor_top_y)
    # Default: left side floor
    return (TILE_W * 3.0, floor_top_y)
