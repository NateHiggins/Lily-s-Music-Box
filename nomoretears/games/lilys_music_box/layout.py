"""
games/lilys_music_box/layout.py
--------------------------------
Static world layout: rooms, exits, gates, NPCs.
No dialogue content — that lives in behaviors.py.

World map:

  [foyer] ──west ground (open)──────────────────> [mud_passage]    intro platforming
  [mud_passage] ──upper_west──────────────────────> [slime_lair]    Slime Maiden (top)
  [foyer] ──east trigger(26,11) [slime_gate]──────> [antechamber_1] puzzle room 1
  [antechamber_1] ──upper_east──────────────────────> [antechamber_2] puzzle room 2
  [antechamber_2] ──upper_east──────────────────────> [guardian_hall] Guardian
  [foyer] ──west trigger( 3, 7) [guardian_gate]──> [cherry_bower]  Cherry
  [foyer] ──east trigger(26, 3) [cherry_gate]────> [bed_room]       WIN

NPC chain:
  Talk to Slime Maiden → slime_gate opens → exit 2 (foyer tier B)
  Talk to Guardian     → guardian_gate opens → exit 3 (foyer tier C)
  Talk to Cherry       → cherry_gate opens → exit 4 (foyer tier D)

Platforming difficulty gradient (solution path):

  mud_passage — EASIEST:
    3 wide platforms step-left from floor to row 10.
    All gaps ≤ 2 rows (64 px). Exit is the left wall once elevated.

  slime_lair  — VINE MECHANIC:
    3 easy staircase platforms funnel the player left to row 10 col 10,
    where the vine trunk from Slime Maiden's platform (row 5) hangs above.
    Jump + grab vine → climb to row 5.  No updraft; vine is the solution.

  guardian_hall, cherry_bower — progressively harder, designed separately.

Trigger exits in the foyer are listed BEFORE directional exits so they
are matched first in the engine's sequential exit-check loop.
"""
from engine.room_graph import (
    GameDefinition, RoomGraph, RoomDef, ExitDef,
    EligibilityLayer, PlatformLayerDef,
    NPCDef, BranchDef, FloorDef,
)


# ── Eligibility layers ────────────────────────────────────────────────────────

def _foyer_eligibility() -> EligibilityLayer:
    """
    Four platform tiers of increasing height and decreasing density.
    Updraft at col 15 helps the player reach tiers C and D.
    """
    eligible: set[tuple[int, int]] = set()

    # Tier A (row 14) — two rows above floor; trivial first jump
    for col in [4, 5, 6,   13, 14, 15,   22, 23, 24]:
        eligible.add((col, 14))

    # Tier B (row 11) — three more rows up; exit 2 trigger at (26, 11) right side
    for col in range(3, 8):    # left cluster
        eligible.add((col, 11))
    for col in range(12, 17):  # center cluster
        eligible.add((col, 11))
    for col in range(21, 27):  # right cluster — reaches col 26 for exit 2
        eligible.add((col, 11))

    # Tier C (row 7) — four more rows up; exit 3 trigger at (3, 7) left side
    for col in range(3, 9):    # left cluster — touches col 3 for exit 3
        eligible.add((col, 7))
    for col in range(12, 16):  # center cluster
        eligible.add((col, 7))
    for col in range(21, 25):  # right cluster
        eligible.add((col, 7))

    # Tier D (row 3) — four more rows up; exit 4 trigger at (26, 3) right side
    for col in range(4, 7):    # left cluster
        eligible.add((col, 3))
    for col in range(13, 16):  # center cluster
        eligible.add((col, 3))
    for col in range(21, 27):  # right cluster — reaches col 26 for exit 4
        eligible.add((col, 3))

    return EligibilityLayer(
        eligible=eligible,
        updraft_col=15,
        updraft_row_top=2,
        updraft_row_bottom=15,
    )


def _mud_passage_eligibility() -> EligibilityLayer:
    """
    Easiest standalone room.  Three wide platforms staircase left from the
    east-side spawn toward the upper-left exit.  All vertical gaps are ≤ 2
    rows so any jump clears them comfortably.  No updraft — none needed.

    Layout (floor is row 17, screen is rows 0-19):
      Row 14 cols 20-26  — first hop from floor, right side (7 tiles wide)
      Row 12 cols 12-18  — second hop, center                (7 tiles wide)
      Row 10 cols  4-10  — third hop, left side              (7 tiles wide)
    Player walks off the left wall at this height to exit into slime_lair.
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(20, 27):   # right step
        eligible.add((col, 14))
    for col in range(12, 19):   # center step
        eligible.add((col, 12))
    for col in range(4, 11):    # left step — player exits from here
        eligible.add((col, 10))
    return EligibilityLayer(eligible=eligible)


def _slime_lair_eligibility() -> EligibilityLayer:
    """
    Vine-first room — designed around VineAnchorClimb (Klimt skin ability).

    The _klimt_air_layout drops a tree_trunk from Slime Maiden's platform
    (row 5, centre col 10) through rows 6-9 at col 10.  The platform directly
    below (row 10, cols 7-13) puts the player in range to jump and grab that
    vine, then climb the remaining 5 rows to her level.  No horizontal
    skill-check jump is required — the vine does the vertical work.

    The first three platforms are a comfortable leftward staircase with 2-row
    rises and 1-col gaps (easily jumpable) that funnels the player to col 10
    at row 10, where the vine grab is obvious.

    Layout (entry from east, player drops onto row 14 right platform):
      Row 14  cols 22-27  — right entry   (6 tiles)
      Row 12  cols 14-20  — centre        (7 tiles, 2-row rise, 1-col gap)
      Row 10  cols  7-13  — left          (7 tiles, 2-row rise, 1-col gap;
                                           vine trunk at col 10 hangs through
                                           rows 6-9 directly above here)
      Row  5  cols  7-14  — top           (8 tiles, Slime Maiden at col 10;
                                           4-row gap forces vine use to ascend)
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(22, 28):   # hop 1 — right entry
        eligible.add((col, 14))
    for col in range(14, 21):   # hop 2 — centre
        eligible.add((col, 12))
    for col in range(7, 14):    # hop 3 — left (vine trunk above at col 10)
        eligible.add((col, 10))
    for col in range(7, 15):    # top — Slime Maiden's platform (vine required)
        eligible.add((col, 5))
    return EligibilityLayer(eligible=eligible)


def _antechamber_1_eligibility() -> EligibilityLayer:
    """
    Moderate west-to-east staircase — four platforms with 2-tile horizontal gaps
    and 2-row height gains.  All jumps are comfortable (≤80 px vertical).
    Exit is upper_east at row 7, reachable from the rightmost platform.

    Layout:
      Row 13  cols  4-10  — first platform from west spawn  (7 tiles)
      Row 11  cols 12-18  — second platform, gap 2, rise 2  (7 tiles)
      Row  9  cols 19-24  — third platform,  gap 1, rise 2  (6 tiles)
      Row  7  cols 25-30  — fourth platform, gap 1, rise 2  (6 tiles) → upper_east exit
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(4, 11):    eligible.add((col, 13))
    for col in range(12, 19):   eligible.add((col, 11))
    for col in range(19, 25):   eligible.add((col,  9))
    for col in range(25, 31):   eligible.add((col,  7))
    return EligibilityLayer(eligible=eligible)


def _antechamber_2_eligibility() -> EligibilityLayer:
    """
    Hard west-to-east staircase — five platforms.  The first gap is 3 tiles wide
    (cols 9-10 empty) which forces a running edge-of-platform jump.  Later gaps
    are tighter in width but the platforms are narrower, demanding precise landings.
    Exit is upper_east at row 5 (py ≈ 165 px, well inside the upper_east threshold).

    Layout:
      Row 13  cols  3- 8  — first platform, wide launch pad     (6 tiles)
      Row 11  cols 11-15  — second platform, gap 3 (skill check) (5 tiles)
      Row  9  cols 16-20  — third platform,  gap 1, rise 2       (5 tiles)
      Row  7  cols 21-24  — fourth platform, gap 1, rise 2       (4 tiles — narrow)
      Row  5  cols 25-30  — fifth platform,  gap 1, rise 2       (6 tiles) → upper_east exit
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(3, 9):     eligible.add((col, 13))
    for col in range(11, 16):   eligible.add((col, 11))
    for col in range(16, 21):   eligible.add((col,  9))
    for col in range(21, 25):   eligible.add((col,  7))
    for col in range(25, 31):   eligible.add((col,  5))
    return EligibilityLayer(eligible=eligible)


# ── Cherry path rooms (east → west, moderate) ────────────────────────────────
# Player enters from east (right side), staircases left to upper_west exit.
# upper_west fires when px ≤ 55 AND py < 440 — leftmost platform touches col 0.
# Rows always spaced 2 apart so proc_gen's +1-below fill never merges adjacent tiers.

def _gallery_a_eligibility() -> EligibilityLayer:
    """
    Moderate east-to-west, 3 platforms.  All gaps are 2 tiles (80 px) with a
    2-row (80 px) height gain each step — comfortable running jumps.

    Layout (right spawn → left exit):
      Row 13  cols 22-31  — spawn tier, wide and accessible from floor   (10 tiles)
      Row 11  cols 11-19  — middle tier, gap 2 to the right               ( 9 tiles)
      Row  9  cols  0- 8  — exit tier, gap 2, touches left wall           ( 9 tiles)
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(22, 32):   eligible.add((col, 13))
    for col in range(11, 20):   eligible.add((col, 11))
    for col in range(0,  9):    eligible.add((col,  9))
    return EligibilityLayer(eligible=eligible)


def _gallery_b_eligibility() -> EligibilityLayer:
    """
    Moderate-plus east-to-west, 4 platforms.  2-tile gaps throughout but
    platforms narrow as they climb — demands more precise landings.

    Layout:
      Row 13  cols 28-31  — spawn tier (4 tiles, narrow)
      Row 11  cols 19-25  — second tier, gap 2                            (7 tiles)
      Row  9  cols  9-16  — third tier, gap 2                             (8 tiles)
      Row  7  cols  0- 6  — exit tier, gap 2, left wall                   (7 tiles)
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(28, 32):   eligible.add((col, 13))
    for col in range(19, 26):   eligible.add((col, 11))
    for col in range(9,  17):   eligible.add((col,  9))
    for col in range(0,  7):    eligible.add((col,  7))
    return EligibilityLayer(eligible=eligible)


def _gallery_c_eligibility() -> EligibilityLayer:
    """
    Moderate-hard east-to-west, 4 platforms.  First gap from the exit tier to
    the next is 3 tiles (120 px) — the single skill-check jump requiring a
    running edge launch at 80 px rise.  Later gaps ease back to 2 tiles.

    Layout:
      Row 13  cols 25-31  — spawn tier                                    (7 tiles)
      Row 11  cols 17-22  — second tier, gap 2                            (6 tiles)
      Row  9  cols  9-14  — third tier, gap 2                             (6 tiles)
      Row  7  cols  0- 5  — exit tier, gap 3 (SKILL CHECK), left wall     (6 tiles)
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(25, 32):   eligible.add((col, 13))
    for col in range(17, 23):   eligible.add((col, 11))
    for col in range(9,  15):   eligible.add((col,  9))
    for col in range(0,  6):    eligible.add((col,  7))
    return EligibilityLayer(eligible=eligible)


# ── Bed-path rooms (west → east, hardest) ─────────────────────────────────────
# Player enters from west (left side), staircases right to upper_east exit.
# upper_east fires when px ≥ 1160 AND py < 440.
# Col 29 (px=1160) is the minimum; all exit platforms include cols 29-31.
# 3-tile horizontal gaps (120 px) at 80 px rise test exact jump-height limits.

def _spire_a_eligibility() -> EligibilityLayer:
    """
    Hard west-to-east, 4 platforms.  First gap is 3 tiles (skill check);
    remaining gaps are 2 tiles.  Platforms are 5-6 tiles wide.

    Layout:
      Row 13  cols  2- 7  — spawn tier                                    (6 tiles)
      Row 11  cols 11-15  — second tier, gap 3 (SKILL CHECK)              (5 tiles)
      Row  9  cols 18-22  — third tier, gap 2                             (5 tiles)
      Row  7  cols 25-29  — exit tier, gap 2, upper_east (col 29, py 245) (5 tiles)
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(2,  8):    eligible.add((col, 13))
    for col in range(11, 16):   eligible.add((col, 11))
    for col in range(18, 23):   eligible.add((col,  9))
    for col in range(25, 30):   eligible.add((col,  7))
    return EligibilityLayer(eligible=eligible)


def _spire_b_eligibility() -> EligibilityLayer:
    """
    Very hard west-to-east, 4 platforms.  Two consecutive 3-tile gaps demand
    back-to-back edge-of-platform launches with no rest between.

    Layout:
      Row 13  cols  2- 6  — spawn tier                                    (5 tiles)
      Row 11  cols 10-14  — second tier, gap 3 (SKILL CHECK)              (5 tiles)
      Row  9  cols 18-22  — third tier, gap 3 (SKILL CHECK)               (5 tiles)
      Row  7  cols 25-29  — exit tier, gap 2, upper_east                  (5 tiles)
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(2,  7):    eligible.add((col, 13))
    for col in range(10, 15):   eligible.add((col, 11))
    for col in range(18, 23):   eligible.add((col,  9))
    for col in range(25, 30):   eligible.add((col,  7))
    return EligibilityLayer(eligible=eligible)


def _spire_c_eligibility() -> EligibilityLayer:
    """
    Extreme west-to-east, 5 platforms.  Three consecutive 3-tile gaps on
    progressively narrowing platforms.  Exit tier is at row 5 (py 165).

    Layout:
      Row 13  cols  2- 6  — spawn tier                                    (5 tiles)
      Row 11  cols 10-13  — second tier, gap 3, narrow                    (4 tiles)
      Row  9  cols 17-20  — third tier, gap 3, narrow                     (4 tiles)
      Row  7  cols 24-27  — fourth tier, gap 3, narrow                    (4 tiles)
      Row  5  cols 29-31  — exit tier, gap 1, upper_east (py 165)         (3 tiles)
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(2,  7):    eligible.add((col, 13))
    for col in range(10, 14):   eligible.add((col, 11))
    for col in range(17, 21):   eligible.add((col,  9))
    for col in range(24, 28):   eligible.add((col,  7))
    for col in range(29, 32):   eligible.add((col,  5))
    return EligibilityLayer(eligible=eligible)


def _spire_d_eligibility() -> EligibilityLayer:
    """
    Brutal west-to-east, 5 platforms.  Four consecutive 3-tile gaps on very
    narrow platforms (3-4 tiles) from start to finish — every single jump
    is a near-max-range edge launch.  Exit tier at row 5 (py 165).

    Layout:
      Row 13  cols  1- 4  — spawn tier, very narrow                       (4 tiles)
      Row 11  cols  8-11  — second tier, gap 3                            (4 tiles)
      Row  9  cols 15-18  — third tier, gap 3                             (4 tiles)
      Row  7  cols 22-25  — fourth tier, gap 3                            (4 tiles)
      Row  5  cols 29-31  — exit tier, gap 3, upper_east (py 165)         (3 tiles)
    """
    eligible: set[tuple[int, int]] = set()
    for col in range(1,  5):    eligible.add((col, 13))
    for col in range(8,  12):   eligible.add((col, 11))
    for col in range(15, 19):   eligible.add((col,  9))
    for col in range(22, 26):   eligible.add((col,  7))
    for col in range(29, 32):   eligible.add((col,  5))
    return EligibilityLayer(eligible=eligible)


def _guardian_hall_eligibility() -> EligibilityLayer:
    """Scattered platforms giving the hall a verticality without being punishing."""
    eligible: set[tuple[int, int]] = set()
    for col in range(5, 11):
        eligible.add((col, 13))
    for col in range(15, 22):
        eligible.add((col, 10))
    for col in range(9, 16):
        eligible.add((col, 7))
    return EligibilityLayer(eligible=eligible)


def _cherry_bower_eligibility() -> EligibilityLayer:
    """Floating island clusters with an updraft — dreamy, asymmetric."""
    eligible: set[tuple[int, int]] = set()
    for col in range(3, 9):
        eligible.add((col, 12))
    for col in range(17, 24):
        eligible.add((col, 9))
    for col in range(10, 17):
        eligible.add((col, 5))
    return EligibilityLayer(
        eligible=eligible,
        updraft_col=14,
        updraft_row_top=3,
        updraft_row_bottom=15,
    )


# ── World definition ──────────────────────────────────────────────────────────

def build_game_definition() -> GameDefinition:
    rooms: dict[str, RoomDef] = {

        # ── Hub ───────────────────────────────────────────────────────────────
        "foyer": RoomDef(
            room_id="foyer",
            display_name="The Foyer",
            exits=[
                # Trigger exits checked FIRST to take priority over directional exits.
                # Exit 2 — mid-right, gated by slime_gate
                ExitDef(
                    to_room="antechamber_1",
                    direction="east",
                    route_kind="platform",
                    gate_id="slime_gate",
                    trigger_col=26,
                    trigger_row=11,
                ),
                # Exit 3 — upper-left, gated by guardian_gate → cherry gallery chain
                ExitDef(
                    to_room="gallery_a",
                    direction="west",
                    route_kind="platform",
                    gate_id="guardian_gate",
                    trigger_col=3,
                    trigger_row=7,
                ),
                # Exit 4 — top-right, gated by cherry_gate → dream spire chain → WIN
                ExitDef(
                    to_room="spire_a",
                    direction="east",
                    route_kind="platform",
                    gate_id="cherry_gate",
                    trigger_col=26,
                    trigger_row=3,
                ),
                # Exit 1 — ground west, always open → intro corridor
                ExitDef(
                    to_room="mud_passage",
                    direction="west",
                    route_kind="ground",
                ),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_foyer_eligibility(),
                seed=7,
                fill_density=0.55,
                min_fill=0.40,
            ),
            biome="foyer",
        ),

        # ── Intro corridor — lowest difficulty ────────────────────────────────
        # Three wide stepping-stone platforms staircase left from ground.
        # The upper_west exit fires once the player is above row 13 at the
        # left wall (py < 13*TILE_H) — naturally reached via the row-10 platform.
        "mud_passage": RoomDef(
            room_id="mud_passage",
            display_name="The Drip Hall",
            exits=[
                # Primary forward exit — elevated left wall → slime_lair
                ExitDef(
                    to_room="slime_lair",
                    direction="upper_west",
                    route_kind="platform",
                ),
                # Return exit — ground east → foyer
                ExitDef(
                    to_room="foyer",
                    direction="east",
                    route_kind="ground",
                ),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_mud_passage_eligibility(),
                seed=3,
                fill_density=0.80,   # generous fill — easy room
                min_fill=0.65,
            ),
            biome="alcove",
        ),

        # ── Slime Maiden's domain — slightly harder ───────────────────────────
        # Five-platform zigzag rising to row 5.  The hop from row 10 → row 7
        # (3 rows = 96 px) is the single demanding jump; an updraft at col 15
        # assists the upper half.  Slime Maiden waits at the top (col 10, row 5).
        "slime_lair": RoomDef(
            room_id="slime_lair",
            display_name="The Mud Room",
            exits=[
                # Return — ground east → back to mud_passage corridor
                ExitDef(
                    to_room="mud_passage",
                    direction="east",
                    route_kind="platform",
                ),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_slime_lair_eligibility(),
                seed=9,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="alcove",
        ),

        # ── Gallery chain — east-to-west, moderate (guardian_gate path) ────────────
        # Three rooms between foyer and cherry_bower.  Player enters from east each
        # time (right-side spawn), staircases upward-left to upper_west exit.
        # Return exits allow backtracking: gallery_a upper_east → foyer,
        # gallery_b/c upper_east → previous gallery room.

        "gallery_a": RoomDef(
            room_id="gallery_a",
            display_name="The East Gallery",
            exits=[
                ExitDef(
                    to_room="gallery_b",
                    direction="upper_west",
                    route_kind="platform",
                ),
                ExitDef(to_room="foyer", direction="upper_east", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_gallery_a_eligibility(),
                seed=53,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="gallery",
        ),

        "gallery_b": RoomDef(
            room_id="gallery_b",
            display_name="The West Gallery",
            exits=[
                ExitDef(
                    to_room="gallery_c",
                    direction="upper_west",
                    route_kind="platform",
                ),
                ExitDef(to_room="gallery_a", direction="upper_east", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_gallery_b_eligibility(),
                seed=59,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="gallery",
        ),

        "gallery_c": RoomDef(
            room_id="gallery_c",
            display_name="The Gallery Vault",
            exits=[
                ExitDef(
                    to_room="cherry_bower",
                    direction="upper_west",
                    route_kind="platform",
                ),
                ExitDef(to_room="gallery_b", direction="upper_east", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_gallery_c_eligibility(),
                seed=61,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="gallery",
        ),

        # ── Spire chain — west-to-east, hardest (cherry_gate path → bed_room) ─────
        # Four rooms between foyer and bed_room.  Player enters from west each time
        # (left-side spawn), staircases upward-right to upper_east exit.
        # Return exits allow backtracking: spire_a west → foyer,
        # spire_b/c/d upper_west → previous spire room.

        "spire_a": RoomDef(
            room_id="spire_a",
            display_name="The First Climb",
            exits=[
                ExitDef(
                    to_room="spire_b",
                    direction="upper_east",
                    route_kind="platform",
                ),
                ExitDef(to_room="foyer", direction="west", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_spire_a_eligibility(),
                seed=67,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="gallery",
        ),

        "spire_b": RoomDef(
            room_id="spire_b",
            display_name="The Second Climb",
            exits=[
                ExitDef(
                    to_room="spire_c",
                    direction="upper_east",
                    route_kind="platform",
                ),
                ExitDef(to_room="spire_a", direction="upper_west", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_spire_b_eligibility(),
                seed=71,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="gallery",
        ),

        "spire_c": RoomDef(
            room_id="spire_c",
            display_name="The Third Climb",
            exits=[
                ExitDef(
                    to_room="spire_d",
                    direction="upper_east",
                    route_kind="platform",
                ),
                ExitDef(to_room="spire_b", direction="upper_west", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_spire_c_eligibility(),
                seed=73,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="gallery",
        ),

        "spire_d": RoomDef(
            room_id="spire_d",
            display_name="The Final Ascent",
            exits=[
                ExitDef(
                    to_room="bed_room",
                    direction="upper_east",
                    route_kind="platform",
                ),
                ExitDef(to_room="spire_c", direction="upper_west", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_spire_d_eligibility(),
                seed=79,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="gallery",
        ),

        # ── Antechamber 1 — moderate puzzle (reached via slime_gate) ─────────────
        # Four staircase platforms west→east, comfortable 2-row gaps.
        # upper_east exit at row 7 (py≈245px < 440px threshold).
        "antechamber_1": RoomDef(
            room_id="antechamber_1",
            display_name="The Stone Passage",
            exits=[
                ExitDef(
                    to_room="antechamber_2",
                    direction="upper_east",
                    route_kind="platform",
                ),
                ExitDef(to_room="foyer", direction="west", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_antechamber_1_eligibility(),
                seed=31,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="gallery",
        ),

        # ── Antechamber 2 — hard puzzle (reached from antechamber_1) ─────────────
        # Five staircase platforms; first gap is 3 tiles wide (skill check jump).
        # upper_east exit at row 5 (py≈165px < 440px threshold).
        "antechamber_2": RoomDef(
            room_id="antechamber_2",
            display_name="The High Passage",
            exits=[
                ExitDef(
                    to_room="guardian_hall",
                    direction="upper_east",
                    route_kind="platform",
                ),
                ExitDef(to_room="antechamber_1", direction="west", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_antechamber_2_eligibility(),
                seed=47,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="gallery",
        ),

        # ── Guardian's hall (reached via antechamber_2) ───────────────────────
        "guardian_hall": RoomDef(
            room_id="guardian_hall",
            display_name="Guardian's Hall",
            exits=[
                ExitDef(to_room="antechamber_2", direction="west", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_guardian_hall_eligibility(),
                seed=13,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="gallery",
        ),

        # ── Cherry's bower (reached via guardian_gate at tier C) ──────────────
        "cherry_bower": RoomDef(
            room_id="cherry_bower",
            display_name="Cherry's Bower",
            exits=[
                ExitDef(to_room="gallery_c", direction="east", route_kind="platform"),
            ],
            platform_layer=PlatformLayerDef(
                eligibility=_cherry_bower_eligibility(),
                seed=21,
                fill_density=1.0,
                min_fill=1.0,
            ),
            biome="alcove",
        ),

        # ── Bed room — win condition (reached via spire_d) ───────────────────
        "bed_room": RoomDef(
            room_id="bed_room",
            display_name="Lily's Room",
            exits=[
                ExitDef(to_room="spire_d", direction="west", route_kind="platform"),
            ],
            biome="bedroom",
        ),
    }

    npcs = [
        # Slime Maiden — at top of slime_lair (row 5), solving her opens slime_gate
        NPCDef(
            npc_id="slime_maiden",
            room_id="slime_lair",
            col=10,
            row=5,
            bypass_gate_id="slime_gate",
        ),
        # Guardian — in guardian_hall, solving him opens guardian_gate (exit 3)
        NPCDef(
            npc_id="guardian",
            room_id="guardian_hall",
            col=12,
            row=7,
            bypass_gate_id="guardian_gate",
        ),
        # Cherry — in cherry_bower, solving her opens cherry_gate (exit 4)
        NPCDef(
            npc_id="cherry",
            room_id="cherry_bower",
            col=13,
            row=5,
            bypass_gate_id="cherry_gate",
        ),
    ]

    floors = [
        FloorDef(
            floor_id="ground_floor",
            branches=[
                BranchDef(
                    branch_id="slime_maiden",
                    npc_id="slime_maiden",
                    rooms=["mud_passage", "slime_lair"],
                ),
            ],
        ),
        FloorDef(
            floor_id="upper_floor",
            branches=[
                BranchDef(
                    branch_id="guardian",
                    npc_id="guardian",
                    rooms=["antechamber_1", "antechamber_2", "guardian_hall"],
                ),
                BranchDef(
                    branch_id="cherry",
                    npc_id="cherry",
                    rooms=["gallery_a", "gallery_b", "gallery_c", "cherry_bower"],
                ),
            ],
        ),
    ]

    return GameDefinition(
        game_id="lilys_music_box",
        display_title="Lily's Music Box",
        start_room_id="foyer",
        win_room_id="bed_room",
        fatigue_seconds=120.0,
        graph=RoomGraph(rooms=rooms),
        npcs=npcs,
        floors=floors,
    )
