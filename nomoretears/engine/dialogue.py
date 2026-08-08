"""
engine/dialogue.py
------------------
Dialogue tree data model, condition/effect primitives, and DialogueRunner.

Game modules build DialogueTree instances from these primitives — the engine
traverses them. No game-specific logic lives here.

Coordinate system for choices: visible_choices() returns only choices whose
condition evaluates True against the current GameState. Indices are stable
within one node (use them for key-press mapping).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Callable, Protocol, runtime_checkable

if TYPE_CHECKING:
    from engine.state import GameState


# ── Condition protocol ────────────────────────────────────────────────────────

@runtime_checkable
class Condition(Protocol):
    def evaluate(self, state: "GameState") -> bool: ...


@dataclass
class GateOpen:
    gate_id: str
    def evaluate(self, state: "GameState") -> bool:
        return state.is_gate_open(self.gate_id)


@dataclass
class NPCSolved:
    npc_id: str
    def evaluate(self, state: "GameState") -> bool:
        return state.is_npc_solved(self.npc_id)


@dataclass
class RoomVisited:
    room_id: str
    min_times: int = 1
    def evaluate(self, state: "GameState") -> bool:
        return state.attempt_count.get(self.room_id, 0) >= self.min_times


@dataclass
class FlagSet:
    flag_name: str
    def evaluate(self, state: "GameState") -> bool:
        return state.flags.get(self.flag_name, False)


@dataclass
class AnyOf:
    conditions: list[Condition]
    def evaluate(self, state: "GameState") -> bool:
        return any(c.evaluate(state) for c in self.conditions)


@dataclass
class AllOf:
    conditions: list[Condition]
    def evaluate(self, state: "GameState") -> bool:
        return all(c.evaluate(state) for c in self.conditions)


@dataclass
class Not:
    condition: Condition
    def evaluate(self, state: "GameState") -> bool:
        return not self.condition.evaluate(state)


# ── Effect protocol ───────────────────────────────────────────────────────────

@runtime_checkable
class Effect(Protocol):
    def apply(self, state: "GameState") -> None: ...


@dataclass
class SolveNPC:
    npc_id: str
    def apply(self, state: "GameState") -> None:
        state.solve_npc(self.npc_id)


@dataclass
class OpenGate:
    gate_id: str
    def apply(self, state: "GameState") -> None:
        state.open_gates.add(self.gate_id)


@dataclass
class SetFlag:
    flag_name: str
    value: bool = True
    def apply(self, state: "GameState") -> None:
        state.flags[self.flag_name] = self.value


@dataclass
class SetTileset:
    """
    Switch the active tileset for all rooms immediately and record it as
    unlocked so the player can cycle back to it via the [T] key.
    """
    tileset_id: str
    def apply(self, state: "GameState") -> None:
        state.active_tileset = self.tileset_id
        state.unlocked_tilesets.add(self.tileset_id)


@dataclass
class SetFillDensity:
    room_id: str
    density: float
    def apply(self, state: "GameState") -> None:
        state.fill_density_map[self.room_id] = max(0.0, min(1.0, self.density))
        state._layout_cache.pop(self.room_id, None)


# ── Tree nodes ────────────────────────────────────────────────────────────────

@dataclass
class DialogueChoice:
    """One branch option shown to the player."""
    text: str
    next_node: str | None       # None = close dialogue after this choice
    condition: Condition | None = None


@dataclass
class DialogueNode:
    """
    One beat of dialogue.

    If choices is non-empty the player must pick one to advance.
    If choices is empty, the runner advances automatically to next_node
    (or closes if next_node is None) when the player presses advance.
    Effects fire immediately when the node is entered.
    """
    node_id: str
    text: str
    choices: list[DialogueChoice] = field(default_factory=list)
    effects: list[Effect] = field(default_factory=list)
    next_node: str | None = None


@dataclass
class DialogueTree:
    """
    Complete conversation tree for one NPC.

    root_node: default entry point.
    root_selector: optional callable — overrides root_node based on GameState,
                   e.g. returning a different node if the NPC is already solved.
    nodes: all nodes keyed by node_id.
    """
    root_node: str
    nodes: dict[str, DialogueNode]
    root_selector: Callable[["GameState"], str] | None = None

    def get_root(self, state: "GameState") -> str:
        if self.root_selector is not None:
            return self.root_selector(state)
        return self.root_node


# ── Runner ────────────────────────────────────────────────────────────────────

class DialogueRunner:
    """
    Stateful traverser for one open conversation.

    Lifecycle: create → read current_node() → player presses keys →
    select_choice() or advance() → repeat → active becomes False → discard.
    """

    def __init__(self, tree: DialogueTree, state: "GameState") -> None:
        self.tree = tree
        self.state = state
        self.active = True
        self._current_id: str = tree.get_root(state)
        self._fire_effects()

    # ── Public interface ──────────────────────────────────────────────────────

    def current_node(self) -> DialogueNode | None:
        return self.tree.nodes.get(self._current_id)

    def visible_choices(self) -> list[tuple[int, DialogueChoice]]:
        """Return (display_index, choice) for choices whose condition passes."""
        node = self.current_node()
        if not node:
            return []
        return [
            (i, c) for i, c in enumerate(node.choices)
            if c.condition is None or c.condition.evaluate(self.state)
        ]

    def select_choice(self, display_index: int) -> None:
        """Player selected the choice at display_index in visible_choices()."""
        visible = self.visible_choices()
        if display_index >= len(visible):
            return
        _, choice = visible[display_index]
        if choice.next_node is None:
            self.active = False
        else:
            self._goto(choice.next_node)

    def advance(self) -> None:
        """
        For nodes with no choices: advance to next_node or close.
        For nodes with choices: no-op (player must select).
        """
        node = self.current_node()
        if not node:
            self.active = False
            return
        if node.choices:
            return   # choices present — must use select_choice
        if node.next_node:
            self._goto(node.next_node)
        else:
            self.active = False

    def dismiss(self) -> None:
        """Force-close the dialogue (player pressed Escape / E again)."""
        self.active = False

    # ── Internal ──────────────────────────────────────────────────────────────

    def _goto(self, node_id: str) -> None:
        self._current_id = node_id
        self._fire_effects()

    def _fire_effects(self) -> None:
        node = self.current_node()
        if node:
            for effect in node.effects:
                effect.apply(self.state)
