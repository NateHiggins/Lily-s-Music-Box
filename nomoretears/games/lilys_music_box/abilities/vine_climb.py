"""
games/lilys_music_box/abilities/vine_climb.py
----------------------------------------------
VINE_ANCHOR_CLIMB — the platforming ability unlocked by the KLIMT_TREE_OF_LIFE
ruleset.

Functional description
───────────────────────
While the klimt_dining tileset is active, certain air-cell tiles carry
climbable vine metadata.  When the player's collision box overlaps any
climbable vine cell the ability enters ATTACHED state.  Pressing Up or Down
(or moving on the analogue stick vertically) transitions to CLIMBING.

CLIMBING behaviour
  • Gravity is suppressed via PhysicsBody.vine_anchor = True.
  • Vertical input moves the player up or down at CLIMB_SPEED px/s.
  • No vertical input → slow slide downward at SLIDE_SPEED px/s.
  • Horizontal input is not blocked — the player can walk off a vine laterally,
    which naturally ends the climb when overlap is lost.
  • Jump releases from the vine immediately (vine_anchor cleared inside physics).

Visual affordances
  • Climbable cells glow with a faint gold shimmer drawn in render_ability_layer.
  • Glow pulses at a slow frequency to feel ornamental rather than gamey.
  • In non-Klimt rooms: no cells, no glow, no state (ability is not called).

Vine validation rule
  Only cells whose role appears in KlimtTilesetProvider._CLIMBABLE_ROLES are
  added to _climbable_cells.  This guarantees that eye/triangle special motifs
  and stair/landing tiles are never climbable even if they visually appear
  attached to a vine network.

Performance contract
  _climbable_cells is rebuilt once per room entry in on_room_enter().
  update() performs only set-membership tests (O(1)) and two physics writes.
  render_ability_layer() creates one SRCALPHA surface per frame for the glow
  pulse; surfaces are small (TILE_W × TILE_H) and reused via a per-cell blit
  of the same pre-built surface.
"""
from __future__ import annotations

import math
from enum import Enum, auto
from typing import TYPE_CHECKING, Any

import pygame

from engine.physics import PLAYER_W, PLAYER_H
from engine.room_graph import TILE_W, TILE_H, TILE_SCALE

if TYPE_CHECKING:
    from engine.entities import PlayerEntity
    from engine.proc_gen import GeneratedLayout
    from engine.state import GameState


# ── Constants ─────────────────────────────────────────────────────────────────

CLIMB_SPEED = 80.0      # px / s — vertical movement while actively climbing
SLIDE_SPEED = 18.0      # px / s — passive downward drift while idle on vine
GLOW_COLOR  = (212, 175, 55)   # Klimt gold leaf (#D4AF37)
GLOW_ALPHA_BASE = 30           # base alpha for vine glow tile
GLOW_ALPHA_PULSE = 20          # additional alpha at glow peak


def _s(n: float) -> int:
    return max(1, round(n * TILE_SCALE))


# ── State machine ─────────────────────────────────────────────────────────────

class _ClimbState(Enum):
    IDLE      = auto()    # not touching any climbable vine
    ATTACHED  = auto()    # touching vine, not yet actively climbing
    CLIMBING  = auto()    # vine_anchor active, gravity suppressed


# ── VineAnchorClimb ───────────────────────────────────────────────────────────

class VineAnchorClimb:
    """
    VINE_ANCHOR_CLIMB ability for the KLIMT_TREE_OF_LIFE ruleset.

    Constructed with a reference to the KlimtTilesetProvider so it can read
    _vine_climbable_cells after each room's air_layout() call populates it.
    """

    def __init__(self, klimt_provider) -> None:
        """
        klimt_provider: KlimtTilesetProvider instance.
        The ability reads provider._vine_climbable_cells to know which cells
        the player can grab this room — populated after each air_layout() call.
        """
        self._provider          = klimt_provider
        self._climbable_cells:  set[tuple[int, int]] = set()
        self._state:            _ClimbState = _ClimbState.IDLE
        self._game_time:        float = 0.0
        # Pre-baked glow surface — rebuilt once per room entry (tile size fixed).
        self._glow_surf:        pygame.Surface | None = None

    # ── ArtPlatformAbility protocol ────────────────────────────────────────────

    def on_room_enter(
        self,
        layout: "GeneratedLayout",
        deco_map: "dict[tuple[int,int], str]",
    ) -> None:
        """
        Sync climbable-cell set from the tileset provider.

        The provider's air_layout() populates _vine_climbable_cells as a side
        effect; we copy that set here so the ability owns its own snapshot and
        is not affected by subsequent room transitions before the set is rebuilt.
        """
        self._state = _ClimbState.IDLE
        # Provider has already computed the set (air_layout was called in
        # _Session._notify_ability_room_enter before this method runs).
        self._climbable_cells = set(getattr(self._provider, "_vine_climbable_cells", set()))
        self._glow_surf = None   # force rebuild on next render

    def on_ruleset_deactivate(self, player: "PlayerEntity") -> None:
        """Release physics state immediately when tileset switches away."""
        player.body.vine_anchor = False
        self._state = _ClimbState.IDLE
        self._climbable_cells.clear()

    def update(
        self,
        dt: float,
        player: "PlayerEntity",
        state: "GameState",
        layout: "GeneratedLayout",
        jump_pressed: bool,
    ) -> None:
        """
        Core ability update — runs after PhysicsBody.update() each frame.

        Checks player AABB overlap with climbable vine cells.  Manages the
        IDLE / ATTACHED / CLIMBING state machine.  When CLIMBING:
          - sets vine_anchor = True (suppresses next frame's gravity)
          - reads vertical key input and writes vy for the next physics step
        """
        self._game_time += dt

        # Jump releases vine — physics already cleared vine_anchor and fired
        # the jump when _jump_buffer consumed it.  Mirror state here.
        if jump_pressed and self._state == _ClimbState.CLIMBING:
            self._state = _ClimbState.IDLE
            # vine_anchor was cleared inside physics on jump
            return

        # Determine which vine cells the player currently overlaps.
        touching = self._touching_vine_cells(player)

        if not touching:
            # Left all vine cells — release.
            if self._state != _ClimbState.IDLE:
                player.body.vine_anchor = False
            self._state = _ClimbState.IDLE
            return

        # Player is overlapping at least one vine cell.
        keys = pygame.key.get_pressed()
        wants_climb = (
            keys[pygame.K_UP]   or keys[pygame.K_w]
            or keys[pygame.K_DOWN] or keys[pygame.K_s]
        )

        if self._state == _ClimbState.IDLE:
            # Transition to ATTACHED on first contact.
            self._state = _ClimbState.ATTACHED

        if self._state == _ClimbState.ATTACHED and wants_climb:
            # Player pressed a vertical key while touching vine → start climbing.
            self._state = _ClimbState.CLIMBING

        if self._state == _ClimbState.CLIMBING:
            # Suppress gravity for this frame; ability controls vy.
            player.body.vine_anchor = True

            if keys[pygame.K_UP] or keys[pygame.K_w]:
                player.body.vy = -CLIMB_SPEED
            elif keys[pygame.K_DOWN] or keys[pygame.K_s]:
                player.body.vy = CLIMB_SPEED
            else:
                # Passive slide — slow downward drift
                player.body.vy = SLIDE_SPEED

    def render_ability_layer(self, surface: pygame.Surface) -> None:
        """
        Draw a gentle pulsing gold glow over every climbable vine cell.

        Pulse frequency is slow (0.8 Hz) so the effect reads as ornamental
        rather than a bright "climbable!" warning indicator.  The glow is
        intentionally subtle — it should be discoverable, not obvious.
        """
        if not self._climbable_cells:
            return

        pulse = GLOW_ALPHA_BASE + round(
            GLOW_ALPHA_PULSE * math.sin(self._game_time * 2 * math.pi * 0.8)
        )

        if self._glow_surf is None:
            self._glow_surf = pygame.Surface((TILE_W, TILE_H), pygame.SRCALPHA)

        # Rebuild glow surface with current pulse alpha
        self._glow_surf.fill((0, 0, 0, 0))
        self._glow_surf.fill((*GLOW_COLOR, max(0, pulse)))

        for (c, r) in self._climbable_cells:
            surface.blit(self._glow_surf, (c * TILE_W, r * TILE_H))

    def get_debug_status(self) -> dict[str, Any]:
        return {
            "climb_state":      self._state.name,
            "vine_cells":       len(self._climbable_cells),
        }

    # ── Internal ──────────────────────────────────────────────────────────────

    def _touching_vine_cells(
        self, player: "PlayerEntity"
    ) -> list[tuple[int, int]]:
        """
        Return the vine cells (col, row) whose tile rect overlaps the player AABB.

        Checks only the 3×3 tile neighborhood of the player's centre to keep
        this O(9) regardless of room size or number of vine cells.
        """
        cx = int(player.body.center_x / TILE_W)
        cy = int(player.body.center_y / TILE_H)
        player_rect = player.body.rect
        touching = []
        for dc in (-1, 0, 1):
            for dr in (-1, 0, 1):
                cell = (cx + dc, cy + dr)
                if cell not in self._climbable_cells:
                    continue
                tile_rect = pygame.Rect(
                    cell[0] * TILE_W, cell[1] * TILE_H, TILE_W, TILE_H
                )
                if player_rect.colliderect(tile_rect):
                    touching.append(cell)
        return touching
