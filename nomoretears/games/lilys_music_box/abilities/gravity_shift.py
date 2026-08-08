"""
games/lilys_music_box/abilities/gravity_shift.py
-------------------------------------------------
GRAVITY_PLANE_SHIFT — deferred stub for the ESCHER_RELATIVITY ruleset.

TODO: final tileset before bed — implement after all other rulesets are complete.
TODO: requires glitch-art impossible-geometry pass (impossible_floor_ceiling tiles).
TODO: requires gravity-plane traversal logic (4-direction gravity, wall-walking).
TODO: requires side-view anatomical mannequin trail renderer.
TODO: requires impossible-stair environmental logic (looping staircase rooms).

Design notes (for future implementer)
───────────────────────────────────────
GRAVITY_PLANE_SHIFT allows Lily to shift her gravity orientation to one of four
planes (down, up, left, right) when standing on an impossible_floor_ceiling tile
or a gravity_east / gravity_west transition tile.

The shift is not instantaneous — there is a brief "rotation moment" where the
world tilts around the player, then gravity snaps to the new direction.

While in a non-standard gravity plane:
  • The player walks along the new "floor" (previously a wall or ceiling).
  • The jump fires perpendicular to the current gravity plane.
  • The Escher mannequin trail reflects the current gravity orientation.
  • Room exits that require specific gravity are gated by gravity state.

The impossible geometry must be visually consistent:
  • Stair tiles that appear to go both up and down simultaneously.
  • Pillars that are simultaneously floor and ceiling supports.
  • Figures visible at multiple orientations in the trail.

This stub satisfies the ArtPlatformAbility protocol so the architecture compiles.
Replace the pass-through methods with full implementations in the Escher pass.
"""
from __future__ import annotations

from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    import pygame
    from engine.entities import PlayerEntity
    from engine.proc_gen import GeneratedLayout
    from engine.state import GameState


class GravityPlaneShift:
    """
    GRAVITY_PLANE_SHIFT — ESCHER_RELATIVITY ability.

    STUB ONLY.  All methods are no-ops.  Do not add gameplay logic here until
    the full Escher impossible-geometry pass begins.
    """

    def on_room_enter(self, layout: "GeneratedLayout", deco_map: dict) -> None:
        pass   # TODO: scan deco_map for impossible_floor, gravity_east/west tiles

    def on_ruleset_deactivate(self, player: "PlayerEntity") -> None:
        pass   # TODO: snap gravity back to default down-plane

    def update(
        self,
        dt: float,
        player: "PlayerEntity",
        state: "GameState",
        layout: "GeneratedLayout",
        jump_pressed: bool,
    ) -> None:
        pass   # TODO: detect gravity-transition tile contact, trigger plane shift

    def render_ability_layer(self, surface: "pygame.Surface") -> None:
        pass   # TODO: render gravity-plane shift effect (world-rotation overlay)

    def get_debug_status(self) -> dict[str, Any]:
        return {
            "status": "STUB — not implemented",
            "note":   "Escher deferred — implement after all other rulesets",
        }
