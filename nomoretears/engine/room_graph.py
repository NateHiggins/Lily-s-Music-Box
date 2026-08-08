"""
engine/room_graph.py
--------------------
Core data model: GameDefinition, RoomGraph, Room, Exit, NPC, Objective, Branch.
No pygame imports — pure data / logic.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional


# ── Constants ─────────────────────────────────────────────────────────────────

TILE_W    = 40
TILE_H    = 40
ROOM_COLS = 32   # 1280 px wide
ROOM_ROWS = 18   # 720 px tall
TILE_SCALE = TILE_W / 32   # 1.25 — multiply legacy 32-px values by this


# ── Eligibility layer ─────────────────────────────────────────────────────────

@dataclass
class EligibilityLayer:
    """
    Marks which tile positions in a room *may* host platforms.
    The procedural generator fills a subset of these based on fill_density.

    eligible: set of (col, row) pairs where platforms are allowed.
    updraft_col: column where the updraft zone sits (None = no updraft).
    updraft_row_top: top row of updraft (smaller row index = higher on screen).
    updraft_row_bottom: bottom row of updraft.
    """
    eligible: set[tuple[int, int]] = field(default_factory=set)
    updraft_col: Optional[int] = None
    updraft_row_top: int = 2
    updraft_row_bottom: int = 17


@dataclass
class PlatformLayerDef:
    """
    Fully describes how a room's platforms are generated.
    seed + fill_density → deterministic layout.
    """
    eligibility: EligibilityLayer
    seed: int = 0
    fill_density: float = 0.5  # 0.0 = sparse/hard, 1.0 = all eligible filled/easy
    # Minimum required fill: generator will not go below this fraction.
    min_fill: float = 0.25


# ── Exit / route definitions ──────────────────────────────────────────────────

@dataclass
class ExitDef:
    """One directional connection leaving a room."""
    to_room: str
    direction: str          # "west" | "east" | "upper_west" | "upper_east" | "north" | "south"
    route_kind: str = "ground"   # "ground" | "platform" | "bypass"
    gate_id: Optional[str] = None  # None = always open
    # Tile position of the trigger hitbox (col, row).  None = auto from direction.
    trigger_col: Optional[int] = None
    trigger_row: Optional[int] = None


# ── NPC / Objective ───────────────────────────────────────────────────────────

@dataclass
class ObjectiveDef:
    """What must be done to solve an NPC's problem."""
    room_id: str             # which room holds the objective tile
    col: int                 # tile column of the objective
    row: int                 # tile row of the objective
    prompt: str = "Reach this point"


@dataclass
class NPCDef:
    """
    An NPC in a specific room with a problem.
    Dialogue content lives in the module's DialogueTree (keyed by npc_id).
    Solving their objective (if any) or completing their dialogue unlocks bypass_gate_id.
    objective is optional — NPCs that resolve purely through dialogue leave it None.
    """
    npc_id: str
    room_id: str
    col: int
    row: int                 # tile row (NPC stands on this row's floor)
    objective: Optional[ObjectiveDef] = None
    bypass_gate_id: Optional[str] = None  # gate opened when solved


# ── Branch / Floor ────────────────────────────────────────────────────────────

@dataclass
class BranchDef:
    """
    A group of rooms belonging to one NPC's puzzle arc.
    rooms = ordered list of room_ids in the branch.
    """
    branch_id: str
    npc_id: str
    rooms: list[str]


@dataclass
class FloorDef:
    """One 'floor' of the castle: one or more NPC branches."""
    floor_id: str
    branches: list[BranchDef]


# ── Room ──────────────────────────────────────────────────────────────────────

@dataclass
class RoomDef:
    """Complete description of one room."""
    room_id: str
    display_name: str
    exits: list[ExitDef] = field(default_factory=list)
    platform_layer: Optional[PlatformLayerDef] = None
    branch_id: Optional[str] = None
    # Ambient theme override — None = use game default
    biome: str = "default"


# ── Game definition ───────────────────────────────────────────────────────────

@dataclass
class RoomGraph:
    rooms: dict[str, RoomDef] = field(default_factory=dict)

    def get(self, room_id: str) -> Optional[RoomDef]:
        return self.rooms.get(room_id)

    def exits_from(self, room_id: str) -> list[ExitDef]:
        room = self.get(room_id)
        return room.exits if room else []


@dataclass
class GameDefinition:
    """
    Complete definition of one short-form platform adventure game.
    Engine code is generic; all game content lives here.
    """
    game_id: str
    display_title: str
    start_room_id: str
    win_room_id: str
    fatigue_seconds: float
    graph: RoomGraph
    npcs: list[NPCDef] = field(default_factory=list)
    floors: list[FloorDef] = field(default_factory=list)

    def get_npc(self, npc_id: str) -> Optional[NPCDef]:
        for n in self.npcs:
            if n.npc_id == npc_id:
                return n
        return None

    def npcs_in_room(self, room_id: str) -> list[NPCDef]:
        return [n for n in self.npcs if n.room_id == room_id]
