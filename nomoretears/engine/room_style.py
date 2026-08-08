"""
engine/room_style.py
--------------------
RoomStyle protocol: per-tileset visual effect hooks for player rendering.

Each tileset can register a RoomStyle that replaces or augments the default
player sprite.  The engine calls update() every frame and delegates drawing
to draw_trail() / draw_player() instead of _draw_player().

Implementations live in games/<module>/styles/ and are registered in
GameBundle.room_styles keyed by tileset_id.
"""
from __future__ import annotations

from typing import TYPE_CHECKING, Protocol, runtime_checkable

if TYPE_CHECKING:
    import pygame
    from engine.entities import PlayerEntity
    from engine.room_graph import GeneratedLayout
    from engine.state import GameState


@runtime_checkable
class RoomStyle(Protocol):
    """
    Visual effect plugin for a specific tileset.

    Lifecycle (called by _Session and Renderer):
      1. update(dt, player, state) — advance animation state every frame
      2. on_room_change()          — reset transient state (trail, phase, etc.)
      3. draw_trail(surface)       — blit ghost trail BEFORE NPCs
      4. draw_player(surface, player, tick) — replace the default player blit
    """

    def update(
        self,
        dt: float,
        player: "PlayerEntity",
        state: "GameState",
        layout: "GeneratedLayout | None" = None,
    ) -> None:
        """Advance internal timers, spawn ghost samples, age trail stages."""
        ...

    def on_room_change(self) -> None:
        """Clear trail and reset per-room transient state."""
        ...

    def draw_trail(self, surface: "pygame.Surface") -> None:
        """Draw ghost-trail sprites behind the player (called before NPCs)."""
        ...

    def draw_player(
        self,
        surface: "pygame.Surface",
        player: "PlayerEntity",
        tick: int,
    ) -> None:
        """Draw the player sprite (replaces default rectangle/sprite)."""
        ...
