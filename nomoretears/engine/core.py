"""
engine/core.py
--------------
Main game loop. Accepts a GameBundle loaded from any game module.
Manages room transitions, fatigue resets, dialogue tree traversal,
and objective collection.
"""
from __future__ import annotations

import sys
import pygame

from engine.bundle import GameBundle
from engine.room_graph import TILE_W, TILE_H, ROOM_COLS, ROOM_ROWS
from engine.proc_gen import generate_layout, GeneratedLayout
from engine.state import GameState
from engine.physics import spawn_position_from_direction, PLAYER_W, PLAYER_H
from engine.entities import PlayerEntity, NPCEntity, ObjectiveEntity
from engine.dialogue import DialogueRunner
from engine.renderer import Renderer, SCREEN_W, SCREEN_H

TARGET_FPS = 60
TRANSITION_MARGIN_PX = 15


class Engine:
    """
    Load a GameBundle and run the game loop.
    Call Engine(bundle).run().
    """

    def __init__(self, bundle: GameBundle) -> None:
        self.bundle = bundle

    def run(
        self,
        screen: "pygame.Surface | None" = None,
        clock: "pygame.time.Clock | None" = None,
    ) -> None:
        """
        Run the game loop.
        If screen/clock are supplied (from the title screen) they are reused
        so pygame is not re-initialised.
        """
        if screen is None:
            pygame.init()
            pygame.font.init()
            screen = pygame.display.set_mode(
                (SCREEN_W, SCREEN_H),
                pygame.SCALED,
            )
            clock = pygame.time.Clock()
        pygame.display.set_caption(self.bundle.definition.display_title)
        if clock is None:
            clock = pygame.time.Clock()

        # Initialise joystick subsystem and open any already-connected devices.
        pygame.joystick.init()
        joysticks: dict[int, pygame.joystick.JoystickType] = {}
        for i in range(pygame.joystick.get_count()):
            joy = pygame.joystick.Joystick(i)
            joy.init()
            joysticks[joy.get_instance_id()] = joy

        state = GameState(game_def=self.bundle.definition)
        # Unlock every tileset registered in the cycle.
        # Progression gating (NPC-based unlocks) can narrow this down later;
        # for now all tilesets are available from session start.
        state.unlocked_tilesets.update(self.bundle.tileset_cycle)
        renderer = Renderer(self.bundle.theme, self.bundle)
        session = _Session(state, renderer, self.bundle)
        session.enter_room(self.bundle.definition.start_room_id, from_direction="center")

        tick = 0
        running = True
        while running:
            dt = clock.tick(TARGET_FPS) / 1000.0
            dt = min(dt, 0.05)

            jump_pressed    = False
            interact_pressed = False
            choice_pressed: int | None = None

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False

                # ── Keyboard ──────────────────────────────────────────────────
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        if session.dialogue_runner:
                            session.dialogue_runner.dismiss()
                        else:
                            running = False
                    elif event.key in (pygame.K_SPACE, pygame.K_UP, pygame.K_w):
                        if session.dialogue_runner:
                            session.dialogue_runner.advance()
                        else:
                            jump_pressed = True
                    elif event.key == pygame.K_e:
                        interact_pressed = True
                    elif event.key == pygame.K_t:
                        session.cycle_tileset()
                    elif event.key == pygame.K_1:
                        choice_pressed = 0
                    elif event.key == pygame.K_2:
                        choice_pressed = 1
                    elif event.key == pygame.K_3:
                        choice_pressed = 2
                    elif event.key == pygame.K_4:
                        choice_pressed = 3

                # ── Controller — hot-plug ─────────────────────────────────────
                elif event.type == pygame.JOYDEVICEADDED:
                    joy = pygame.joystick.Joystick(event.device_index)
                    joy.init()
                    joysticks[joy.get_instance_id()] = joy

                elif event.type == pygame.JOYDEVICEREMOVED:
                    joysticks.pop(event.instance_id, None)

                # ── Controller — buttons ──────────────────────────────────────
                elif event.type == pygame.JOYBUTTONDOWN:
                    # Cross/A (0) → jump/advance   Circle/B (1) → interact/dismiss
                    # Start (7 on Xbox, 9 on PS)   → escape/quit
                    btn = event.button
                    if btn == 0:           # A / Cross — jump or advance dialogue
                        if session.dialogue_runner:
                            session.dialogue_runner.advance()
                        else:
                            jump_pressed = True
                    elif btn == 1:         # B / Circle — interact or dismiss
                        interact_pressed = True
                    elif btn in (7, 9):    # Start / Options — quit/dismiss
                        if session.dialogue_runner:
                            session.dialogue_runner.dismiss()
                        else:
                            running = False
                    elif btn == 4:         # LB / L1 — cycle tileset backwards (future)
                        pass
                    elif btn == 5:         # RB / R1 — cycle tileset forward
                        session.cycle_tileset()
                    # Face buttons 2/3 (X/Y or Square/Triangle) for choices
                    elif btn == 2:
                        choice_pressed = 0
                    elif btn == 3:
                        choice_pressed = 1

                # ── Controller — D-pad as extra jump source ───────────────────
                elif event.type == pygame.JOYHATMOTION:
                    hx, hy = event.value
                    if hy == 1:            # D-pad up → jump
                        if session.dialogue_runner:
                            session.dialogue_runner.advance()
                        else:
                            jump_pressed = True

            # ── Interact / dialogue routing ───────────────────────────────────
            if interact_pressed:
                if session.dialogue_runner:
                    session.dialogue_runner.dismiss()
                else:
                    session.try_interact()

            if choice_pressed is not None and session.dialogue_runner:
                session.dialogue_runner.select_choice(choice_pressed)

            # Dismiss runner if it closed itself via effects/advance
            if session.dialogue_runner and not session.dialogue_runner.active:
                session.dialogue_runner = None

            # ── Analogue stick horizontal (merged from all connected sticks) ──
            joy_move = 0.0
            for joy in joysticks.values():
                if joy.get_numaxes() > 0:
                    ax = joy.get_axis(0)   # left stick X
                    if abs(ax) > abs(joy_move):
                        joy_move = ax
                # D-pad hat as digital movement if no significant stick input
                if abs(joy_move) < 0.2 and joy.get_numhats() > 0:
                    hx, _ = joy.get_hat(0)
                    if hx != 0:
                        joy_move = float(hx)

            keys = pygame.key.get_pressed()
            # Freeze player movement while dialogue is open
            if not session.dialogue_runner:
                session.update(dt, keys, jump_pressed, joy_move=joy_move)
            else:
                session.update_fatigue_only(dt)

            session.draw(screen, tick)
            pygame.display.flip()
            tick += 1

        pygame.quit()
        sys.exit()


# ── Session ───────────────────────────────────────────────────────────────────

class _Session:
    def __init__(
        self, state: GameState, renderer: Renderer, bundle: GameBundle
    ) -> None:
        self.state = state
        self.renderer = renderer
        self.bundle = bundle
        self.layout: GeneratedLayout | None = None
        self.player: PlayerEntity | None = None
        self.npcs: list[NPCEntity] = []
        self.objectives: list[ObjectiveEntity] = []
        self.dialogue_runner: DialogueRunner | None = None
        self._exit_grace: float = 0.0
        self._current_music_path: str | None = None   # last path fed to mixer

    # ── Music ──────────────────────────────────────────────────────────────────

    def _play_music_for_tileset(self) -> None:
        """
        Start the music track registered for the currently active tileset.

        Skips the reload when the same file is already playing — so room
        transitions that don't change the tileset never interrupt the track.
        Stops the mixer when no track is registered for the active tileset.
        All mixer calls are wrapped in a broad except so a missing file or an
        unsupported codec (e.g. .mp4 on a build without AAC) degrades silently.
        """
        import pygame
        tileset_id = getattr(self.state, "active_tileset", "")
        path = self.bundle.tileset_music.get(tileset_id)
        if path is None:
            # No track registered → stop whatever was playing
            try:
                if pygame.mixer.get_init():
                    pygame.mixer.music.stop()
            except Exception:
                pass
            self._current_music_path = None
            return

        path_str = str(path)
        if path_str == self._current_music_path:
            # Same track already loaded and (presumably) playing — leave it alone
            return

        try:
            if not pygame.mixer.get_init():
                pygame.mixer.init()
            pygame.mixer.music.load(path_str)
            pygame.mixer.music.set_volume(0.6)
            pygame.mixer.music.play(-1)   # -1 → loop indefinitely
            self._current_music_path = path_str
        except Exception:
            # Missing file, unsupported codec, or no audio device — ignore
            self._current_music_path = None

    # ── Room entry ─────────────────────────────────────────────────────────────

    def enter_room(self, room_id: str, from_direction: str) -> None:
        state = self.state
        state.record_room_entry(room_id)
        state.current_room_id = room_id
        self._exit_grace = 0.4
        self.dialogue_runner = None

        # Notify the active style so it can clear trail / per-room state.
        active_style = self.bundle.room_styles.get(
            getattr(state, "active_tileset", ""), None
        )
        if active_style is not None:
            active_style.on_room_change()

        # Notify the active ability so it can rebuild vine/anchor cell sets.
        # Deferred until after layout is generated (below) — see _notify_ability_room_enter().

        room = state.game_def.graph.get(room_id)
        if room is None:
            raise ValueError(f"Unknown room: {room_id!r}")

        if room_id in state._layout_cache:
            self.layout = state._layout_cache[room_id]
        else:
            if room.platform_layer is not None:
                density = state.get_fill_density(room_id)
                self.layout = generate_layout(
                    room.platform_layer.eligibility,
                    seed=room.platform_layer.seed,
                    fill_density=density,
                    min_fill=room.platform_layer.min_fill,
                )
            else:
                from engine.room_graph import EligibilityLayer
                self.layout = generate_layout(
                    EligibilityLayer(), seed=0, fill_density=0.0
                )
            state._layout_cache[room_id] = self.layout

        # Center spawn for start room; otherwise come from the exit direction
        spawn_dir = "center" if room_id == state.game_def.start_room_id else from_direction
        px, py = spawn_position_from_direction(spawn_dir)
        self.player = PlayerEntity(px, py)

        self.npcs = [
            NPCEntity(n.npc_id, n.col, n.row)
            for n in state.game_def.npcs_in_room(room_id)
        ]

        self.objectives = []
        for npc_def in state.game_def.npcs:
            if (npc_def.objective is not None
                    and npc_def.objective.room_id == room_id
                    and not state.is_npc_solved(npc_def.npc_id)):
                self.objectives.append(
                    ObjectiveEntity(npc_def.npc_id,
                                    npc_def.objective.col,
                                    npc_def.objective.row)
                )

        self._play_music_for_tileset()

        # Now that layout is set, inform the active ability about the new room.
        self._notify_ability_room_enter()

    def _notify_ability_room_enter(self) -> None:
        """
        Tell the active ruleset's ability about the new room layout.

        Called after both layout generation and tileset resolution so the
        ability can build its climbable-cell set from the art provider's
        air-layout data.  The deco_map is requested directly from the art
        provider rather than the renderer's cache so the ability has it
        immediately on the first frame (before the renderer draws anything).
        """
        tileset_id = getattr(self.state, "active_tileset", "")
        ruleset    = self.bundle.rulesets.get(tileset_id)
        if ruleset is None or ruleset.ability is None or self.layout is None:
            return
        art = self.bundle.tilesets.get(tileset_id) or self.bundle.art
        if art is not None and hasattr(art, "air_layout"):
            from engine.room_graph import ROOM_COLS, ROOM_ROWS
            deco_map = art.air_layout(
                self.layout.solid_tiles, ROOM_COLS, ROOM_ROWS, self.layout.seed
            )
        else:
            deco_map = {}
        ruleset.ability.on_room_enter(self.layout, deco_map)

    # ── Update ─────────────────────────────────────────────────────────────────

    def update(
        self,
        dt: float,
        keys: pygame.key.ScancodeWrapper,
        jump_pressed: bool,
        joy_move: float = 0.0,
    ) -> None:
        self.renderer.tick_flash(dt)
        exhausted = self.state.tick_fatigue(dt)
        if exhausted:
            self._reset_to_start()
            return

        if self.player is None or self.layout is None:
            return

        self._exit_grace = max(0.0, self._exit_grace - dt)

        # Updraft physics are only active in the Escher tileset.
        # Other tilesets clear in_updraft each frame so zones exert no force.
        active_ts = getattr(self.state, "active_tileset", "")
        updraft_active = (active_ts == "escher_foyer")

        self.player.body.update(
            dt, keys, self.layout, jump_pressed,
            joy_move=joy_move, updraft_active=updraft_active,
        )

        # Track horizontal facing from velocity — persists while idle (last direction).
        if self.player.body.vx > 0:
            self.player.facing_right = True
        elif self.player.body.vx < 0:
            self.player.facing_right = False

        # Update active room style (mannequin walk phase, ghost trail, fatigue).
        active_style = self.bundle.room_styles.get(
            getattr(self.state, "active_tileset", ""), None
        )
        if active_style is not None:
            active_style.update(dt, self.player, self.state, layout=self.layout)

        # Update active ruleset ability (vine climb, etc.) — runs after physics
        # so it can correct vy/vine_anchor for next frame.
        active_ruleset = self.bundle.rulesets.get(
            getattr(self.state, "active_tileset", ""), None
        )
        if active_ruleset and active_ruleset.ability:
            active_ruleset.ability.update(
                dt, self.player, self.state, self.layout, jump_pressed
            )

        for npc in self.npcs:
            npc.update_proximity(self.player)

        for obj in self.objectives:
            if obj.check_collect(self.player):
                self._on_objective_collected(obj.obj_id)

        self._check_exit()

    def update_fatigue_only(self, dt: float) -> None:
        """Tick fatigue while dialogue is open; reset if expired."""
        self.renderer.tick_flash(dt)
        exhausted = self.state.tick_fatigue(dt)
        if exhausted:
            self.dialogue_runner = None
            self._reset_to_start()

    # ── Interaction ────────────────────────────────────────────────────────────

    def try_interact(self) -> None:
        if not self.npcs or self.player is None:
            return
        nearest = min(self.npcs, key=lambda n: (
            abs(self.player.body.center_x - n.px) +
            abs(self.player.body.center_y - n.py)
        ))
        if not nearest.near_player:
            return
        tree = self.bundle.dialogue_trees.get(nearest.npc_id)
        if tree is None:
            return
        self.dialogue_runner = DialogueRunner(tree, self.state)

    def cycle_tileset(self) -> None:
        """
        Advance state.active_tileset to the next entry in bundle.tileset_cycle
        that the player has unlocked.

        "fallback" is always treated as unlocked — it maps to bundle.art
        (the base procedural provider) and is never gated behind an NPC.
        Any other id must appear in state.unlocked_tilesets to be included.
        """
        cycle = self.bundle.tileset_cycle
        if not cycle:
            return
        available = [
            tid for tid in cycle
            if tid == "fallback" or tid in self.state.unlocked_tilesets
        ]
        if len(available) < 2:
            return   # nothing to cycle to
        try:
            idx = available.index(self.state.active_tileset)
        except ValueError:
            idx = -1
        prev_tileset = self.state.active_tileset
        self.state.active_tileset = available[(idx + 1) % len(available)]

        # Deactivate previous ability so it can release physics state (vine_anchor etc.)
        prev_ruleset = self.bundle.rulesets.get(prev_tileset)
        if prev_ruleset and prev_ruleset.ability and self.player:
            prev_ruleset.ability.on_ruleset_deactivate(self.player)

        # Clear the newly-active style's trail so no artifacts from the old tileset
        new_style = self.bundle.room_styles.get(self.state.active_tileset)
        if new_style is not None:
            new_style.on_room_change()
        # Notify new ability about the current room layout
        self._notify_ability_room_enter()

        # Show a banner so the player can see which tileset is now active
        ts_id   = self.state.active_tileset
        ts_name = self.bundle.tileset_display_names.get(ts_id) or ts_id.replace("_", " ").title()
        pos     = available.index(ts_id) + 1
        self.renderer.show_flash(f"{ts_name}  [{pos}/{len(available)}]")
        self._play_music_for_tileset()

    def _on_objective_collected(self, npc_id: str) -> None:
        self.state.solve_npc(npc_id)
        self.state._layout_cache.clear()
        # Open the NPC's tree at its solved root so the player gets feedback
        tree = self.bundle.dialogue_trees.get(npc_id)
        if tree:
            self.dialogue_runner = DialogueRunner(tree, self.state)

    # ── Exit transitions ───────────────────────────────────────────────────────

    def _check_exit(self) -> None:
        if self.player is None or self._exit_grace > 0:
            return
        state = self.state
        room = state.game_def.graph.get(state.current_room_id)
        if not room:
            return

        px = self.player.body.px
        py = self.player.body.py
        pcol = self.player.col
        prow = self.player.row
        floor_row = ROOM_ROWS - 3

        for ex in room.exits:
            if not state.is_gate_open(ex.gate_id):
                continue
            triggered = False

            if ex.direction == "west":
                triggered = px <= TILE_W + TRANSITION_MARGIN_PX
            elif ex.direction == "east":
                triggered = px >= SCREEN_W - TILE_W * 2 - PLAYER_W - TRANSITION_MARGIN_PX
            elif ex.direction == "upper_west":
                triggered = (px <= TILE_W + TRANSITION_MARGIN_PX
                             and py < (floor_row - 4) * TILE_H)
            elif ex.direction == "upper_east":
                triggered = (px >= SCREEN_W - TILE_W * 2 - PLAYER_W - TRANSITION_MARGIN_PX
                             and py < (floor_row - 4) * TILE_H)
            elif ex.trigger_col is not None and ex.trigger_row is not None:
                triggered = (abs(pcol - ex.trigger_col) <= 1
                             and abs(prow - ex.trigger_row) <= 1)

            if triggered:
                entry_map = {
                    "west": "east", "east": "west",
                    "upper_west": "upper_east", "upper_east": "upper_west",
                    "north": "south", "south": "north",
                }
                self.enter_room(ex.to_room, entry_map.get(ex.direction, "east"))
                return

    def _reset_to_start(self) -> None:
        self.state.reset_fatigue()
        self.enter_room(self.state.game_def.start_room_id, from_direction="center")

    # ── Draw ───────────────────────────────────────────────────────────────────

    def draw(self, surface: pygame.Surface, tick: int) -> None:
        if self.layout is None or self.player is None:
            return
        self.renderer.draw(
            surface,
            layout=self.layout,
            player=self.player,
            npcs=self.npcs,
            objectives=self.objectives,
            state=self.state,
            tick=tick,
            dialogue_runner=self.dialogue_runner,
        )
