"""
tests_engine/test_proc_gen.py
------------------------------
Tests for procedural platform generation. No pygame dependency.
"""
import pytest
from engine.room_graph import EligibilityLayer
from engine.proc_gen import generate_layout, validate_routes, GeneratedLayout
from engine.room_graph import ROOM_COLS, ROOM_ROWS


def _simple_layer() -> EligibilityLayer:
    """A few eligible platform positions for testing."""
    eligible = {(c, r) for c in range(5, 25) for r in [10, 12, 14]}
    return EligibilityLayer(eligible=eligible, updraft_col=15)


def test_floor_always_solid():
    layer = _simple_layer()
    layout = generate_layout(layer, seed=1, fill_density=0.0)
    floor_row = ROOM_ROWS - 3
    # Every column of the floor row must be solid
    for col in range(ROOM_COLS):
        assert layout.is_solid(col, floor_row), f"Floor tile ({col}, {floor_row}) not solid"


def test_deterministic():
    layer = _simple_layer()
    a = generate_layout(layer, seed=7, fill_density=0.5)
    b = generate_layout(layer, seed=7, fill_density=0.5)
    assert a.solid_tiles == b.solid_tiles


def test_different_seeds_differ():
    layer = _simple_layer()
    a = generate_layout(layer, seed=1, fill_density=0.5)
    b = generate_layout(layer, seed=99, fill_density=0.5)
    # Elevated (non-floor) solids should differ
    floor_row = ROOM_ROWS - 3
    a_elev = {t for t in a.solid_tiles if t[1] < floor_row}
    b_elev = {t for t in b.solid_tiles if t[1] < floor_row}
    assert a_elev != b_elev


def test_fill_density_increases_platforms():
    layer = _simple_layer()
    sparse = generate_layout(layer, seed=42, fill_density=0.1)
    dense  = generate_layout(layer, seed=42, fill_density=1.0)
    floor_row = ROOM_ROWS - 3
    sparse_elev = len([t for t in sparse.solid_tiles if t[1] < floor_row])
    dense_elev  = len([t for t in dense.solid_tiles  if t[1] < floor_row])
    assert dense_elev >= sparse_elev


def test_ghost_tiles_are_eligible_but_unfilled():
    layer = _simple_layer()
    layout = generate_layout(layer, seed=5, fill_density=0.3)
    for (c, r) in layout.ghost_tiles:
        assert (c, r) in layer.eligible
        assert not layout.is_solid(c, r)


def test_no_overlap_solid_ghost():
    layer = _simple_layer()
    layout = generate_layout(layer, seed=3, fill_density=0.6)
    assert layout.solid_tiles.isdisjoint(layout.ghost_tiles)


def test_updraft_set_when_layer_has_updraft():
    layer = _simple_layer()
    layout = generate_layout(layer, seed=0, fill_density=0.5)
    assert layout.updraft is not None
    assert layout.updraft[0] == 15


def test_no_updraft_when_layer_has_none():
    layer = EligibilityLayer(eligible=set(), updraft_col=None)
    layout = generate_layout(layer, seed=0, fill_density=0.5)
    assert layout.updraft is None


def test_min_fill_respected():
    """Even at density=0.0 the min_fill fraction of eligible tiles is filled."""
    eligible = {(c, r) for c in range(5, 20) for r in [10, 12]}
    layer = EligibilityLayer(eligible=eligible)
    layout = generate_layout(layer, seed=0, fill_density=0.0, min_fill=0.5)
    floor_row = ROOM_ROWS - 3
    elev_solid = [t for t in layout.solid_tiles if t[1] < floor_row]
    # At min_fill=0.5 we expect at least half of 30 elevated eligible tiles filled
    assert len(elev_solid) >= len(eligible) * 0.5 - 2   # small tolerance for rounding


def test_route_validation_floor_always_reachable():
    layer = EligibilityLayer()
    layout = generate_layout(layer, seed=0, fill_density=0.0)
    floor_row = ROOM_ROWS - 3
    exits = [
        {"direction": "east", "col": ROOM_COLS - 2, "row": floor_row - 1},
        {"direction": "west", "col": 1, "row": floor_row - 1},
    ]
    result = validate_routes(layout, exits)
    assert result.valid, f"Floor exits unreachable: {result.message}"
