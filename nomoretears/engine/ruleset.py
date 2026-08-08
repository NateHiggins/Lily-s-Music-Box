"""
engine/ruleset.py
-----------------
ArtRuleset: per-tileset rule container tying visual style, platforming ability,
and environmental logic to a named fine-art context.

ArtPlatformAbility: Protocol every ruleset ability must implement.

Design intent
─────────────
Each tileset changes more than art: it changes the *laws of play*.
Entering a Klimt room means vines become climbable.  Entering an Escher room
will mean gravity is ambiguous.  The ArtRuleset makes this contract explicit
and keeps the engine decoupled from game-specific logic.

Active-ruleset resolution (in _Session):
  active_ruleset = bundle.rulesets.get(state.active_tileset)
  ability        = active_ruleset.ability if active_ruleset else None

Inactive abilities must never render, collide, or receive input.  The engine
enforces this by only calling ability methods when the ruleset owning that
ability is the active one.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any, Protocol, runtime_checkable

if TYPE_CHECKING:
    import pygame
    from engine.entities import PlayerEntity
    from engine.proc_gen import GeneratedLayout
    from engine.state import GameState


# ── Ability interface ─────────────────────────────────────────────────────────

@runtime_checkable
class ArtPlatformAbility(Protocol):
    """
    Platforming ability owned by one ArtRuleset.

    Lifecycle per frame (called by _Session only when owning ruleset is active):
      1. on_room_enter(layout, deco_map)  — called once when entering a room.
      2. update(dt, player, state, layout, jump_pressed)  — physics override.
      3. handle_input(keys, joy_move, jump_pressed, player, layout) — input hook.
      4. render_ability_layer(surface)  — draw climbable affordances / effects.
      5. get_debug_status() → dict     — for overlay display.

    on_ruleset_deactivate() fires when the player switches away from this
    ruleset so the ability can cleanly release any overridden physics state.
    """

    def on_room_enter(
        self,
        layout: "GeneratedLayout",
        deco_map: "dict[tuple[int,int], str]",
    ) -> None:
        """Receive new room data.  Build climbable cell sets, reset state."""
        ...

    def on_ruleset_deactivate(self, player: "PlayerEntity") -> None:
        """Ruleset switched away — release any held physics state immediately."""
        ...

    def update(
        self,
        dt: float,
        player: "PlayerEntity",
        state: "GameState",
        layout: "GeneratedLayout",
        jump_pressed: bool,
    ) -> None:
        """Advance ability state; override physics as needed."""
        ...

    def render_ability_layer(self, surface: "pygame.Surface") -> None:
        """Draw ability-specific affordances (vine highlights, etc.)."""
        ...

    def get_debug_status(self) -> dict[str, Any]:
        """Return dict of debug info for the overlay."""
        ...


# ── ArtRuleset ────────────────────────────────────────────────────────────────

@dataclass
class ArtRuleset:
    """
    Complete rule-set for one fine-art tileset.

    ruleset_id      : matches the tileset_id key (e.g. "klimt_dining").
    display_name    : human-readable name shown in debug overlay.
    ability         : the one platforming ability unlocked by this ruleset,
                      or None for tilesets with no ability yet.
    ability_name    : display name for the ability (shown in HUD / debug).
    env_tags        : arbitrary string tags consumed by environmental logic
                      (e.g. "vine_physics", "gravity_ambiguous").

    Rulesets are constructed once at module load time and referenced by the
    engine throughout the session.  They are stateless data containers; all
    mutable state lives inside the ability instance.
    """
    ruleset_id:   str
    display_name: str
    ability:      "ArtPlatformAbility | None" = None
    ability_name: str = ""
    env_tags:     list[str] = field(default_factory=list)


# ── Convenience stub ──────────────────────────────────────────────────────────

class NullAbility:
    """
    No-op ability used as a typed placeholder.

    Satisfies the ArtPlatformAbility protocol so rulesets can always store
    an ability instance without None checks at every call site.
    """

    def on_room_enter(self, layout, deco_map) -> None:
        pass

    def on_ruleset_deactivate(self, player) -> None:
        pass

    def update(self, dt, player, state, layout, jump_pressed) -> None:
        pass

    def render_ability_layer(self, surface) -> None:
        pass

    def get_debug_status(self) -> dict:
        return {"status": "inactive (null ability)"}
