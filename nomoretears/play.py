"""
play.py — NoMoreTears platform engine launcher.

Usage:
    python play.py                        # show module selector, then run chosen game
    python play.py games.lilys_music_box  # skip selector, run directly

In-game controls:
    Arrow keys / WASD  — move
    Space / W / Up     — jump  (or advance linear dialogue)
    E                  — interact with NPC  /  dismiss dialogue
    1 2 3 4            — select dialogue choice
    Escape             — dismiss dialogue  /  quit to title

Title-screen controls:
    ↑ ↓                — navigate modules
    Enter              — launch selected module
    1 2 3 …            — shortcut by index
    Escape             — quit
"""
import sys
from pathlib import Path


def main() -> None:
    import pygame
    pygame.init()
    pygame.font.init()

    from engine.title_screen import TitleScreen, TitleMusicConfig, SCREEN_W, SCREEN_H
    from engine.loader import load_module
    from engine.core import Engine

    # SCALED: pygame renders at the logical 3840×2160 resolution and
    # scales it down to fit whatever window/display size is available.
    # No FULLSCREEN flag keeps it in a normal desktop window.
    screen = pygame.display.set_mode((SCREEN_W, SCREEN_H), pygame.SCALED)
    pygame.display.set_caption("NOMOREATE/RS ENGINE")
    clock = pygame.time.Clock()

    games_dir = Path(__file__).parent / "games"

    # Parse args: optional module path, optional --dev flag
    args = sys.argv[1:]
    dev_mode    = "--dev" in args
    module_args = [a for a in args if not a.startswith("--")]

    if module_args:
        module_path = module_args[0]
    else:
        # Build title-screen music config from Lily's music folder.
        # Paths are checked before constructing so a missing file degrades
        # silently rather than crashing on startup.
        _music_dir = games_dir / "lilys_music_box" / "music"
        _intro     = _music_dir / "The_Last_Carriage_Return.ogg"
        _loop      = _music_dir / "Cold_Boot.ogg"
        title_music = TitleMusicConfig(
            intro_path      = str(_intro),
            intro_start_sec = 10.0,   # frame 0 = 10 s into the track
            play_duration   = 15.0,   # play for 15 s, then begin fade
            loop_path       = str(_loop),
            loop_volume     = 0.5,
            crossfade_sec   = 5.0,    # 5 s fade before Cold Boot takes over
        ) if _intro.exists() and _loop.exists() else None

        module_path = TitleScreen(games_dir, title_music=title_music).run(screen, clock)

    if module_path is None:
        pygame.quit()
        return

    bundle = load_module(module_path, dev_mode=dev_mode)

    # Play the game's intro video (if one exists) before the game loop starts.
    # Skippable with any key or mouse click; silent no-op if file is missing.
    from engine.intro_video import play_intro_video, video_path_for_module
    play_intro_video(screen, clock, video_path_for_module(module_path))

    Engine(bundle).run(screen=screen, clock=clock)


if __name__ == "__main__":
    main()
