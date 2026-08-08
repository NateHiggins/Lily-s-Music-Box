"""
games/lilys_music_box/theme.py
-------------------------------
ThemeDefinition for Lily's Music Box.
Palette: dream-gallery / music-box world — warm ambers, dusty purples, soft golds.
"""
from engine.theme import (
    ThemeDefinition, TilePalette, UpdraftVisual, NPCVisual,
    PlayerVisual, ObjectiveVisual, HUDStyle,
)

LILY_THEME = ThemeDefinition(
    theme_id="lilys_music_box",
    display_name="Lily's Music Box",
    tiles=TilePalette(
        floor_top      = (160, 130, 90),    # warm oak planks
        floor_body     = (100, 78, 55),
        platform_top   = (140, 110, 160),   # dusty lavender platforms
        platform_body  = (90, 68, 110),
        ghost_fill     = (180, 160, 200, 45),
        ghost_border   = (200, 180, 230, 100),
        background     = (18, 14, 28),      # deep dreaming dark
        wall           = (40, 35, 55),
    ),
    updraft=UpdraftVisual(
        color_bottom   = (220, 190, 255, 90),   # pale violet shimmer
        color_top      = (200, 180, 255, 0),
        particle_color = (230, 215, 255),
        width_tiles    = 2,
    ),
    npc=NPCVisual(
        body_color     = (200, 160, 100),   # warm amber NPC
        accent_color   = (255, 220, 140),
        width          = 23,
        height         = 40,
    ),
    player=PlayerVisual(
        body_color     = (160, 120, 200),   # soft purple — Lily
        accent_color   = (220, 190, 255),
        width          = 20,
        height         = 28,
    ),
    objective=ObjectiveVisual(
        color          = (255, 230, 100),   # golden music note / star
        glow_color     = (255, 230, 100, 90),
        size           = 18,
    ),
    hud=HUDStyle(
        fatigue_full   = (130, 210, 160),   # soft green — "well rested"
        fatigue_low    = (220, 90, 90),     # red — "about to wake"
        text_color     = (230, 220, 200),
        font_size      = 20,
        bg_color       = (0, 0, 0, 150),
    ),
    show_ghost_platforms=True,
)
