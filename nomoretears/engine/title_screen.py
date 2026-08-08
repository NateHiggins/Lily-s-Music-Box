"""
engine/title_screen.py
-----------------------
WarGames-style phosphor-terminal title screen.

Boot phase:  typewriter text scrolls in line by line.
Menu phase:  module list is interactive — arrow keys / numbers navigate,
             Enter / number key launches.
             Coming-soon items are shown but are unselectable.

Fix for readability: each boot line is tagged with a type. The renderer
uses type to set color, and _draw_menu clears and redraws the selected
row cleanly (no double-render). Stored module_y_positions are populated
during _draw so _draw_menu can place the overlay at the exact right pixel.
"""
from __future__ import annotations

import datetime
import importlib
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import pygame

# ── Palette ────────────────────────────────────────────────────────────────────

P_BG         = (  0,   0,   0)
P_BRIGHT     = (200, 255, 210)   # selected / highlight
P_NORMAL     = (  0, 210,  50)   # main text
P_DIM        = (  0, 110,  28)   # secondary / separators
P_VERY_DIM   = (  0,  65,  18)   # coming-soon items
P_CURSOR     = (  0, 255,  65)   # blinking block
P_GLOW       = (  0, 180,  45)   # ghost copy offset for bloom

from engine.room_graph import TILE_W, TILE_H, ROOM_COLS, ROOM_ROWS, TILE_SCALE
SCREEN_W  = ROOM_COLS * TILE_W
SCREEN_H  = ROOM_ROWS * TILE_H
FONT_SIZE    = round(18 * TILE_SCALE)   # 68 at 4K
SMALL_SIZE   = round(14 * TILE_SCALE)   # 52 at 4K
CHAR_DELAY   = 0.026   # seconds per character
LINE_PAUSE   = 0.18    # pause after each complete line

# ── Line type tags ────────────────────────────────────────────────────────────

_NORMAL      = "normal"
_MOD_TITLE   = "mod_title"    # selectable module — title row
_MOD_PATH    = "mod_path"     # selectable module — path row (dim)
_SOON_TITLE  = "soon_title"   # coming-soon — title row (very dim)
_SOON_PATH   = "soon_path"    # coming-soon — path row (very dim)
_SEP         = "sep"          # separator line
_EMPTY       = "empty"


def _color_for_type(tag: str) -> tuple:
    return {
        _NORMAL:     P_NORMAL,
        _MOD_TITLE:  P_DIM,        # dim by default; selected row overrides to P_BRIGHT
        _MOD_PATH:   P_VERY_DIM,
        _SOON_TITLE: P_VERY_DIM,
        _SOON_PATH:  P_VERY_DIM,
        _SEP:        P_DIM,
        _EMPTY:      P_NORMAL,
    }.get(tag, P_NORMAL)


# ── Title music config ────────────────────────────────────────────────────────

@dataclass
class TitleMusicConfig:
    """
    Two-track title screen music sequence.

    intro_path       — played first, starting at intro_start_sec.
    intro_start_sec  — offset (seconds) into the intro file where playback begins.
                       Frame 0 of the title screen = this point in the track.
    play_duration    — how many seconds of the intro to play before fading.
                       The fade starts exactly play_duration seconds after play().
    loop_path        — loaded and looped (in full, from its beginning) after fade.
    loop_volume      — mixer volume for the loop track (0.0–1.0).
    crossfade_sec    — duration of the fadeout that bridges intro → loop.
    """
    intro_path:      str
    intro_start_sec: float = 10.0
    play_duration:   float = 15.0
    loop_path:       str   = ""
    loop_volume:     float = 0.5
    crossfade_sec:   float = 5.0


# ── Module discovery ──────────────────────────────────────────────────────────

def discover_modules(games_dir: Path) -> list[tuple[str, str]]:
    """Return [(module_path, display_title)] for every loadable game module."""
    results: list[tuple[str, str]] = []
    if not games_dir.is_dir():
        return results
    for child in sorted(games_dir.iterdir()):
        if not child.is_dir() or not (child / "__init__.py").exists():
            continue
        module_path = f"games.{child.name}"
        try:
            mod = importlib.import_module(module_path)
        except Exception:
            continue
        if not hasattr(mod, "load"):
            continue
        title = getattr(mod, "TITLE", child.name.replace("_", " ").upper())
        results.append((module_path, title))
    return results


# ── Coming-soon catalogue ─────────────────────────────────────────────────────

# Add future games here.  They appear on screen but are never selectable.
COMING_SOON: list[tuple[str, str]] = [
    ("GLOBAL THERMONUCLEAR WAR", "CLASSIFIED"),
]


# ── Glow text helper ──────────────────────────────────────────────────────────

def _blit_glow(
    surface: pygame.Surface,
    font: pygame.font.Font,
    text: str,
    color: tuple,
    glow_color: tuple,
    pos: tuple[int, int],
) -> None:
    if not text.strip():
        return
    ghost = font.render(text, True, glow_color)
    ghost.set_alpha(50)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        surface.blit(ghost, (pos[0] + dx, pos[1] + dy))
    surface.blit(font.render(text, True, color), pos)


# ── Static overlays ───────────────────────────────────────────────────────────

def _make_scanlines(width: int, height: int) -> pygame.Surface:
    surf = pygame.Surface((width, height), pygame.SRCALPHA)
    for y in range(0, height, 3):
        pygame.draw.line(surf, (0, 0, 0, 70), (0, y), (width, y))
    return surf


def _make_vignette(width: int, height: int) -> pygame.Surface:
    surf = pygame.Surface((width, height), pygame.SRCALPHA)
    cx, cy = width // 2, height // 2
    steps = 60
    for i in range(steps, 0, -1):
        frac = i / steps
        alpha = int((1.0 - frac) ** 2 * 110)
        rx = int(cx * frac)
        ry = int(cy * frac)
        pygame.draw.ellipse(surf, (0, 0, 0, alpha),
                            (cx - rx, cy - ry, rx * 2, ry * 2), 2)
    return surf


# ── Title screen ──────────────────────────────────────────────────────────────

class TitleScreen:
    """
    Show the WarGames-style terminal screen and return the chosen module path,
    or None if the user quits.

    Usage:
        result = TitleScreen(games_dir).run(screen, clock)
    """

    _HEADER = [
        r" ███╗   ██╗ ██████╗ ███╗   ███╗ ██████╗ ██████╗ ███████╗",
        r" ████╗  ██║██╔═══██╗████╗ ████║██╔═══██╗██╔══██╗██╔════╝",
        r" ██╔██╗ ██║██║   ██║██╔████╔██║██║   ██║██████╔╝█████╗  ",
        r" ██║╚██╗██║██║   ██║██║╚██╔╝██║██║   ██║██╔══██╗██╔══╝  ",
        r" ██║ ╚████║╚██████╔╝██║ ╚═╝ ██║╚██████╔╝██║  ██║███████╗",
        r" ╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝",
        r"  T E A R S   ·   P L A T F O R M   A D V E N T U R E",
    ]

    def __init__(
        self,
        games_dir: Path,
        title_music: "TitleMusicConfig | None" = None,
    ) -> None:
        self.games_dir      = games_dir
        self.title_music    = title_music
        self.modules:        list[tuple[str, str]] = []
        # Populated by _draw each frame — y pixel of each selectable module's title row
        self._module_ys:     list[int] = []
        self._font:          pygame.font.Font | None = None
        self._small:         pygame.font.Font | None = None
        self._scanlines:     pygame.Surface | None = None
        self._vignette:      pygame.Surface | None = None

    # ── Public entry ──────────────────────────────────────────────────────────

    def run(self, screen: pygame.Surface, clock: pygame.time.Clock) -> str | None:
        self._font      = pygame.font.SysFont("Courier New,Courier,monospace", FONT_SIZE, bold=True)
        self._small     = pygame.font.SysFont("Courier New,Courier,monospace", SMALL_SIZE)
        self._scanlines = _make_scanlines(SCREEN_W, SCREEN_H)
        self._vignette  = _make_vignette(SCREEN_W, SCREEN_H)

        self.modules  = discover_modules(self.games_dir)
        boot_lines    = self._make_boot_lines()

        phase         = "boot"
        typed:        list[tuple[str, str]] = []    # (text, tag) fully typed
        cur_text      = ""
        cur_tag       = _NORMAL
        line_idx      = 0
        char_idx      = 0
        char_timer    = 0.0
        line_pause    = 0.0
        selected      = 0
        launch_timer  = 0.0
        blink_timer   = 0.0
        blink_on      = True
        result: str | None = None

        # ── Music setup ───────────────────────────────────────────────────────
        # Simple sequential: play intro from intro_start_sec, then when it ends
        # load and loop the second track.  No fading, no Sound objects.
        _MUSIC_END  = pygame.USEREVENT + 10
        music_state = "idle"

        cfg = self.title_music
        if cfg and cfg.intro_path:
            try:
                if not pygame.mixer.get_init():
                    pygame.mixer.init()
                pygame.mixer.music.set_endevent(_MUSIC_END)
                pygame.mixer.music.load(cfg.intro_path)
                pygame.mixer.music.set_volume(1.0)
                pygame.mixer.music.play(0, start=cfg.intro_start_sec)
                music_state = "intro"
            except Exception:
                music_state = "idle"

        running = True
        while running:
            dt = min(clock.tick(60) / 1000.0, 0.05)
            blink_timer += dt
            if blink_timer >= 0.5:
                blink_timer = 0.0
                blink_on = not blink_on

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return None
                if event.type == _MUSIC_END and music_state == "intro":
                    # Intro finished — start looping the second track.
                    if cfg and cfg.loop_path:
                        try:
                            pygame.mixer.music.load(cfg.loop_path)
                            pygame.mixer.music.set_volume(cfg.loop_volume)
                            pygame.mixer.music.play(-1)
                            music_state = "loop"
                        except Exception:
                            music_state = "done"
                    else:
                        music_state = "done"
                if event.type == pygame.KEYDOWN:
                    if phase == "boot":
                        if event.key == pygame.K_ESCAPE:
                            return None
                        else:
                            # Any key skips boot animation
                            typed = list(boot_lines)
                            cur_text = ""
                            line_idx = len(boot_lines)
                            phase = "menu"
                    elif phase == "menu":
                        if event.key == pygame.K_ESCAPE:
                            return None
                        elif event.key in (pygame.K_UP, pygame.K_w):
                            selected = (selected - 1) % max(1, len(self.modules))
                        elif event.key in (pygame.K_DOWN, pygame.K_s):
                            selected = (selected + 1) % max(1, len(self.modules))
                        elif event.key == pygame.K_RETURN and self.modules:
                            result = self.modules[selected][0]
                            phase = "launch"
                        elif pygame.K_1 <= event.key <= pygame.K_9:
                            idx = event.key - pygame.K_1
                            if idx < len(self.modules):
                                result = self.modules[idx][0]
                                phase = "launch"

            # ── Phase updates ──────────────────────────────────────────────────

            if phase == "boot":
                if line_idx >= len(boot_lines):
                    phase = "menu"
                elif line_pause > 0:
                    line_pause -= dt
                    if line_pause <= 0:
                        typed.append((cur_text, cur_tag))
                        cur_text = ""
                        char_idx = 0
                        line_idx += 1
                else:
                    char_timer += dt
                    n = int(char_timer / CHAR_DELAY)
                    if n > 0:
                        char_timer -= n * CHAR_DELAY
                        if line_idx < len(boot_lines):
                            target_text, cur_tag = boot_lines[line_idx]
                            cur_text = target_text[:char_idx + n]
                            char_idx = len(cur_text)
                            if char_idx >= len(target_text):
                                line_pause = LINE_PAUSE

            elif phase == "launch":
                launch_timer += dt
                if launch_timer >= 1.2:
                    running = False

            # ── Music cleanup on launch ───────────────────────────────────────
            if music_state in ("intro", "loop") and phase == "launch" and launch_timer > 0.6:
                try:
                    pygame.mixer.music.fadeout(600)
                except Exception:
                    pass
                music_state = "done"

            # ── Draw ──────────────────────────────────────────────────────────
            self._draw(screen, phase, typed, cur_text, cur_tag,
                       selected, blink_on, launch_timer, result)
            pygame.display.flip()

        return result

    # ── Boot line construction ────────────────────────────────────────────────

    def _make_boot_lines(self) -> list[tuple[str, str]]:
        now = datetime.datetime.now()
        lines: list[tuple[str, str]] = [
            ("", _EMPTY),
            ("NOMOREATE/RS PLATFORM ENGINE  V0.1.0", _NORMAL),
            (f"SYSTEM DATE: {now.strftime('%Y-%m-%d  %H:%M:%S')}", _NORMAL),
            ("", _EMPTY),
            ("HELLO.", _NORMAL),
            ("", _EMPTY),
            ("AVAILABLE PROGRAMS:", _NORMAL),
            ("", _EMPTY),
        ]

        if self.modules:
            for i, (path, title) in enumerate(self.modules):
                lines.append((f"  [{i + 1}]  {title}", _MOD_TITLE))
                lines.append((f"        {path}", _MOD_PATH))
                lines.append(("", _EMPTY))
        else:
            lines.append(("  NO MODULES FOUND IN games/", _NORMAL))
            lines.append(("", _EMPTY))

        lines.append(("─" * 54, _SEP))
        lines.append(("", _EMPTY))

        if COMING_SOON:
            lines.append(("COMING SOON:", _VERY_DIM_LABEL := _SOON_TITLE))
            lines.append(("", _EMPTY))
            for title, path in COMING_SOON:
                lines.append((f"  [ ]  {title}", _SOON_TITLE))
                lines.append((f"        {path}", _SOON_PATH))
                lines.append(("", _EMPTY))
            lines.append(("─" * 54, _SEP))
            lines.append(("", _EMPTY))

        lines += [
            ("SHALL WE PLAY A GAME?", _NORMAL),
            ("", _EMPTY),
        ]
        return lines

    # ── Draw ─────────────────────────────────────────────────────────────────

    def _draw(
        self,
        screen: pygame.Surface,
        phase: str,
        typed: list[tuple[str, str]],
        cur_text: str,
        cur_tag: str,
        selected: int,
        blink_on: bool,
        launch_timer: float,
        result: str | None,
    ) -> None:
        screen.fill(P_BG)

        font  = self._font
        small = self._small
        lh    = font.get_height() + 3
        hx    = 20

        # ── ASCII header ──────────────────────────────────────────────────────
        hy = 14
        for i, hline in enumerate(self._HEADER):
            color = P_DIM if i < len(self._HEADER) - 1 else P_NORMAL
            _blit_glow(screen, small, hline, color, P_GLOW, (hx, hy + i * (SMALL_SIZE + 2)))
        header_bottom = hy + len(self._HEADER) * (SMALL_SIZE + 2) + 8
        _blit_glow(screen, small, "═" * 64, P_DIM, P_GLOW, (hx, header_bottom))
        content_top = header_bottom + SMALL_SIZE + 8

        # ── Typed lines ───────────────────────────────────────────────────────
        max_vis = (SCREEN_H - content_top - 50) // lh
        all_lines = typed + ([(cur_text, cur_tag)] if cur_text is not None else [])
        visible   = all_lines[-max_vis:]

        self._module_ys = []   # reset; populated below for selectable entries

        # Track which visible lines correspond to which selectable module index
        # so we can look up exact y positions in _draw_menu.
        mod_idx_counter = 0
        # Compute how many typed lines precede the visible window
        skip = len(all_lines) - len(visible)

        ty = content_top
        for vi, (text, tag) in enumerate(visible):
            global_idx = skip + vi

            # Record y for selectable module title rows
            if tag == _MOD_TITLE:
                self._module_ys.append(ty)

            color = _color_for_type(tag)

            # In menu phase, selected module title is rendered bright —
            # but only if this is the selected one. The actual clearing + redraw
            # happens in _draw_menu; here we just skip to avoid double paint.
            is_selected_title = (
                phase == "menu"
                and tag == _MOD_TITLE
                and len(self._module_ys) - 1 == selected
            )
            if not is_selected_title:
                _blit_glow(screen, font, text, color, P_GLOW, (hx + 10, ty))

            ty += lh

        # Blinking cursor
        if phase in ("boot", "menu") and blink_on:
            cursor_x = hx + 10 + (font.size(cur_text)[0] if cur_text else 0)
            pygame.draw.rect(screen, P_CURSOR, (cursor_x, ty - lh + 2, 10, lh - 4))

        # ── Selection overlay ─────────────────────────────────────────────────
        if phase == "menu" and self.modules and selected < len(self._module_ys):
            self._draw_selection(screen, font, selected, hx, lh)

        # ── Launch flash ──────────────────────────────────────────────────────
        if phase == "launch" and result:
            _, title = next((m for m in self.modules if m[0] == result), (result, result))
            msg = f"LOADING  {title} ..."
            txt_surf = font.render(msg, True, P_BRIGHT)
            bx = SCREEN_W // 2 - txt_surf.get_width() // 2
            by = SCREEN_H // 2 - txt_surf.get_height() // 2
            pad = pygame.Surface((txt_surf.get_width() + 40, txt_surf.get_height() + 20),
                                 pygame.SRCALPHA)
            pad.fill((0, 0, 0, 230))
            screen.blit(pad, (bx - 20, by - 10))
            _blit_glow(screen, font, msg, P_BRIGHT, P_GLOW, (bx, by))

        # ── Status bar ────────────────────────────────────────────────────────
        if phase != "launch":
            hint = "↑↓ SELECT    ENTER CONFIRM    1-9 SHORTCUT    ESC QUIT"
            hs = small.render(hint, True, P_DIM)
            screen.blit(hs, (SCREEN_W // 2 - hs.get_width() // 2, SCREEN_H - 22))

        # ── CRT overlays ──────────────────────────────────────────────────────
        screen.blit(self._scanlines, (0, 0))
        screen.blit(self._vignette, (0, 0))

    def _draw_selection(
        self,
        screen: pygame.Surface,
        font: pygame.font.Font,
        selected: int,
        hx: int,
        lh: int,
    ) -> None:
        """
        Cleanly draw the selected module row.
        Clears the original dim text first, then redraws bright with arrow.
        """
        sel_y = self._module_ys[selected]
        box_w = SCREEN_W - hx * 2 - 8

        # 1. Erase the dim text the main loop drew (skipped above) — belt-and-suspenders
        pygame.draw.rect(screen, P_BG, (hx + 4, sel_y, box_w, lh))

        # 2. Subtle green highlight background
        hi = pygame.Surface((box_w, lh), pygame.SRCALPHA)
        hi.fill((*P_NORMAL, 22))
        screen.blit(hi, (hx + 4, sel_y))

        # 3. Border
        pygame.draw.rect(screen, P_DIM, (hx + 4, sel_y, box_w, lh), 1)

        # 4. Arrow
        arrow_surf = font.render("▶", True, P_BRIGHT)
        screen.blit(arrow_surf, (hx + 10, sel_y))
        arrow_w = arrow_surf.get_width() + 4

        # 5. Bright module text (no duplicate prefix — just title)
        _, title = self.modules[selected]
        idx = selected
        label = f"[{idx + 1}]  {title}"
        _blit_glow(screen, font, label, P_BRIGHT, P_GLOW, (hx + 10 + arrow_w, sel_y))
