"""
tests_engine/test_room_graph.py
---------------------------------
Tests for GameDefinition, GameState, GameBundle, and DialogueRunner.
Updated to reflect the hub-foyer world: Slime Maiden → Guardian → Cherry → bed.
"""
import pytest
from engine.room_graph import GameDefinition
from engine.state import GameState
from engine.bundle import GameBundle
from games.lilys_music_box import load as lmb_load
from games.lilys_music_box.layout import build_game_definition


def _def():
    return build_game_definition()


def _bundle():
    return lmb_load()


# -- Bundle / definition integrity

def test_bundle_loads():
    b = _bundle()
    assert b.definition.game_id == "lilys_music_box"
    assert b.theme is not None
    assert "slime_maiden" in b.dialogue_trees
    assert "guardian" in b.dialogue_trees
    assert "cherry" in b.dialogue_trees
    assert b.art is not None


def test_all_exit_targets_exist():
    game = _def()
    for room_id, room in game.graph.rooms.items():
        for ex in room.exits:
            assert ex.to_room in game.graph.rooms, \
                f"{room_id!r} exit {ex.direction!r} -> unknown {ex.to_room!r}"


def test_all_npc_rooms_exist():
    game = _def()
    for npc in game.npcs:
        assert npc.room_id in game.graph.rooms


def test_all_objective_rooms_exist():
    """NPCs with optional objectives — only check those that have one."""
    game = _def()
    for npc in game.npcs:
        if npc.objective is not None:
            assert npc.objective.room_id in game.graph.rooms


def test_bypass_gate_referenced_in_exits():
    game = _def()
    gate_ids = {ex.gate_id for room in game.graph.rooms.values()
                for ex in room.exits if ex.gate_id}
    for npc in game.npcs:
        if npc.bypass_gate_id:
            assert npc.bypass_gate_id in gate_ids


def test_no_duplicate_npc_ids():
    game = _def()
    ids = [n.npc_id for n in game.npcs]
    assert len(ids) == len(set(ids))


def test_foyer_has_four_exits():
    """Hub room must have exactly four exits — one per gate tier."""
    game = _def()
    foyer = game.graph.get("foyer")
    assert foyer is not None
    assert len(foyer.exits) == 4


def test_foyer_west_leads_to_mud_passage():
    """Foyer's always-open west exit leads to the intro corridor, not directly to slime_lair."""
    game = _def()
    foyer = game.graph.get("foyer")
    west_exits = [ex for ex in foyer.exits if ex.direction == "west" and ex.gate_id is None]
    assert len(west_exits) == 1
    assert west_exits[0].to_room == "mud_passage"


def test_mud_passage_exists():
    """mud_passage room is registered in the graph."""
    game = _def()
    assert game.graph.get("mud_passage") is not None


def test_mud_passage_leads_to_slime_lair():
    """mud_passage has an upper_west exit to slime_lair (always open)."""
    game = _def()
    room = game.graph.get("mud_passage")
    assert room is not None
    upper_exits = [ex for ex in room.exits if ex.to_room == "slime_lair"]
    assert len(upper_exits) == 1
    assert upper_exits[0].direction == "upper_west"
    assert upper_exits[0].gate_id is None   # no gate on this hop


def test_mud_passage_returns_to_foyer():
    """mud_passage has a ground east exit back to the foyer."""
    game = _def()
    room = game.graph.get("mud_passage")
    back = [ex for ex in room.exits if ex.to_room == "foyer"]
    assert len(back) == 1


def test_slime_lair_returns_to_mud_passage():
    """slime_lair's exit leads back to mud_passage, not directly to foyer."""
    game = _def()
    room = game.graph.get("slime_lair")
    assert room is not None
    exits = room.exits
    assert len(exits) == 1
    assert exits[0].to_room == "mud_passage"


def test_slime_maiden_elevated():
    """Slime Maiden is above the floor (row < 17) — top of a platform section."""
    game = _def()
    sm = game.get_npc("slime_maiden")
    assert sm is not None
    assert sm.row < 10   # well above the floor (floor is row 17)


def test_exit_gate_chain():
    """Gate IDs used in foyer exits match the bypass_gate_ids of the three NPCs."""
    game = _def()
    foyer_gates = {ex.gate_id for ex in game.graph.get("foyer").exits if ex.gate_id}
    npc_gates   = {n.bypass_gate_id for n in game.npcs if n.bypass_gate_id}
    assert foyer_gates == npc_gates


# -- GameState

def test_initial_state():
    state = GameState(game_def=_def())
    assert state.fatigue_remaining == _def().fatigue_seconds
    assert state.flags == {}


def test_solve_npc_opens_gate():
    """Solving slime_maiden via state.solve_npc opens slime_gate."""
    state = GameState(game_def=_def())
    assert not state.is_gate_open("slime_gate")
    state.solve_npc("slime_maiden")
    assert state.is_gate_open("slime_gate")


def test_full_npc_chain_opens_gates():
    """Solving all three NPCs in sequence opens all three gates."""
    state = GameState(game_def=_def())
    for npc_id, gate_id in [
        ("slime_maiden", "slime_gate"),
        ("guardian",     "guardian_gate"),
        ("cherry",       "cherry_gate"),
    ]:
        assert not state.is_gate_open(gate_id)
        state.solve_npc(npc_id)
        assert state.is_gate_open(gate_id)


def test_flag_operations():
    state = GameState(game_def=_def())
    assert not state.flags.get("met_slime_maiden")
    state.flags["met_slime_maiden"] = True
    assert state.flags["met_slime_maiden"]


def test_fill_density_increases():
    """Foyer has a platform layer; repeated entry raises its fill density."""
    state = GameState(game_def=_def())
    d0 = state.get_fill_density("foyer")
    state.record_room_entry("foyer")
    assert state.get_fill_density("foyer") > d0


def test_fill_density_caps():
    state = GameState(game_def=_def())
    for _ in range(100):
        state.record_room_entry("foyer")
    assert state.get_fill_density("foyer") <= 0.95


def test_fatigue_expiry():
    state = GameState(game_def=_def())
    state.fatigue_remaining = 0.05
    assert state.tick_fatigue(0.1)
    assert state.fatigue_remaining == 0


# -- Dialogue tree integrity

def test_all_choice_targets_exist():
    b = _bundle()
    for npc_id, tree in b.dialogue_trees.items():
        for node in tree.nodes.values():
            for choice in node.choices:
                if choice.next_node is not None:
                    assert choice.next_node in tree.nodes, \
                        f"{npc_id!r}/{node.node_id!r} -> unknown {choice.next_node!r}"


def test_root_node_exists():
    b = _bundle()
    for npc_id, tree in b.dialogue_trees.items():
        assert tree.root_node in tree.nodes


def test_dialogue_runner_starts():
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    runner = DialogueRunner(b.dialogue_trees["slime_maiden"], state)
    assert runner.active
    assert runner.current_node() is not None


def test_dialogue_choice_advances_node():
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    runner = DialogueRunner(b.dialogue_trees["slime_maiden"], state)
    start_id = runner.current_node().node_id
    choices = runner.visible_choices()
    assert len(choices) >= 1
    runner.select_choice(0)
    assert runner.current_node().node_id != start_id


def test_none_next_closes_runner():
    """A choice with next_node=None closes the runner immediately."""
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    runner = DialogueRunner(b.dialogue_trees["slime_maiden"], state)
    # "farewell" has one choice -> None (closes runner)
    runner._goto("farewell")
    runner.select_choice(0)
    assert not runner.active


def test_setflag_effect_fires():
    """Entering the farewell node fires SetFlag('met_slime_maiden')."""
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    runner = DialogueRunner(b.dialogue_trees["slime_maiden"], state)
    runner._goto("farewell")
    assert state.flags.get("met_slime_maiden") is True


def test_solve_npc_effect_fires():
    """Entering the farewell node fires SolveNPC, marking slime_maiden solved."""
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    runner = DialogueRunner(b.dialogue_trees["slime_maiden"], state)
    runner._goto("farewell")
    assert state.is_npc_solved("slime_maiden")


def test_root_selector_post_solve():
    """After slime_maiden is solved, her runner starts at solved_root."""
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    state.solve_npc("slime_maiden")
    runner = DialogueRunner(b.dialogue_trees["slime_maiden"], state)
    assert runner.current_node().node_id == "solved_root"


def test_guardian_reproach_branch():
    """Guardian shows reproach branch when met_slime_maiden flag is NOT set."""
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    runner = DialogueRunner(b.dialogue_trees["guardian"], state)
    # Without met_slime_maiden, the "I spoke with Slime Maiden" choice is hidden
    choices = runner.visible_choices()
    texts = [c.text for _, c in choices]
    assert any("straight here" in t for t in texts)
    # The Slime Maiden option should not be visible (condition: FlagSet)
    assert not any("Slime Maiden" in t for t in texts)


def test_guardian_honoured_branch():
    """Guardian shows honoured path when met_slime_maiden flag IS set."""
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    state.flags["met_slime_maiden"] = True
    runner = DialogueRunner(b.dialogue_trees["guardian"], state)
    choices = runner.visible_choices()
    texts = [c.text for _, c in choices]
    assert any("Slime Maiden" in t for t in texts)


def test_dismiss_closes_runner():
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    runner = DialogueRunner(b.dialogue_trees["slime_maiden"], state)
    runner.dismiss()
    assert not runner.active


# -- Tileset mechanic

def test_bundle_has_tilesets():
    """Bundle registers all four named tilesets."""
    b = _bundle()
    for tid in ("escher_foyer", "klimt_dining", "guardian_gothic", "lily_bedroom"):
        assert tid in b.tilesets, f"Missing tileset {tid!r} in bundle"


def test_default_active_tileset():
    """Initial GameState defaults to klimt_dining — game starts in Klimt."""
    state = GameState(game_def=_def())
    assert state.active_tileset == "klimt_dining"


def test_settileset_effect_updates_state():
    """SetTileset effect changes state.active_tileset."""
    from engine.dialogue import SetTileset
    state = GameState(game_def=_def())
    SetTileset("klimt_dining").apply(state)
    assert state.active_tileset == "klimt_dining"


def test_slime_maiden_farewell_fires_settileset():
    """Solving Slime Maiden switches to guardian_gothic (next set in chain)."""
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    runner = DialogueRunner(b.dialogue_trees["slime_maiden"], state)
    runner._goto("farewell")
    assert state.active_tileset == "guardian_gothic"


def test_guardian_passage_fires_settileset():
    """Solving Guardian switches to escher_foyer (next set in chain)."""
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    runner = DialogueRunner(b.dialogue_trees["guardian"], state)
    runner._goto("passage")
    assert state.active_tileset == "escher_foyer"


def test_cherry_open_door_fires_settileset():
    """Cherry's open_door node triggers SetTileset('lily_bedroom')."""
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())
    runner = DialogueRunner(b.dialogue_trees["cherry"], state)
    runner._goto("open_door")
    assert state.active_tileset == "lily_bedroom"


def test_tileset_chain_sequence():
    """Full NPC chain produces the correct tileset progression.

    Start: klimt_dining (Slime Maiden's world, game opens here)
    Slime Maiden solved → guardian_gothic
    Guardian solved     → escher_foyer
    Cherry solved       → lily_bedroom (win)
    """
    from engine.dialogue import DialogueRunner
    b = _bundle()
    state = GameState(game_def=_def())

    assert state.active_tileset == "klimt_dining"

    DialogueRunner(b.dialogue_trees["slime_maiden"], state)._goto("farewell")
    assert state.active_tileset == "guardian_gothic"

    DialogueRunner(b.dialogue_trees["guardian"], state)._goto("passage")
    assert state.active_tileset == "escher_foyer"

    DialogueRunner(b.dialogue_trees["cherry"], state)._goto("open_door")
    assert state.active_tileset == "lily_bedroom"


# -- Tileset cycle

def test_default_tileset_auto_unlocked():
    """Starting tileset (klimt_dining) is pre-populated in unlocked_tilesets."""
    state = GameState(game_def=_def())
    assert "klimt_dining" in state.unlocked_tilesets


def test_settileset_adds_to_unlocked():
    """SetTileset adds the new id to unlocked_tilesets as well as setting active."""
    from engine.dialogue import SetTileset
    state = GameState(game_def=_def())
    SetTileset("klimt_dining").apply(state)
    assert "klimt_dining" in state.unlocked_tilesets


def test_bundle_has_tileset_cycle():
    """Bundle has a non-empty tileset_cycle and it includes 'fallback'."""
    b = _bundle()
    assert b.tileset_cycle
    assert "fallback" in b.tileset_cycle
    assert "escher_foyer" in b.tileset_cycle


def test_bundle_has_display_names():
    """Every id in tileset_cycle has a human-readable display name."""
    b = _bundle()
    for tid in b.tileset_cycle:
        assert tid in b.tileset_display_names, f"Missing display name for {tid!r}"


def _make_session_with_state(state):
    """Helper: build a _Session backed by the lmb bundle and the given state."""
    from engine.core import _Session
    from engine.renderer import Renderer
    b = _bundle()
    renderer = Renderer(b.theme, b)
    session = _Session(state, renderer, b)
    return session


def test_cycle_only_shows_unlocked():
    """cycle_tileset skips locked tilesets and wraps on available ones."""
    state = GameState(game_def=_def())
    # Only klimt_dining is unlocked at start; fallback is always available.
    session = _make_session_with_state(state)
    assert state.active_tileset == "klimt_dining"
    session.cycle_tileset()
    # Should land on "fallback" (only other available entry)
    assert state.active_tileset == "fallback"
    session.cycle_tileset()
    assert state.active_tileset == "klimt_dining"


def test_cycle_expands_after_unlock():
    """Once a tileset is unlocked, it appears in the cycle."""
    from engine.dialogue import SetTileset
    state = GameState(game_def=_def())
    SetTileset("guardian_gothic").apply(state)
    # active is now guardian_gothic; unlocked = {klimt_dining, guardian_gothic}
    session = _make_session_with_state(state)
    session.cycle_tileset()
    # Next available after guardian_gothic in cycle order: escher? No, not unlocked.
    # Available: klimt_dining, guardian_gothic, fallback → next after guardian is fallback
    assert state.active_tileset == "fallback"


def test_cycle_full_unlock():
    """With all tilesets unlocked, cycling visits every entry in order."""
    from engine.dialogue import SetTileset
    state = GameState(game_def=_def())
    for tid in ("guardian_gothic", "escher_foyer", "lily_bedroom"):
        SetTileset(tid).apply(state)
    # active is lily_bedroom after chain; reset to klimt for predictable start
    state.active_tileset = "klimt_dining"
    session = _make_session_with_state(state)
    seen = []
    for _ in range(5):
        session.cycle_tileset()
        seen.append(state.active_tileset)
    # Full cycle order: klimt → guardian → escher → lily → fallback → klimt
    assert seen == ["guardian_gothic", "escher_foyer", "lily_bedroom", "fallback", "klimt_dining"]
