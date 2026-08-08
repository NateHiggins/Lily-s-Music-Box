"""
engine/entities.py
------------------
Runtime entity wrappers: PlayerEntity, NPCEntity, ObjectiveEntity.
These are thin view-model objects that combine definition data with mutable
runtime state (near_player, collected, etc.).
"""
from __future__ import annotations

import pygame
from engine.physics import PhysicsBody, PLAYER_W, PLAYER_H
from engine.room_graph import TILE_W, TILE_H, ROOM_COLS, ROOM_ROWS

NPC_INTERACT_RANGE_PX = 100   # pixels — within this distance triggers dialogue (scaled 1.25×)


class PlayerEntity:
    def __init__(self, px: float, py: float) -> None:
        self.body = PhysicsBody(px, py)
        self.facing_right = True

    @property
    def col(self) -> int:
        return self.body.col

    @property
    def row(self) -> int:
        return self.body.row

    def tile_center(self) -> tuple[int, int]:
        return (int(self.body.center_x / TILE_W), int(self.body.center_y / TILE_H))


class NPCEntity:
    def __init__(self, npc_id: str, col: int, row: int) -> None:
        self.npc_id = npc_id
        self.col = col
        self.row = row          # tile row of the NPC's feet
        self.near_player = False

    @property
    def px(self) -> float:
        return self.col * TILE_W

    @property
    def py(self) -> float:
        return (self.row - 1) * TILE_H   # feet at bottom of row

    def update_proximity(self, player: PlayerEntity) -> None:
        dx = abs(player.body.center_x - (self.col * TILE_W + TILE_W / 2))
        dy = abs(player.body.center_y - (self.row * TILE_H))
        self.near_player = (dx * dx + dy * dy) < NPC_INTERACT_RANGE_PX ** 2


class ObjectiveEntity:
    def __init__(self, obj_id: str, col: int, row: int) -> None:
        self.obj_id = obj_id
        self.col = col
        self.row = row
        self.collected = False

    def check_collect(self, player: PlayerEntity) -> bool:
        """Returns True if player just collected this objective."""
        if self.collected:
            return False
        pcol, prow = player.tile_center()
        if abs(pcol - self.col) <= 1 and abs(prow - self.row) <= 1:
            self.collected = True
            return True
        return False
