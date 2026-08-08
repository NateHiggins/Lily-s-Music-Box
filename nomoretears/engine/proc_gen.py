"""
engine/proc_gen.py
------------------
Procedural platform layout generation from an eligibility layer.

Key concepts:
- EligibilityLayer marks which tiles *could* hold platforms.
- fill_density [0,1] controls what fraction of eligible tiles are filled.
- The generator guarantees at least one valid route from left exits to right
  exits by always placing a floor-level path and then adding elevated platforms
  from the eligible set.
- Deterministic given (seed, fill_density).
- No pygame import — pure data.
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Optional

from engine.room_graph import EligibilityLayer, ROOM_COLS, ROOM_ROWS


# ── Output ────────────────────────────────────────────────────────────────────

@dataclass
class GeneratedLayout:
    """
    Result of one generation pass.

    solid_tiles: set of (col, row) — filled solid platform tiles.
    ghost_tiles: set of (col, row) — eligible but unfilled tiles (visible as ghost).
    updraft: (col, row_top, row_bottom) or None.
    seed: seed used.
    fill_density: actual density used.
    """
    solid_tiles: set[tuple[int, int]]
    ghost_tiles: set[tuple[int, int]]
    updraft: Optional[tuple[int, int, int]]
    seed: int
    fill_density: float

    def is_solid(self, col: int, row: int) -> bool:
        return (col, row) in self.solid_tiles

    def is_ghost(self, col: int, row: int) -> bool:
        return (col, row) in self.ghost_tiles


# ── Generator ─────────────────────────────────────────────────────────────────

def generate_layout(
    eligibility: EligibilityLayer,
    seed: int = 0,
    fill_density: float = 0.5,
    min_fill: float = 0.25,
) -> GeneratedLayout:
    """
    Generate a platform layout from an eligibility layer.

    Eligible tiles above the floor row are filled with probability fill_density.
    Unfilled eligible tiles become ghost/phantom tiles (visible hint, not solid).
    The floor row is always solid.

    Route guarantee: floor-level traversal is always available (floor is solid).
    Elevated platform paths depend on fill_density — higher = more filled = easier.
    """
    rng = random.Random(seed)
    floor_row = ROOM_ROWS - 3  # row 17 = solid floor top

    solid: set[tuple[int, int]] = set()
    ghost: set[tuple[int, int]] = set()

    # Always fill the floor row fully
    for col in range(ROOM_COLS):
        solid.add((col, floor_row))
        solid.add((col, floor_row + 1))  # sub-floor solid
        solid.add((col, floor_row + 2))  # bottom solid

    # Clamp density
    density = max(min_fill, min(1.0, fill_density))

    # Process elevated eligible tiles
    elevated = [(c, r) for (c, r) in eligibility.eligible if r < floor_row]

    # Shuffle deterministically, then fill based on density
    rng.shuffle(elevated)
    fill_count = max(
        int(len(elevated) * min_fill),
        int(len(elevated) * density),
    )

    filled = set(elevated[:fill_count])
    unfilled = set(elevated[fill_count:])

    # For each filled tile, also fill the tile below it to make a solid block
    for (c, r) in list(filled):
        solid.add((c, r))
        if r + 1 < ROOM_ROWS:
            solid.add((c, r + 1))

    ghost = unfilled

    # Updraft
    updraft = None
    if eligibility.updraft_col is not None:
        updraft = (
            eligibility.updraft_col,
            eligibility.updraft_row_top,
            eligibility.updraft_row_bottom,
        )

    return GeneratedLayout(
        solid_tiles=solid,
        ghost_tiles=ghost,
        updraft=updraft,
        seed=seed,
        fill_density=density,
    )


# ── Route validator ───────────────────────────────────────────────────────────

@dataclass
class RouteValidationResult:
    valid: bool
    reachable_exits: list[str]
    unreachable_exits: list[str]
    message: str


def validate_routes(
    layout: GeneratedLayout,
    exits: list[dict],  # [{"direction": "east", "col": 29, "row": 17}, ...]
    player_jump_height: int = 4,   # tiles upward a player can jump
    player_jump_reach: int = 5,    # tiles horizontal reach per jump
) -> RouteValidationResult:
    """
    BFS from the leftmost floor tile to check that all exit tiles are reachable.
    Considers solid tiles as walkable tops and jump/fall physics.

    This is a simplified reachability check — not exact physics simulation.
    It treats any tile where the tile below is solid (and the tile itself is
    empty) as a walkable position.
    """
    solid = layout.solid_tiles
    floor_row = ROOM_ROWS - 3

    def walkable_positions() -> set[tuple[int, int]]:
        """All (col, row) where player can stand: tile below is solid, tile itself empty."""
        positions: set[tuple[int, int]] = set()
        for (c, r) in solid:
            above = (c, r - 1)
            if above not in solid and 0 <= r - 1 < ROOM_ROWS:
                positions.add(above)
        return positions

    walkable = walkable_positions()
    if not walkable:
        return RouteValidationResult(False, [], [e["direction"] for e in exits],
                                     "No walkable positions found")

    # BFS from any floor-level start position
    start_positions = [(c, r) for (c, r) in walkable if r == floor_row - 1]
    if not start_positions:
        start_positions = [min(walkable, key=lambda p: (p[1], p[0]))]

    visited: set[tuple[int, int]] = set()
    queue = list(start_positions)
    for s in start_positions:
        visited.add(s)

    def neighbors(c: int, r: int) -> list[tuple[int, int]]:
        result = []
        # Walk left/right
        for dc in [-1, 1]:
            nc = c + dc
            if (nc, r) in walkable:
                result.append((nc, r))
        # Fall: if nothing below walkable, fall down
        for dr in range(1, ROOM_ROWS - r):
            candidate = (c, r + dr)
            if candidate in walkable:
                result.append(candidate)
                break
            if (c, r + dr) in solid:
                break
        # Jump: upward + horizontal
        for dc in range(-player_jump_reach, player_jump_reach + 1):
            for dr in range(1, player_jump_height + 1):
                candidate = (c + dc, r - dr)
                if candidate in walkable:
                    result.append(candidate)
        return result

    while queue:
        c, r = queue.pop(0)
        for nc, nr in neighbors(c, r):
            if (nc, nr) not in visited and (nc, nr) in walkable:
                visited.add((nc, nr))
                queue.append((nc, nr))

    # Check each exit
    reachable = []
    unreachable = []
    for ex in exits:
        ecol, erow = ex.get("col", 0), ex.get("row", floor_row - 1)
        # Check if any tile near the exit trigger is reachable
        found = any(
            (ecol + dc, erow + dr) in visited
            for dc in range(-2, 3)
            for dr in range(-1, 2)
        )
        if found:
            reachable.append(ex["direction"])
        else:
            unreachable.append(ex["direction"])

    valid = len(unreachable) == 0
    msg = "All exits reachable" if valid else f"Unreachable exits: {unreachable}"
    return RouteValidationResult(valid, reachable, unreachable, msg)
