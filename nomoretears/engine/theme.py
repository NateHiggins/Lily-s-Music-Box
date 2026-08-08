"""
engine/theme.py
---------------
ThemeDefinition: palette, tile colors, updraft visuals, NPC style.
Themes are pure data — no pygame surfaces stored here.
The renderer reads the theme and produces surfaces on demand.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Tuple

Color = Tuple[int, int, int]
ColorA = Tuple[int, int, int, int]


@dataclass
class TilePalette:
    floor_top: Color          = (120, 100, 80)
    floor_body: Color         = (80, 65, 55)
    platform_top: Color       = (140, 120, 100)
    platform_body: Color      = (100, 85, 70)
    ghost_fill: ColorA        = (180, 160, 140, 60)   # rgba — partially transparent
    ghost_border: ColorA      = (200, 180, 160, 120)
    background: Color         = (20, 18, 30)
    wall: Color               = (50, 45, 60)


@dataclass
class UpdraftVisual:
    color_bottom: ColorA      = (100, 180, 255, 80)
    color_top: ColorA         = (180, 220, 255, 0)
    particle_color: Color     = (200, 230, 255)
    width_tiles: int          = 2


@dataclass
class NPCVisual:
    body_color: Color         = (220, 180, 120)
    accent_color: Color       = (255, 220, 100)
    width: int                = 18
    height: int               = 32


@dataclass
class PlayerVisual:
    body_color: Color         = (180, 140, 200)
    accent_color: Color       = (220, 180, 255)
    width: int                = 20
    height: int               = 28


@dataclass
class ObjectiveVisual:
    color: Color              = (255, 240, 100)
    glow_color: ColorA        = (255, 240, 100, 80)
    size: int                 = 16


@dataclass
class HUDStyle:
    fatigue_full: Color       = (100, 220, 150)
    fatigue_low: Color        = (220, 80, 80)
    text_color: Color         = (240, 230, 210)
    font_size: int            = 16
    bg_color: ColorA          = (0, 0, 0, 140)


@dataclass
class ThemeDefinition:
    theme_id: str
    display_name: str
    tiles: TilePalette        = field(default_factory=TilePalette)
    updraft: UpdraftVisual    = field(default_factory=UpdraftVisual)
    npc: NPCVisual            = field(default_factory=NPCVisual)
    player: PlayerVisual      = field(default_factory=PlayerVisual)
    objective: ObjectiveVisual = field(default_factory=ObjectiveVisual)
    hud: HUDStyle             = field(default_factory=HUDStyle)
    show_ghost_platforms: bool = True
