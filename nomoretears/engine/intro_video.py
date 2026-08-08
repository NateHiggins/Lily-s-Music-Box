"""
engine/intro_video.py
---------------------
Full-screen intro-video player using ffpyplayer.

Plays a video file (any format ffmpeg supports — mp4, webm, etc.) at the
correct frame rate with synchronised audio, scaled to fill the screen with
black letterbox/pillarbox bars.  The player is skippable with any key press
or mouse click; it also exits cleanly on QUIT events.

Usage
-----
    from engine.intro_video import play_intro_video
    play_intro_video(screen, clock, "/path/to/video.mp4")

If ffpyplayer is not installed, or the file does not exist, the call is a
silent no-op so the game always starts even in degraded environments.

Sync strategy
─────────────
ffpyplayer returns each frame with a pts (presentation timestamp in seconds).
We compute the wall-clock time at which each frame should appear and busy-wait
in small slices (capped at TARGET_FPS so the event queue stays responsive).
Audio is handled internally by ffpyplayer; no extra work required.
"""
from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import pygame


TARGET_FPS = 60          # event-poll rate while video plays
SKIP_FADE_MS = 300       # black-out duration after skip before returning


def play_intro_video(
    screen: "pygame.Surface",
    clock: "pygame.time.Clock",
    video_path: str | Path,
) -> None:
    """
    Play *video_path* full-screen with audio until it ends or the player skips.

    Parameters
    ----------
    screen      : the active pygame display surface (any size; video is scaled).
    clock       : the caller's Clock — used only for the post-video fade tick.
    video_path  : absolute path to the video file.

    The function returns as soon as the video ends or the user skips.  The
    display is left fully black so the caller can fade in cleanly.
    """
    try:
        from ffpyplayer.player import MediaPlayer   # type: ignore[import]
    except ModuleNotFoundError:
        return   # degraded: no ffpyplayer, skip silently

    import pygame
    import time

    path = Path(video_path)
    if not path.exists():
        return

    screen_w, screen_h = screen.get_size()

    # Open the media file.  ff_opts mute the player's own logging.
    player = MediaPlayer(str(path), ff_opts={"paused": False, "af": "aresample=44100"})

    # Pre-roll: wait for the first real frame so we can measure aspect ratio.
    frame = None
    img_size = None
    for _ in range(300):                    # up to ~5 s of patience
        frame, val = player.get_frame()
        if val == "eof":
            player.close_player()
            return
        if frame is not None:
            img_size = frame[0].get_size()  # (width, height) in pixels
            break
        time.sleep(0.01)

    if img_size is None:
        player.close_player()
        return

    vid_w, vid_h = img_size

    # Compute letterbox/pillarbox destination rect (maintain aspect ratio).
    scale      = min(screen_w / vid_w, screen_h / vid_h)
    dst_w      = round(vid_w * scale)
    dst_h      = round(vid_h * scale)
    dst_x      = (screen_w - dst_w) // 2
    dst_y      = (screen_h - dst_h) // 2
    dst_rect   = (dst_x, dst_y)

    def _show_frame(f: tuple) -> None:
        """Convert an ffpyplayer frame into a pygame blit."""
        img, _pts = f
        raw      = bytes(img.to_bytearray()[0])   # plane 0 = packed RGB bytes
        img_surf = pygame.image.frombuffer(raw, (vid_w, vid_h), "RGB")
        if scale != 1.0:
            img_surf = pygame.transform.scale(img_surf, (dst_w, dst_h))
        screen.fill((0, 0, 0))
        screen.blit(img_surf, dst_rect)
        pygame.display.flip()

    # Wall-clock reference: t=0 corresponds to pts=0.
    t_start = time.perf_counter()

    # Show the pre-rolled first frame immediately (pts ≈ 0).
    if frame is not None:
        _show_frame(frame)

    # pending_frame holds the next frame waiting for its display time.
    # We fetch one frame at a time and hold it until wall-clock ≥ pts,
    # then show it and fetch the next.  This keeps video in lockstep with
    # the audio track (which ffpyplayer plays independently at real-time).
    pending_frame: tuple | None = None
    pending_pts:   float        = 0.0

    running = True
    while running:
        # ── Event handling ─────────────────────────────────────────────────────
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type in (pygame.KEYDOWN, pygame.MOUSEBUTTONDOWN):
                running = False

        if not running:
            break

        now = time.perf_counter() - t_start

        # ── Fetch next frame if we don't have one waiting ──────────────────────
        if pending_frame is None:
            frame, val = player.get_frame()
            if val == "eof":
                break
            if frame is not None:
                img, pts    = frame
                pending_frame = frame
                pending_pts   = float(pts)

        # ── Display the pending frame once wall-clock catches up to its pts ────
        if pending_frame is not None and now >= pending_pts:
            _show_frame(pending_frame)
            pending_frame = None

        clock.tick(TARGET_FPS)              # yield to OS; audio thread keeps running

    player.close_player()

    # Brief black frame so the transition to the game isn't a hard cut.
    screen.fill((0, 0, 0))
    pygame.display.flip()
    clock.tick(TARGET_FPS)   # one tick to let audio wind down


def video_path_for_module(module_path: str, video_name: str = "introvideo.mp4") -> Path:
    """
    Resolve a video file path from a dotted module path and a filename.

    Looks for:
        <repo_root>/<module_path_as_dir>/prerenderedVideo/<video_name>

    Returns a Path regardless of whether the file exists — callers should
    check .exists() or let play_intro_video handle the missing-file case.
    """
    from pathlib import Path
    import sys

    repo_root = Path(sys.argv[0]).resolve().parent
    rel       = Path(*module_path.split("."))   # games/lilys_music_box
    return repo_root / rel / "prerenderedVideo" / video_name
