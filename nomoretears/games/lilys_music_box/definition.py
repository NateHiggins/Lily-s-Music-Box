"""
games/lilys_music_box/definition.py
-------------------------------------
GameDefinition for the Lily's Music Box proof-of-concept slice.

World layout:
  [foyer] ─── east ──> [gallery_hall] ─── upper_east ──> [music_alcove (objective)]
                │                                          (upper route — platform skill)
                └─── east (bypass_arch) ──> [bed_alcove]  (bypass — unlocked after solve)

  foyer: start point. Slime NPC ("the archivist") is here.
  gallery_hall: branch room with platforms. Music-note objective at upper right.
  music_alcove: reaching this room counts as the objective.
  bed_alcove: Lily's destination (win). Accessible via ground east after bypass unlocks.

NPC design intent:
  The Archivist is anxious — they've lost a song and need someone to find where
  the melody drifted to (the music alcove at the top of the gallery).
  Solving unlocks the bypass_arch gate so future runs can skip the gallery entirely.
"""
from engine.room_graph import (
    GameDefinition, RoomGraph, RoomDef, ExitDef,
    EligibilityLayer, PlatformLayerDef,
    NPCDef, ObjectiveDef, BranchDef, FloorDef,
)


# ── Eligibility layers ─────────────────────────────────────────────────────────

def _gallery_eligibility() -> EligibilityLayer:
    """
    Gallery Hall platform eligibility.
    Platforms form a staircase pattern rising from floor (row 14) to upper exit (row 8).
    The updraft at col 15 helps reach the upper tier.
    """
    eligible: set[tuple[int, int]] = set()

    # Lower tier platforms (rows 12-14) — left half
    for col in range(4, 10):
        eligible.add((col, 14))
    for col in range(7, 14):
        eligible.add((col, 12))

    # Mid platforms (row 10) — spanning center
    for col in range(12, 20):
        eligible.add((col, 10))

    # Upper platforms (rows 8-9) — right half, leads to upper_east exit
    for col in range(18, 27):
        eligible.add((col, 8))
    for col in range(22, 27):
        eligible.add((col, 9))

    return EligibilityLayer(
        eligible=eligible,
        updraft_col=15,
        updraft_row_top=3,
        updraft_row_bottom=16,
    )


# ── Room definitions ───────────────────────────────────────────────────────────

def _build_rooms() -> dict[str, RoomDef]:
    rooms: dict[str, RoomDef] = {}

    # Foyer — start room. Plain floor, Archivist NPC.
    rooms["foyer"] = RoomDef(
        room_id="foyer",
        display_name="The Foyer",
        exits=[
            ExitDef(to_room="gallery_hall",  direction="east",  route_kind="ground"),
            ExitDef(to_room="bed_alcove",    direction="east",  route_kind="bypass",
                    gate_id="bypass_arch"),
        ],
        platform_layer=None,   # no platforms — simple starting room
        biome="foyer",
    )

    # Gallery Hall — the branch room with platforms and updraft.
    rooms["gallery_hall"] = RoomDef(
        room_id="gallery_hall",
        display_name="Gallery Hall",
        exits=[
            ExitDef(to_room="foyer",        direction="west",       route_kind="ground"),
            ExitDef(to_room="music_alcove", direction="upper_east", route_kind="platform"),
        ],
        platform_layer=PlatformLayerDef(
            eligibility=_gallery_eligibility(),
            seed=42,
            fill_density=0.55,
            min_fill=0.30,
        ),
        branch_id="archivist",
        biome="gallery",
    )

    # Music Alcove — objective destination. Upper room, simple floor.
    rooms["music_alcove"] = RoomDef(
        room_id="music_alcove",
        display_name="Music Alcove",
        exits=[
            ExitDef(to_room="gallery_hall", direction="west", route_kind="platform"),
        ],
        platform_layer=None,
        branch_id="archivist",
        biome="alcove",
    )

    # Bed Alcove — win room. Accessible via bypass after solving Archivist.
    rooms["bed_alcove"] = RoomDef(
        room_id="bed_alcove",
        display_name="Lily's Room",
        exits=[
            ExitDef(to_room="foyer", direction="west", route_kind="bypass"),
        ],
        platform_layer=None,
        biome="bedroom",
    )

    return rooms


# ── NPCs ──────────────────────────────────────────────────────────────────────

def _build_npcs() -> list[NPCDef]:
    return [
        NPCDef(
            npc_id="archivist",
            room_id="foyer",
            col=18,
            row=17,   # standing on floor
            dialogue=(
                "The melody... it drifted upward into the gallery. "
                "If you could find where it settled, I could rest. "
                "Try the upper east passage of the gallery."
            ),
            solved_dialogue=(
                "You found it! The song is safe. "
                "The arch shortcut is open now — you can reach your room directly."
            ),
            objective=ObjectiveDef(
                room_id="music_alcove",
                col=15,
                row=16,    # on the floor of the alcove
                prompt="Find where the melody settled",
            ),
            bypass_gate_id="bypass_arch",
        ),
    ]


# ── Floors / branches ──────────────────────────────────────────────────────────

def _build_floors() -> list[FloorDef]:
    return [
        FloorDef(
            floor_id="ground_floor",
            branches=[
                BranchDef(
                    branch_id="archivist",
                    npc_id="archivist",
                    rooms=["gallery_hall", "music_alcove"],
                ),
            ],
        ),
    ]


# ── GameDefinition factory ─────────────────────────────────────────────────────

def build_game() -> GameDefinition:
    """Build and return the full Lily's Music Box GameDefinition."""
    rooms = _build_rooms()
    return GameDefinition(
        game_id="lilys_music_box",
        display_title="Lily's Music Box",
        start_room_id="foyer",
        win_room_id="bed_alcove",
        fatigue_seconds=90.0,
        graph=RoomGraph(rooms=rooms),
        npcs=_build_npcs(),
        floors=_build_floors(),
    )
