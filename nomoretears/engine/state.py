"""
engine/state.py
---------------
GameState: runtime mutable state — current room, fatigue, unlocked gates,
NPC solve status, fill density per room.
No pygame imports.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional

from engine.room_graph import GameDefinition


@dataclass
class GameState:
    """
    All mutable runtime state for one play session.

    fill_density_map: room_id -> current fill density.
                      Increases on repeat visits to ease difficulty.
    solved_npcs:      set of npc_ids that have been resolved.
    open_gates:       set of gate_ids currently open.
    attempt_count:    room_id -> how many times player has entered.
    """
    game_def: GameDefinition
    current_room_id: str = ""
    player_col: float = 2.0
    player_row: float = 16.0   # standing on floor
    fatigue_remaining: float = 60.0

    solved_npcs: set[str] = field(default_factory=set)
    open_gates: set[str] = field(default_factory=set)
    fill_density_map: dict[str, float] = field(default_factory=dict)
    attempt_count: dict[str, int] = field(default_factory=dict)
    flags: dict[str, bool] = field(default_factory=dict)
    # Active tileset id — mutated by SetTileset dialogue effect or the cycle key.
    # Persists across room transitions and fatigue resets.
    active_tileset: str = "klimt_dining"
    # All tileset ids the player has unlocked (starts with the default).
    # SetTileset adds to this set; the cycle key only surfaces unlocked entries.
    unlocked_tilesets: set[str] = field(default_factory=set)

    # Cached generated layouts (regenerated when density changes)
    _layout_cache: dict[str, object] = field(default_factory=dict, repr=False)

    def __post_init__(self) -> None:
        if not self.current_room_id:
            self.current_room_id = self.game_def.start_room_id
        self.fatigue_remaining = self.game_def.fatigue_seconds
        # Seed the unlocked set with the starting tileset so it is always cycled.
        self.unlocked_tilesets.add(self.active_tileset)

    def is_gate_open(self, gate_id: Optional[str]) -> bool:
        return gate_id is None or gate_id in self.open_gates

    def solve_npc(self, npc_id: str) -> None:
        self.solved_npcs.add(npc_id)
        npc = self.game_def.get_npc(npc_id)
        if npc and npc.bypass_gate_id:
            self.open_gates.add(npc.bypass_gate_id)

    def is_npc_solved(self, npc_id: str) -> bool:
        return npc_id in self.solved_npcs

    def get_fill_density(self, room_id: str) -> float:
        """Return current fill density for a room (increases with repeat visits)."""
        return self.fill_density_map.get(room_id, 0.5)

    def record_room_entry(self, room_id: str) -> None:
        """Called each time the player enters a room — raises fill density slightly."""
        count = self.attempt_count.get(room_id, 0) + 1
        self.attempt_count[room_id] = count
        # Each visit adds ~5% fill, capped at 0.95
        current = self.fill_density_map.get(room_id, 0.5)
        self.fill_density_map[room_id] = min(0.95, current + 0.05)
        # Invalidate layout cache so it regenerates with new density
        self._layout_cache.pop(room_id, None)

    def reset_fatigue(self) -> None:
        self.fatigue_remaining = self.game_def.fatigue_seconds

    def tick_fatigue(self, dt: float) -> bool:
        """Reduce fatigue; returns True if fatigue just hit zero."""
        if self.fatigue_remaining <= 0:
            return False
        self.fatigue_remaining -= dt
        if self.fatigue_remaining <= 0:
            self.fatigue_remaining = 0
            return True
        return False
