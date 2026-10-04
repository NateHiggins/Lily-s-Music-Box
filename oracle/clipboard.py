"""Put text on the system clipboard, using only what the system already has.

Windows has `clip`, macOS has `pbcopy`, and a Linux desktop has one of `wl-copy`,
`xclip` or `xsel`. Nothing is installed and nothing is imported beyond the
standard library. If no tool is present the caller is told so, and the prompt is
still on the screen and in its file.
"""

from __future__ import annotations

import codecs
import os
import shutil
import subprocess
import sys

TIMEOUT = 8.0


def _candidates(platform: str, which) -> list[tuple[str, list[str], str]]:
    """(name, command, encoding) in the order they should be tried."""
    out: list[tuple[str, list[str], str]] = []
    if platform.startswith("win") or which("clip.exe"):
        # clip reads the console code page unless the input starts with a UTF-16 byte order
        # mark, so the text is sent as UTF-16 and arrives whole whatever it contains.
        tool = which("clip") or which("clip.exe")
        if tool:
            out.append(("clip", [tool], "utf-16"))
    if platform == "darwin" and which("pbcopy"):
        out.append(("pbcopy", [which("pbcopy")], "utf-8"))
    if platform.startswith(("linux", "freebsd")):
        if os.environ.get("WAYLAND_DISPLAY") and which("wl-copy"):
            out.append(("wl-copy", [which("wl-copy")], "utf-8"))
        if which("xclip"):
            out.append(("xclip", [which("xclip"), "-selection", "clipboard"], "utf-8"))
        if which("xsel"):
            out.append(("xsel", [which("xsel"), "--clipboard", "--input"], "utf-8"))
        if which("wl-copy") and not os.environ.get("WAYLAND_DISPLAY"):
            out.append(("wl-copy", [which("wl-copy")], "utf-8"))
    return out


def available(platform: str | None = None, which=shutil.which) -> str | None:
    """The name of the tool that would be used, or None."""
    found = _candidates(platform or sys.platform, which)
    return found[0][0] if found else None


def copy(text: str, platform: str | None = None, which=shutil.which, run=subprocess.run) -> tuple[bool, str]:
    """Copy `text` to the clipboard. Returns (done, how): the tool that did it, or why not."""
    platform = platform or sys.platform
    tools = _candidates(platform, which)
    if not tools:
        return False, "no clipboard tool was found on this computer"
    problems: list[str] = []
    for name, command, encoding in tools:
        payload = text.replace("\r\n", "\n")
        if name == "clip":
            payload = payload.replace("\n", "\r\n")      # what Windows programs expect on paste
        env = dict(os.environ)
        if name == "pbcopy":
            env["LC_CTYPE"] = "UTF-8"
        if encoding == "utf-16":
            data = codecs.BOM_UTF16_LE + payload.encode("utf-16-le")
        else:
            data = payload.encode(encoding)
        try:
            done = run(command, input=data, env=env, timeout=TIMEOUT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (OSError, subprocess.SubprocessError) as exc:
            problems.append(f"{name}: {exc}")
            continue
        if getattr(done, "returncode", 1) == 0:
            return True, name
        problems.append(f"{name}: exit {getattr(done, 'returncode', '?')}")
    return False, "; ".join(problems)
