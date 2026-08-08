"""
games/lilys_music_box
----------------------
Lily's Music Box — first game module for the NoMoreTears platform engine.

Contract: expose TITLE (str) and load() -> GameBundle.
"""

TITLE = "LILY'S MUSIC BOX"

from pathlib import Path

from engine.bundle import GameBundle
from engine.ruleset import ArtRuleset
from games.lilys_music_box.layout import build_game_definition
from games.lilys_music_box.theme import LILY_THEME
from games.lilys_music_box.behaviors import DIALOGUE_TREES
from games.lilys_music_box.art import LilyArtProvider
from games.lilys_music_box.tilesets import (
    ImageTilesetProvider,
    KlimtTilesetProvider,
    GuardianGothicTilesetProvider,
)
from games.lilys_music_box.styles.escher import EscherVisualEffect
from games.lilys_music_box.styles.klimt import KlimtGoldLeafFlow
from games.lilys_music_box.styles.fragonard import FragonardGardenFlow
from games.lilys_music_box.abilities.vine_climb import VineAnchorClimb
from games.lilys_music_box.abilities.gravity_shift import GravityPlaneShift
from games.lilys_music_box.abilities.swing_ascend import SwingAscendAbility

_TILESETS_DIR  = Path(__file__).parent / "assets" / "tilesets"
_KLIMT_DIR     = Path(__file__).parent / "klimtTile"
_MUSIC_DIR     = Path(__file__).parent / "music"

_TILESET_IDS = [
    "escher_foyer",
    "guardian_gothic",
    "lily_bedroom",
]


def load(dev_mode: bool = False) -> GameBundle:
    lily_art = LilyArtProvider()

    # Build the guardian_gothic provider first — SwingAscendAbility holds a
    # reference to it so it can call _anchor_cells after each air_layout().
    guardian_provider = GuardianGothicTilesetProvider(
        _TILESETS_DIR / "guardian_gothic", lily_art
    )
    swing_ability  = SwingAscendAbility(guardian_provider)
    fragonard_style = FragonardGardenFlow(swing_ability)

    tilesets = {
        tid: ImageTilesetProvider(tid, _TILESETS_DIR / tid, lily_art)
        for tid in _TILESET_IDS
    }
    klimt_provider = KlimtTilesetProvider(_KLIMT_DIR, lily_art)
    tilesets["klimt_dining"]    = klimt_provider
    tilesets["guardian_gothic"] = guardian_provider

    rulesets = {
        "klimt_dining": ArtRuleset(
            ruleset_id="klimt_dining",
            display_name="Klimt — Tree of Life",
            ability=VineAnchorClimb(klimt_provider),
            ability_name="VINE_ANCHOR_CLIMB",
            env_tags=["vine_physics"],
        ),
        "escher_foyer": ArtRuleset(
            ruleset_id="escher_foyer",
            display_name="Escher — Relativity",
            ability=GravityPlaneShift(),
            ability_name="GRAVITY_PLANE_SHIFT",
            env_tags=["gravity_ambiguous"],
        ),
        "guardian_gothic": ArtRuleset(
            ruleset_id="guardian_gothic",
            display_name="Fragonard — The Swing",
            ability=swing_ability,
            ability_name="SWING_ASCEND",
            env_tags=["hidden_garden", "swing_physics"],
        ),
    }
    return GameBundle(
        definition=build_game_definition(),
        theme=LILY_THEME,
        dialogue_trees=DIALOGUE_TREES,
        art=lily_art,
        tilesets=tilesets,
        rulesets=rulesets,
        # Cycle order matches NPC unlock chain: Klimt → Guardian → Escher → bedroom.
        # Only klimt_dining is unlocked at start (it's the active_tileset default).
        # SetTileset effects add each subsequent tileset to state.unlocked_tilesets
        # as NPCs are solved, so the cycle key only surfaces what the player has earned.
        # "fallback" is a special sentinel — maps to bundle.art (LilyArtProvider).
        tileset_cycle=[
            "klimt_dining",
            "guardian_gothic",
            "escher_foyer",
            "lily_bedroom",
            "fallback",
        ],
        tileset_display_names={
            "escher_foyer":    "Escher Foyer",
            "klimt_dining":    "Klimt Dining",
            "guardian_gothic": "Guardian Gothic",
            "lily_bedroom":    "Lily's Bedroom",
            "fallback":        "Dream Art",
        },
        room_styles={
            "escher_foyer":    EscherVisualEffect(),
            "klimt_dining":    KlimtGoldLeafFlow(),
            "guardian_gothic": fragonard_style,
        },
        tileset_music={
            # Tracks are .mp4 containers — pygame-ce on Windows reads the audio
            # stream via SDL_mixer; degrade silently if the codec is unavailable.
            "escher_foyer":    str(_MUSIC_DIR / "Recursive_Ascent.ogg"),
            "klimt_dining":    str(_MUSIC_DIR / "Amber_Canopy_Waltz.ogg"),
            # guardian_gothic tileset is themed on Fragonard's "The Swing"
            "guardian_gothic": str(_MUSIC_DIR / "Petals_on_the_Fountain.ogg"),
        },
        dev_mode=dev_mode,
    )
