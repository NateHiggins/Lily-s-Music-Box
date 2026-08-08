"""
games/lilys_music_box/abilities/swing_ascend.py
------------------------------------------------
SWING_ASCEND — traversal ability for the FRAGONARD_THE_SWING ruleset.

Traversal language summary
───────────────────────────
Conventional jumping is removed.  The garden operates on momentum.

  HIDDEN_GARDEN   — player on ground.  Sprite invisible (foliage occludes).
                    Environmental feedback (particles, shadow) marks position.

  CHAIN_SEEK      — UP pressed with a valid anchor above.  Chain animates
                    upward during a brief launch window, then locks.

  SWINGING        — pendulum physics.  LEFT/RIGHT add angular momentum.
                    UP reels the chain shorter.  DOWN or jump-key releases.

  FALLING         — chain broken.  Full momentum preserved.  Normal gravity.
                    Landing on floor → HIDDEN_GARDEN.
                    Landing on a branch node → BRANCH_PERCH.

  BRANCH_PERCH    — standing on a branch node in mid-air.  Visible.
                    UP re-triggers Ascend.  Any horizontal move or delay
                    causes natural fall into FALLING.

Physics contract
─────────────────
Ability runs AFTER PhysicsBody.update() each frame.

In SWINGING:
  vine_anchor = True (set at end of each ability frame) → gravity suppressed
  next frame's physics does nothing (vx=0, vy=0, vine_anchor prevents gravity)
  ability then overrides px/py from pendulum computation

In HIDDEN_GARDEN / BRANCH_PERCH:
  If jump_pressed (UP/SPACE key from engine) was set, ability intercepts it:
  if an anchor is found above → cancel jump (vy = 0), start CHAIN_SEEK.
  if no anchor → jump fires normally as a one-time garden stagger (Lily
  stumbles briefly, giving feedback that the garden has no anchor above here).

Anchor cells
─────────────
GuardianGothicTilesetProvider.air_layout() populates _anchor_cells after
each room entry.  The ability reads this set on on_room_enter().
Anchors are (col, row) cells with role "branch_node", "pulley_node", or
"arch_anchor".  Only cells above the player's current row are valid targets
for Ascend.
"""
from __future__ import annotations

import math
from enum import Enum, auto
from typing import TYPE_CHECKING, Any

import pygame

from engine.physics import GRAVITY, PLAYER_W, PLAYER_H
from engine.room_graph import TILE_W, TILE_H, ROOM_COLS, ROOM_ROWS, TILE_SCALE

if TYPE_CHECKING:
    from engine.entities import PlayerEntity
    from engine.proc_gen import GeneratedLayout
    from engine.state import GameState


# ── Constants ─────────────────────────────────────────────────────────────────

# Pendulum physics
SWING_DAMPING       = 0.012    # angular damping coefficient per second
SWING_INPUT_TORQUE  = 3.8      # rad/s² per second of LEFT/RIGHT input
CHAIN_REEL_SPEED    = 90.0     # px / s — shortens chain while UP held
CHAIN_MIN_LEN       = 48.0     # shortest the chain can reel to (px)
CHAIN_MAX_LEN       = 300.0    # longest initial chain on Ascend (px)
CHAIN_NATURAL       = 180.0    # default chain length when anchor is found

# Ascend search
ASCEND_MAX_DIST_PX  = 320      # max search distance upward for anchors (px)
ASCEND_H_RANGE      = 6        # max column-offset to consider for "above" anchor
CHAIN_SEEK_TIME     = 0.18     # s — animation delay before SWINGING locks in

# Branch perch
BRANCH_PERCH_GRACE  = 0.4      # s — time before auto-falling from BRANCH_PERCH

# Foliage / ground state
GROUND_ROW_THRESHOLD = ROOM_ROWS - 4   # rows at or below this are "ground space"

# Stagger feedback when no anchor is found (short jump impulse)
STAGGER_VY          = -140.0   # px/s — small hop so player knows they tried

# Glow colour for branch/pulley anchor cells in debug overlay
ANCHOR_GLOW_COLOR   = (180, 230, 140)   # soft garden green
ANCHOR_GLOW_ALPHA   = 28


def _s(n: float) -> int:
    return max(1, round(n * TILE_SCALE))


# ── State machine ─────────────────────────────────────────────────────────────

class SwingState(Enum):
    HIDDEN_GARDEN  = auto()   # on ground, invisible
    CHAIN_SEEK     = auto()   # chain launching toward anchor
    SWINGING       = auto()   # pendulum active
    FALLING        = auto()   # freefall, momentum preserved
    BRANCH_PERCH   = auto()   # standing on a branch node mid-air


# ── SwingAscendAbility ────────────────────────────────────────────────────────

class SwingAscendAbility:
    """
    SWING_ASCEND traversal ability for the Fragonard / guardian_gothic ruleset.

    Constructed with a reference to the GuardianGothicTilesetProvider so it can
    read _anchor_cells after each room's air_layout() call populates them.
    """

    def __init__(self, guardian_provider) -> None:
        self._provider = guardian_provider

        # Anchor cell set — rebuilt on room enter from the provider
        self._anchor_cells: set[tuple[int, int]] = set()

        # State machine
        self._state: SwingState = SwingState.HIDDEN_GARDEN

        # Pendulum physics
        self._angle:        float = 0.0     # radians from vertical (+ = CW/right)
        self._angular_vel:  float = 0.0     # rad/s
        self._chain_len:    float = CHAIN_NATURAL

        # Active anchor (col, row) when SWINGING or CHAIN_SEEK
        self._anchor_col:   int = 0
        self._anchor_row:   int = 0

        # Chain seek timer
        self._seek_timer:   float = 0.0

        # Branch perch timer
        self._perch_timer:  float = 0.0

        # Game time for glow pulse
        self._game_time:    float = 0.0

        # Pre-baked anchor glow surface (rebuilt once per room)
        self._glow_surf:    pygame.Surface | None = None

    # ── ArtPlatformAbility protocol ────────────────────────────────────────────

    def on_room_enter(
        self,
        layout: "GeneratedLayout",
        deco_map: "dict[tuple[int,int], str]",
    ) -> None:
        """Copy anchor cells from the provider's post-air-layout set."""
        self._state       = SwingState.HIDDEN_GARDEN
        self._angle       = 0.0
        self._angular_vel = 0.0
        self._chain_len   = CHAIN_NATURAL
        self._seek_timer  = 0.0
        self._perch_timer = 0.0
        self._glow_surf   = None

        anchor_roles = {"branch_node", "pulley_node", "arch_anchor"}
        self._anchor_cells = {
            cell for cell, role in deco_map.items()
            if role in anchor_roles
        }

    def on_ruleset_deactivate(self, player: "PlayerEntity") -> None:
        """Return to normal physics when tileset switches away."""
        player.body.vine_anchor = False
        self._state = SwingState.HIDDEN_GARDEN
        self._anchor_cells.clear()

    def update(
        self,
        dt: float,
        player: "PlayerEntity",
        state: "GameState",
        layout: "GeneratedLayout",
        jump_pressed: bool,
    ) -> None:
        self._game_time += dt
        keys = pygame.key.get_pressed()

        if self._state == SwingState.HIDDEN_GARDEN:
            self._update_hidden_garden(dt, player, keys, jump_pressed)

        elif self._state == SwingState.CHAIN_SEEK:
            self._update_chain_seek(dt, player)

        elif self._state == SwingState.SWINGING:
            self._update_swinging(dt, player, keys, jump_pressed, layout)

        elif self._state == SwingState.FALLING:
            self._update_falling(dt, player, layout)

        elif self._state == SwingState.BRANCH_PERCH:
            self._update_branch_perch(dt, player, keys, jump_pressed)

    def render_ability_layer(self, surface: pygame.Surface) -> None:
        """
        Draw a soft green glow over all anchor cells so the garden hints at
        Ascend opportunities without making them mechanically obvious.
        """
        if not self._anchor_cells:
            return

        pulse = ANCHOR_GLOW_ALPHA + round(
            8 * math.sin(self._game_time * 2 * math.pi * 0.6)
        )

        if self._glow_surf is None:
            self._glow_surf = pygame.Surface((TILE_W, TILE_H), pygame.SRCALPHA)

        self._glow_surf.fill((0, 0, 0, 0))
        self._glow_surf.fill((*ANCHOR_GLOW_COLOR, max(0, pulse)))

        for c, r in self._anchor_cells:
            surface.blit(self._glow_surf, (c * TILE_W, r * TILE_H))

    def get_debug_status(self) -> dict[str, Any]:
        return {
            "swing_state":    self._state.name,
            "anchor_cells":   len(self._anchor_cells),
            "angle_deg":      round(math.degrees(self._angle), 1),
            "angular_vel":    round(self._angular_vel, 3),
            "chain_len":      round(self._chain_len, 1),
            "anchor":         (self._anchor_col, self._anchor_row),
        }

    # ── Visibility query (read by FragonardGardenFlow) ─────────────────────────

    @property
    def player_visible(self) -> bool:
        """True when Lily should be drawn; False when foliage conceals her."""
        return self._state not in (SwingState.HIDDEN_GARDEN,)

    @property
    def is_swinging(self) -> bool:
        return self._state == SwingState.SWINGING

    @property
    def swing_data(self) -> dict:
        """Return pendulum geometry for FragonardGardenFlow to render."""
        return {
            "anchor_col":    self._anchor_col,
            "anchor_row":    self._anchor_row,
            "chain_len":     self._chain_len,
            "angle":         self._angle,
            "seek_frac":     min(1.0, 1.0 - self._seek_timer / CHAIN_SEEK_TIME)
            if self._state == SwingState.CHAIN_SEEK else 1.0,
            "is_seek":       self._state == SwingState.CHAIN_SEEK,
        }

    # ── State handlers ─────────────────────────────────────────────────────────

    def _update_hidden_garden(
        self,
        dt: float,
        player: "PlayerEntity",
        keys: pygame.key.ScancodeWrapper,
        jump_pressed: bool,
    ) -> None:
        """
        On the ground, concealed.  UP (jump_pressed) triggers Ascend search.
        If no anchor is found, apply the stagger impulse for tactile feedback.
        Physics ran first and may have set vy = JUMP_VELOCITY — we override it.
        """
        # Suppress vine_anchor so normal gravity and collision operate.
        player.body.vine_anchor = False

        if not jump_pressed:
            return

        # Player pressed UP/SPACE — search for an anchor above.
        anchor = self._find_anchor_above(player)
        if anchor is not None:
            self._anchor_col, self._anchor_row = anchor
            # Cancel the physics jump that already fired this frame.
            player.body.vy = 0.0
            self._seek_timer = CHAIN_SEEK_TIME
            self._chain_len  = CHAIN_NATURAL
            # Set initial angle from player position relative to anchor
            ax = self._anchor_col * TILE_W + TILE_W // 2
            ay = self._anchor_row * TILE_H + TILE_H // 2
            px = player.body.center_x
            py = player.body.center_y
            dx, dy = px - ax, py - ay
            self._angle       = math.atan2(dx, max(1.0, dy))
            self._angular_vel = 0.0
            self._state       = SwingState.CHAIN_SEEK
            # Hold player in place during seek animation
            player.body.vine_anchor = True
            player.body.vy = 0.0
        else:
            # No anchor — small stagger hop so the player feels the attempt.
            # Physics already fired a full jump (vy = JUMP_VELOCITY); replace
            # with a gentler stagger so it reads as a stumble, not a full jump.
            player.body.vy = STAGGER_VY

    def _update_chain_seek(self, dt: float, player: "PlayerEntity") -> None:
        """
        Brief animation window: chain travels toward anchor.
        Lily lifts slightly as the chain tightens.
        """
        # Suppress gravity during seek.
        player.body.vine_anchor = True
        player.body.vy          = 0.0
        player.body.vx          = 0.0

        self._seek_timer -= dt
        if self._seek_timer <= 0.0:
            self._state = SwingState.SWINGING

    def _update_swinging(
        self,
        dt: float,
        player: "PlayerEntity",
        keys: pygame.key.ScancodeWrapper,
        jump_pressed: bool,
        layout: "GeneratedLayout",
    ) -> None:
        """
        Full pendulum ownership.
        Physics has already run with vine_anchor=True (set last frame),
        so its contribution was neutral.  We now recompute everything.
        """
        # Suppress physics for next frame.
        player.body.vine_anchor = True
        player.body.vx          = 0.0
        player.body.vy          = 0.0

        # Release on DOWN or jump key.
        if jump_pressed or (keys[pygame.K_DOWN] or keys[pygame.K_s]):
            self._release_to_falling(player)
            return

        # Reel: UP shortens chain.
        if keys[pygame.K_UP] or keys[pygame.K_w]:
            self._chain_len = max(CHAIN_MIN_LEN, self._chain_len - CHAIN_REEL_SPEED * dt)

        # Pendulum torque from LEFT / RIGHT input.
        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            self._angular_vel -= SWING_INPUT_TORQUE * dt
        if keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            self._angular_vel += SWING_INPUT_TORQUE * dt

        # Pendulum physics: α = -(g/L) sin(θ) − damping·ω
        g_over_l = GRAVITY / max(1.0, self._chain_len)
        angular_accel = (
            -g_over_l * math.sin(self._angle)
            - SWING_DAMPING * self._angular_vel
        )
        self._angular_vel += angular_accel * dt
        self._angle       += self._angular_vel * dt

        # Anchor pixel centre.
        ax = float(self._anchor_col * TILE_W + TILE_W // 2)
        ay = float(self._anchor_row * TILE_H + TILE_H // 2)

        # Player position from pendulum geometry.
        new_px = ax + self._chain_len * math.sin(self._angle) - PLAYER_W / 2
        new_py = ay + self._chain_len * math.cos(self._angle) - PLAYER_H / 2

        # Boundary clamp — prevent swinging into room walls.
        new_px = max(0.0, min(new_px, ROOM_COLS * TILE_W - PLAYER_W))
        new_py = max(0.0, min(new_py, (ROOM_ROWS - 1) * TILE_H - PLAYER_H))

        # If pendulum tries to enter a solid tile, release instead of clipping.
        test_col = int((new_px + PLAYER_W / 2) / TILE_W)
        test_row = int((new_py + PLAYER_H)     / TILE_H)
        if layout.is_solid(test_col, test_row):
            self._release_to_falling(player)
            return

        player.body.px = new_px
        player.body.py = new_py
        # Store velocity so Release launches at the correct trajectory.
        player.body.vx = self._chain_len * self._angular_vel * math.cos(self._angle)
        player.body.vy = self._chain_len * self._angular_vel * math.sin(self._angle)

    def _update_falling(
        self,
        dt: float,
        player: "PlayerEntity",
        layout: "GeneratedLayout",
    ) -> None:
        """
        Chain has been released.  Normal physics owns the player.
        Detect landing: ground → HIDDEN_GARDEN, branch node → BRANCH_PERCH.
        """
        player.body.vine_anchor = False

        # Ground landing.
        if player.body.on_ground:
            self._state = SwingState.HIDDEN_GARDEN
            return

        # Branch node landing.
        if self._touching_anchor(player):
            self._state       = SwingState.BRANCH_PERCH
            self._perch_timer = BRANCH_PERCH_GRACE
            # Stick to top of branch cell — zero out downward velocity.
            if player.body.vy > 0:
                player.body.vy = 0.0
            return

    def _update_branch_perch(
        self,
        dt: float,
        player: "PlayerEntity",
        keys: pygame.key.ScancodeWrapper,
        jump_pressed: bool,
    ) -> None:
        """
        Lily stands on a branch node.  Visible.  Ascend available via UP.
        Auto-fall after grace timer expires (prevents sticky platform feel).
        """
        player.body.vine_anchor = True   # suppress gravity during perch
        player.body.vy          = 0.0

        # Ascend from perch.
        if jump_pressed:
            anchor = self._find_anchor_above(player)
            if anchor is not None:
                self._anchor_col, self._anchor_row = anchor
                ax = self._anchor_col * TILE_W + TILE_W // 2
                ay = self._anchor_row * TILE_H + TILE_H // 2
                dx, dy = player.body.center_x - ax, player.body.center_y - ay
                self._angle       = math.atan2(dx, max(1.0, dy))
                self._angular_vel = 0.0
                self._chain_len   = CHAIN_NATURAL
                self._seek_timer  = CHAIN_SEEK_TIME
                player.body.vy    = 0.0
                self._state       = SwingState.CHAIN_SEEK
                return
            else:
                # No anchor — drop off the branch.
                player.body.vine_anchor = False
                self._state = SwingState.FALLING
                return

        # Auto-fall if grace expires or player moves horizontally.
        self._perch_timer -= dt
        moving_h = (keys[pygame.K_LEFT] or keys[pygame.K_a]
                    or keys[pygame.K_RIGHT] or keys[pygame.K_d])
        if self._perch_timer <= 0.0 or moving_h:
            player.body.vine_anchor = False
            self._state = SwingState.FALLING

    # ── Internal helpers ───────────────────────────────────────────────────────

    def _release_to_falling(self, player: "PlayerEntity") -> None:
        """Break the chain.  Velocity is already stored on the body."""
        player.body.vine_anchor = False
        self._state             = SwingState.FALLING

    def _find_anchor_above(
        self, player: "PlayerEntity"
    ) -> tuple[int, int] | None:
        """
        Return the nearest anchor cell that is above the player and within
        the horizontal search window.  Returns None if no valid anchor exists.

        Search strategy: prefer anchors directly overhead; accept a wider
        horizontal window to give the player a forgiving Ascend target.
        """
        px = player.body.center_x
        py = player.body.center_y
        p_col = int(px / TILE_W)

        best: tuple[int, int] | None = None
        best_dist: float = float("inf")

        for col, row in self._anchor_cells:
            # Must be strictly above the player.
            cell_bottom_py = (row + 1) * TILE_H
            if cell_bottom_py >= py:
                continue
            # Within horizontal range.
            if abs(col - p_col) > ASCEND_H_RANGE:
                continue
            ax = col * TILE_W + TILE_W // 2
            ay = row * TILE_H + TILE_H // 2
            dist = math.hypot(ax - px, ay - py)
            if dist < best_dist and dist <= ASCEND_MAX_DIST_PX:
                best_dist = dist
                best      = (col, row)

        return best

    def _touching_anchor(self, player: "PlayerEntity") -> bool:
        """True when the player's AABB overlaps any anchor cell."""
        cx = int(player.body.center_x / TILE_W)
        cy = int(player.body.center_y / TILE_H)
        pr = player.body.rect
        for dc in (-1, 0, 1):
            for dr in (-1, 0, 1):
                cell = (cx + dc, cy + dr)
                if cell not in self._anchor_cells:
                    continue
                tile_rect = pygame.Rect(
                    cell[0] * TILE_W, cell[1] * TILE_H, TILE_W, TILE_H
                )
                if pr.colliderect(tile_rect):
                    return True
        return False
