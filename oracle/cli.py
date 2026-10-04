"""Command line for THE BLANK DECK.

    python -m oracle                 play a night; it ends by handing you a prompt
    python -m oracle resume          take up the last unfinished night
    python -m oracle prompt          a finished night's prompt again: print it, copy it, save it
    python -m oracle list            the nights kept on this computer
    python -m oracle forget          erase them
    python -m oracle dev             write the developer view of a night
    python -m oracle profile         a finished night's design profile, as data
    python -m oracle simulate        play simulated players through whole nights
    python -m oracle doctor          check the content and this computer
    python -m oracle bundle          write this whole program as one file

The program needs nothing but Python. A night is played from the authored rooms
unless a model is asked for with --narrator.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import webbrowser
from pathlib import Path

from . import __version__, clipboard
from .backends import AutoBackend, Backend, BackendError, detect, make_backend
from .bundle import DEFAULT_NAME, BundleError, build_bundle, running_bundle
from .content import ContentError, coverage_report, load_registry
from .devview import write_devview
from .engine import Engine
from .model import PlayerModel
from .prompt import (MANUAL_NAME, PROMPT_FILE, REFERENCE_DIR, PromptError, build_prompt, find_manual,
                     prepare_project, save_prompt, word_count)
from .session import Session, data_dir, forget, latest_session, list_sessions
from .synthesis import build_profile, synthesize
from .ui import Console

COMMANDS = ("play", "resume", "prompt", "list", "forget", "dev", "profile", "simulate", "doctor", "bundle")
NARRATORS = ("offline", "auto", "anthropic", "claude", "codex", "command")

TITLE = "T H E   B L A N K   D E C K"
LAYING_OUT = ("The Proprietor turns the deck face down, cuts it once, and begins to lay the cards out between "
              "you, slowly, in a pattern you do not recognise.")


RUN_AS = ""        # set by __main__ when the program is started as a folder: python path/to/oracle


def _quoted(name: str) -> str:
    return f'"{name}"' if " " in name else name


def invocation() -> str:
    """How this copy of the program was started, for the lines that tell the player what to type:
    the same interpreter, and the same file or folder, as they gave."""
    python = Path(sys.executable).stem if sys.executable else ""
    if not python.lower().startswith("python"):
        python = "python"
    if running_bundle() is not None:
        started = sys.argv[0] if sys.argv and sys.argv[0] else running_bundle().name
        return f"{python} {_quoted(started)}"
    if RUN_AS:
        return f"{python} {_quoted(RUN_AS)}"
    return f"{python} -m oracle"


def help_text(kept: bool = True) -> str:
    leaving = (f"Type quit to leave; the house keeps your place and `{invocation()} resume` returns you to it."
               if kept else "Type quit to leave; this night is not being kept, so leaving ends it.")
    return ("Type what you do, in your own words: look at things, talk, take, try. There is no list of "
            f"commands. If the house does not follow you, ask it for a hint. {leaving}")


# ---------------------------------------------------------------------------
# Who narrates
# ---------------------------------------------------------------------------

def choose_narrator(args, ui) -> Backend | None:
    """None means the house speaks from the page, which is the default and needs nothing.
    A model narrates only when one was asked for by name, or with `auto`."""
    name = getattr(args, "narrator", "offline") or "offline"
    model = getattr(args, "model", None)
    if name == "offline":
        return None
    if name == "auto":
        auto = AutoBackend(model)
        if not auto.chain:
            ui.note("No model is installed or signed in on this computer, so the house will speak from the "
                    f"page. `{invocation()} doctor` shows what a model narrator needs.")
            return None
        with ui.waiting("the house is waking"):
            working = None
            while auto.chain:
                candidate = auto.chain[0]
                try:
                    candidate.complete("Reply with the single word OK.", "Are you there?", purpose="turn")
                    working = candidate
                    break
                except BackendError as exc:
                    auto.skipped.append({"backend": candidate.name, "kind": exc.kind, "detail": str(exc)[:160]})
                    auto.chain.pop(0)
        for skip in auto.skipped:
            ui.dev(f"narrator {skip['backend']} skipped: {skip['kind']}: {skip['detail']}")
        if working is None:
            tried = ", ".join(f"{s['backend']} ({s['kind']})" for s in auto.skipped) or "nothing"
            ui.note(f"No model answered (tried: {tried}), so the house will speak from the page.")
        return working
    try:
        return make_backend(name, model, getattr(args, "narrator_cmd", None))
    except BackendError as exc:
        ui.note(f"The {name} narrator is not available ({exc}). The house will speak from the page.")
        return None


def opening_notice(ui, backend: Backend | None, session: Session) -> None:
    ui.plain("")
    ui.plain(TITLE.center(ui.width).rstrip())
    if backend is None:
        sent = "Nothing you type leaves this computer."
    else:
        sent = (f"The house's voice tonight is {backend.label}: what you type is sent to it to be answered, "
                f"under your own account with that service. Nothing else leaves this computer.")
    if session.config.get("no_save"):
        ui.note(f"This night is not being kept: nothing is written to this computer unless you name a file "
                f"with --out. {sent}")
    else:
        ui.note(f"This game remembers. What you type, and what the house makes of it, is kept on this "
                f"computer until you erase it. {sent}")
        ui.plain(f"  kept in:   {data_dir()}")
        ui.plain(f"  erase it:  {invocation()} forget")
    ui.note(help_text(kept=not session.config.get("no_save")))


# ---------------------------------------------------------------------------
# The night and its ending
# ---------------------------------------------------------------------------

def run_night(engine: Engine, ui) -> str:
    kept = not engine.s.config.get("no_save")

    def leave() -> None:
        engine.s.save()
        if kept:
            ui.note(f"The house keeps your place. Return with: {invocation()} resume {engine.s.id}")
        else:
            ui.note("This night was not being kept. It ends here.")

    while not engine.finished:
        try:
            text = ui.ask()
        except EOFError:
            engine.s.save()
            return "eof"
        except KeyboardInterrupt:
            leave()
            return "quit"
        text = text.strip()
        if not text:
            continue
        low = text.lower()
        if low in ("quit", "exit", "/quit", "/exit"):
            leave()
            return "quit"
        if low == "/help":
            ui.note(help_text(kept))
            continue
        engine.turn(text)
    return "done"


def present_reading(ui, synthesis: dict) -> None:
    p = synthesis["prophecy"]
    ui.pause(1.0)
    ui.proprietor(p["address"])
    ui.pause(1.2)
    for line in p["recollections"]:
        ui.proprietor(line)
        ui.pause(0.7)
    ui.pause(1.0)
    for vision in p["visions"]:
        ui.card(vision["card"], vision["text"])
        ui.pause(1.2)
    ui.pause(1.2)
    ui.banner(p["pronouncement"])
    ui.pause(1.0)


def finish(engine: Engine, registry, ui, args) -> int:
    """The reading, and then the one thing the night hands over: the prompt."""
    s = engine.s
    engine.close_night()
    ui.narrate(LAYING_OUT)
    synthesis = synthesize(registry, engine.model, s, engine.backend, ui)
    s.synthesis = synthesis
    s.prompt = build_prompt(registry, engine.model, s, synthesis)
    s.phase = "done"
    s.save()
    present_reading(ui, synthesis)
    ui.narrate(registry.reading["last_card"])           # the deck becomes one card: the prompt
    ui.pause(0.8)
    ui.proprietor(registry.reading["handoff_line"])
    ui.pause(1.0)
    code = hand_over(ui, s, s.prompt, args)
    if ui.interactive:
        ui.hold("Press Enter to leave the house. ")
    return code


def _prepare(ui_plain, folder: str, text: str, manual_arg: str | None) -> bool:
    """Make the project folder and say, in plain lines, exactly what is in it."""
    manual = find_manual(manual_arg)
    if manual_arg and manual is None:
        ui_plain(f"  No manual at {manual_arg}: looked for {MANUAL_NAME}.")
    try:
        made = prepare_project(folder, text, manual)
    except PromptError as exc:
        ui_plain(f"  The folder was not prepared: {exc}")
        return False
    ui_plain(f"  A folder is ready for the builder: {made['folder'].resolve()}")
    ui_plain(f"    {PROMPT_FILE}: the same prompt, as a file")
    if made["manual"] and made["reference"]:
        ui_plain(f"    {MANUAL_NAME} and {REFERENCE_DIR}/: the manual, copied from {made['manual']}")
        ui_plain("  Open your AI coder in that folder and paste the prompt,")
        ui_plain(f"  or tell it: Read {PROMPT_FILE} and do what it says.")
    elif made["manual"]:
        ui_plain(f"    {MANUAL_NAME}: the manual's core, copied from {made['manual']}")
        ui_plain(f"    Its {REFERENCE_DIR}/ folder was not beside it, so the reference files are NOT there, and the")
        ui_plain(f"    prompt sends the builder to them. Put the {REFERENCE_DIR}/ folder in that folder before you start.")
    else:
        ui_plain("    THE AI STUDIO MANUAL was not found, so it is not there yet. Put")
        ui_plain(f"    {MANUAL_NAME} and its {REFERENCE_DIR}/ folder in that folder, or name the manual with --manual.")
    return True


def hand_over(ui, session: Session, text: str, args) -> int:
    """Out of the fiction: show the prompt exactly, keep it, offer the clipboard, say what to do next."""
    kept = not session.config.get("no_save")
    saved, problem = save_prompt(session, text, getattr(args, "out", None))
    session.save()

    ui.note("Out of the fiction now. The night has been written down as one message, for whoever builds the "
            "game: an AI coding agent that has THE AI STUDIO MANUAL. The message is everything between the "
            "two rules below.")
    ui.rule("the prompt begins below this line")
    ui.raw(text)
    ui.rule("the prompt ended above this line")

    want = getattr(args, "copy", None)          # True: copy. False: never. None: ask, if someone is there.
    copied, how = False, ""
    if want is True:
        copied, how = clipboard.copy(text)
    elif want is None and ui.interactive and clipboard.available():
        if ui.confirm("Copy the prompt to the clipboard now? [Y/n] ", default=True):
            copied, how = clipboard.copy(text)

    run = invocation()
    ui.plain("")
    if copied:
        ui.plain(f"  On the clipboard: the prompt, {word_count(text):,} words.")
    elif how:
        ui.plain(f"  Not copied to the clipboard: {how}.")
    for path in saved:
        ui.plain(f"  Saved: {path}")
    if problem:
        ui.plain(f"  Not saved: {problem}")
    if not kept:
        ui.plain("  This night keeps nothing, so the program cannot show the prompt again." +
                 ("" if saved or copied else " Copy it from the screen now."))
    ui.plain("")
    prepared = bool(getattr(args, "project", None)) and _prepare(ui.plain, args.project, text,
                                                                  getattr(args, "manual", None))
    if not prepared:
        ui.plain("  To have the game built:")
        ui.plain(f"    1. Give an empty folder THE AI STUDIO MANUAL: {MANUAL_NAME} and the {REFERENCE_DIR}/ folder")
        ui.plain("       beside it." + (f" This does it for you:  {run} prompt --project <folder>" if kept else ""))
        ui.plain("    2. Open your AI coder in that folder and paste the prompt.")
    if kept:
        ui.plain("")
        ui.plain(f"  the prompt again:     {run} prompt --copy")
        ui.plain(f"  what the house saw:   {run} dev --open")
        ui.plain(f"  erase this night:     {run} forget {session.id}")
    return 0


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_play(args) -> int:
    registry = load_registry()
    ui = Console(fast=args.fast, plain=args.plain, dev=args.dev)
    backend = choose_narrator(args, ui)
    session = Session.new({"length": args.length, "backend": args.narrator, "model": args.model,
                           "backend_used": backend.name if backend else "offline",
                           "no_save": args.no_save}, seed=args.seed)
    opening_notice(ui, backend, session)
    engine = Engine(session, registry, ui, backend)
    engine.begin()
    if run_night(engine, ui) != "done":
        return 0
    return finish(engine, registry, ui, args)


def _load(session_id: str | None, *, unfinished: bool = False, finished: bool = False) -> Session | None:
    """The night that was named, or the newest one that fits."""
    if session_id:
        ids = [session_id]
    elif finished:
        ids = [s["id"] for s in list_sessions() if s["phase"] == "done"]
    else:
        latest = latest_session(unfinished_only=unfinished)
        ids = [latest] if latest else []
    for sid in ids:
        try:
            return Session.load(sid)
        except (OSError, ValueError):
            continue
    return None


def cmd_resume(args) -> int:
    registry = load_registry()
    ui = Console(fast=args.fast, plain=args.plain, dev=args.dev)
    session = _load(args.session, unfinished=True)
    if session is None:
        ui.note(f"There is no unfinished night to return to. Start one with: {invocation()}")
        return 1
    if session.phase == "done":
        ui.note(f"That night is finished. Its prompt: {invocation()} prompt {session.id}")
        return 0
    backend = choose_narrator(args, ui)
    session.config["backend_used"] = backend.name if backend else "offline"
    opening_notice(ui, backend, session)
    engine = Engine(session, registry, ui, backend)
    if session.phase != "reveal":
        engine.begin()
        if run_night(engine, ui) != "done":
            return 0
    return finish(engine, registry, ui, args)


def _prompt_of(registry, session: Session) -> str:
    """A finished night's prompt: the one it was handed, or, for a night from before the
    prompt existed, the one its record makes."""
    if session.prompt:
        return session.prompt
    model = PlayerModel.from_list(registry, session.observations)
    return build_prompt(registry, model, session, session.synthesis, when=session.updated)


def cmd_prompt(args) -> int:
    registry = load_registry()
    session = _load(args.session, finished=True)
    if session is None or not session.synthesis:
        print("No finished night found. The prompt is written when a night reaches the reading.", file=sys.stderr)
        return 1
    text = _prompt_of(registry, session)
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    if not (args.out or args.copy or args.project):
        try:                                        # the prompt and nothing else, byte for byte, so it can be piped
            sys.stdout.flush()
            sys.stdout.buffer.write(text.encode("utf-8"))
            sys.stdout.buffer.flush()
        except AttributeError:                      # a stream with no byte layer under it
            sys.stdout.write(text)
        return 0
    code = 0
    if args.out:
        # Only the named file is written: the copy the night keeps, and the night's place in
        # the list, are left exactly as they were.
        written, problem = save_prompt(session, text, args.out, keep=False)
        for path in written:
            print(f"Saved: {path}")
        if problem:
            print(f"Not saved: {problem}")
            code = 1
    if args.copy:
        copied, how = clipboard.copy(text)
        print(f"On the clipboard: the prompt, {word_count(text):,} words." if copied
              else f"Not copied to the clipboard: {how}.")
        code = code or (0 if copied else 1)
    if args.project and not _prepare(print, args.project, text, args.manual):
        code = 1
    return code


def cmd_profile(args) -> int:
    registry = load_registry()
    session = _load(args.session, finished=True)
    if session is None or not session.synthesis:
        print("No finished night found.", file=sys.stderr)
        return 1
    model = PlayerModel.from_list(registry, session.observations)
    text = json.dumps(build_profile(registry, model, session, session.synthesis), indent=2, ensure_ascii=False)
    if args.out:
        Path(args.out).write_bytes((text + "\n").encode("utf-8"))
        print(f"Saved: {args.out}")
    else:
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
        print(text)
    return 0


def cmd_list(args) -> int:
    rows = list_sessions()
    if not rows:
        print(f"No nights are kept in {data_dir()}.")
        return 0
    print(f"Nights kept in {data_dir()}:")
    for r in rows:
        when = time.strftime("%Y-%m-%d %H:%M", time.localtime(r["updated"]))
        print(f"  {r['id']}  {when}  {r['phase']:9s} {r['turn']:3d} turns  {r['backend']:8s} {r.get('title', '')}")
    return 0


def cmd_forget(args) -> int:
    target = args.session
    what = f"night {target}" if target else f"every night kept in {data_dir()}"
    if not args.yes:
        if not sys.stdin.isatty():
            print(f"This would erase {what}. Run again with --yes to confirm.")
            return 1
        try:
            answer = input(f"Erase {what}? This cannot be undone. [y/N] ").strip().lower()
        except EOFError:
            print("Nothing was erased. Run again with --yes to confirm.")
            return 1
        if answer not in ("y", "yes"):
            print("Nothing was erased.")
            return 0
    removed = forget(target)
    print("Erased:" if removed else "There was nothing to erase.")
    for path in removed:
        print(f"  {path}")
    return 0


def cmd_dev(args) -> int:
    registry = load_registry()
    session = _load(args.session)
    if session is None:
        print("No night found.")
        return 1
    path = write_devview(registry, session, args.out)
    print(f"Developer view written to {path}")
    if args.open:
        webbrowser.open(path.resolve().as_uri())
    return 0


def cmd_simulate(args) -> int:
    from .simulate import PERSONAS, gdv_difference, run_persona, summary
    registry = load_registry()
    names = list(PERSONAS) if args.persona == "all" else [args.persona]
    runs = []
    for name in names:
        run = run_persona(registry, name, seed=args.seed, length=args.length, save=False)
        runs.append(run)
        info = summary(run)
        print(f"\n== {name}: {PERSONAS[name]['about']}")
        print(f"   {info['turns']} turns, {info['observations']} observations; rooms: {', '.join(info['chambers'])}")
        print(f"   game: {info['title']}")
        print(f"   fantasy: {info['central_fantasy']}")
        print(f"   core verb: {info['core_verb']}   failure cost: {info['failure_cost']}")
        print(f"   mood: {info['mood']}")
        for label in ("dominant", "secondary"):
            for sig in info[label]:
                print(f"   {label}: {sig}")
        print(f"   contradiction: {info['contradiction'] or 'none observed'}")
        print(f"   unrequested: {info['unrequested']}")
        if args.out:
            folder = Path(args.out) / name
            folder.mkdir(parents=True, exist_ok=True)
            text = build_prompt(registry, run["model"], run["session"], run["synthesis"])
            run["session"].prompt = text
            (folder / "prompt.md").write_bytes(text.encode("utf-8"))
            profile = build_profile(registry, run["model"], run["session"], run["synthesis"])
            (folder / "profile.json").write_bytes(
                (json.dumps(profile, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
            dev = write_devview(registry, run["session"], str(folder / "devview.html"))
            print(f"   prompt: {folder / 'prompt.md'} ({word_count(text):,} words)\n   developer view: {dev}")
    if len(runs) > 1:
        print("\nGame Design Vector fields that differ between personas:")
        for i, a in enumerate(runs):
            for b in runs[i + 1:]:
                print(f"   {a['persona']:13s} vs {b['persona']:13s} {gdv_difference(a, b):2d} of "
                      f"{len(registry.implications['gdv_fields'])}")
    return 0


def cmd_doctor(args) -> int:
    print(f"THE BLANK DECK {__version__}")
    try:
        registry = load_registry(force=True)
    except ContentError as exc:
        print(f"Content: INVALID: {exc}")
        return 1
    seeds = registry.chamber_seeds()
    print(f"Content: valid. {len(registry.seeds)} rooms ({len(seeds)} dealable), "
          f"{sum(len(s['options']) for s in registry.seeds.values())} authored options, "
          f"{len(registry.dims)} dimensions, {len(registry.skins)} thresholds, {len(registry.signals)} signals.")
    report = coverage_report(registry)
    thin = [d for d, r in report.items() if registry.dims[d].family == "axis" and len(r["kinds"]) < 2]
    unprobed = [d for d, r in report.items() if not r["seeds"] and registry.dims[d].family not in ("aesthetic",)]
    print(f"Coverage: core dimensions probed by fewer than two kinds of room: {', '.join(thin) or 'none'}.")
    print(f"          weights no room targets directly (evidence comes from thresholds or a narrator): "
          f"{', '.join(unprobed) or 'none'}.")
    print(f"Python: {sys.version.split()[0]}. Run as: {invocation()}")
    bundle = running_bundle()
    print(f"This copy: {'one file, ' + str(bundle) if bundle else 'a folder of source files'}.")
    print(f"Data directory: {data_dir()}")
    tool = clipboard.available()
    print(f"Clipboard: {tool if tool else 'no tool found; the prompt is still printed and saved'}.")
    manual = find_manual()
    print(f"Manual, for --project: {manual.where if manual else 'not found (name one with --manual)'}.")
    print("Narrator: the authored rooms, which need nothing. A model narrates only with --narrator:")
    for item in detect():
        if item["name"] == "offline":
            continue
        mark = "found  " if item["available"] else "missing"
        print(f"  {item['name']:10s} {mark} {item['detail']}")
    if args.probe:
        print("Probing each installed model with one short request:")
        for item in detect():
            if not item["available"] or item["name"] == "offline":
                continue
            try:
                backend = make_backend(item["name"])
                done = backend.complete("Reply with the single word OK.", "Are you there?", purpose="turn")
                print(f"  {item['name']:10s} answered in {done.latency:.1f}s: {done.text.strip()[:40]!r}")
            except BackendError as exc:
                print(f"  {item['name']:10s} failed ({exc.kind}): {str(exc)[:160]}")
    return 0


def cmd_bundle(args) -> int:
    manual = find_manual(args.manual) if args.manual else None
    if args.manual and manual is None:
        print(f"No manual at {args.manual}: looked for {MANUAL_NAME}.")
        return 1
    try:
        info = build_bundle(args.out, manual=manual, with_manual=not args.no_manual)
    except BundleError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(f"Wrote {info['path']} ({info['bytes']:,} bytes).")
    if info.get("copied"):
        print("This program is already one file; that is a copy of it.")
    elif info.get("manual") and info.get("reference"):
        print(f"It carries the rooms and a copy of the manual from {info['manual']}.")
    elif info.get("manual"):
        print(f"It carries the rooms and the manual's core from {info['manual']}, but no {REFERENCE_DIR}/ folder was "
              f"beside the core, so the reference files are not inside.")
    else:
        print("It carries the rooms. No manual was found to carry, so --project will need --manual.")
    print(f"Run it anywhere Python is installed:  python {info['path'].name}")
    return 0


# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    run = invocation()
    parser = argparse.ArgumentParser(
        prog=run,
        description="THE BLANK DECK: a short text adventure that reads how you play, and ends by handing you "
                    "a prompt to paste into an AI coder that has THE AI STUDIO MANUAL.")
    parser.add_argument("--version", action="version", version=f"The Blank Deck {__version__}")
    sub = parser.add_subparsers(dest="command")

    def night(p) -> None:
        p.add_argument("--fast", action="store_true", help="no typewriter effect and no pauses")
        p.add_argument("--plain", action="store_true", help="no colour")
        p.add_argument("--dev", action="store_true", help="show the house's reasoning after each turn")
        p.add_argument("--out", default=None, metavar="FILE", help="also save the prompt to this file")
        p.add_argument("--copy", dest="copy", action="store_true", default=None,
                       help="copy the prompt to the clipboard without asking")
        p.add_argument("--no-copy", dest="copy", action="store_false", help="leave the clipboard alone")
        p.add_argument("--project", default=None, metavar="FOLDER",
                       help="also make this folder ready for a builder: the prompt, and the manual beside it")
        p.add_argument("--manual", default=None, metavar="PATH", help="where the manual is, for --project")
        p.add_argument("--narrator", "--backend", dest="narrator", default="offline", choices=NARRATORS,
                       help="who tells the night: the authored rooms (offline, the default), or a model")
        p.add_argument("--model", default=None, help="model name for the chosen narrator")
        p.add_argument("--narrator-cmd", "--backend-cmd", dest="narrator_cmd", default=None,
                       help="command for --narrator command (prompt on standard input)")

    play = sub.add_parser("play", help="play a night (the default)")
    night(play)
    play.add_argument("--length", default="standard", choices=("short", "standard", "long"),
                      help="short is about 15 minutes, standard about 25, long about 35")
    play.add_argument("--seed", type=int, default=None, help="make the night's dealing reproducible")
    play.add_argument("--no-save", action="store_true", help="keep nothing on this computer")
    play.set_defaults(func=cmd_play)

    resume = sub.add_parser("resume", help="return to an unfinished night")
    resume.add_argument("session", nargs="?", default=None)
    night(resume)
    resume.set_defaults(func=cmd_resume)

    prompt = sub.add_parser("prompt", help="a finished night's prompt again: print it, copy it, save it",
                            description="With no switch, prints the prompt and nothing else, so it can be piped.")
    prompt.add_argument("session", nargs="?", default=None)
    prompt.add_argument("--copy", action="store_true", help="copy it to the clipboard")
    prompt.add_argument("--out", default=None, metavar="FILE", help="save it to this file")
    prompt.add_argument("--project", default=None, metavar="FOLDER",
                        help="make this folder ready for a builder: the prompt, and the manual beside it")
    prompt.add_argument("--manual", default=None, metavar="PATH", help="where the manual is, for --project")
    prompt.set_defaults(func=cmd_prompt)

    listing = sub.add_parser("list", help="the nights kept on this computer")
    listing.set_defaults(func=cmd_list)

    forgetting = sub.add_parser("forget", help="erase one night, or all of them")
    forgetting.add_argument("session", nargs="?", default=None)
    forgetting.add_argument("--yes", action="store_true", help="do not ask for confirmation")
    forgetting.set_defaults(func=cmd_forget)

    dev = sub.add_parser("dev", help="write the developer view of a night")
    dev.add_argument("session", nargs="?", default=None)
    dev.add_argument("--out", default=None, help="path of the HTML file to write")
    dev.add_argument("--open", action="store_true", help="open it in the browser")
    dev.set_defaults(func=cmd_dev)

    profile = sub.add_parser("profile", help="a finished night's design profile, as data")
    profile.add_argument("session", nargs="?", default=None)
    profile.add_argument("--out", default=None, metavar="FILE", help="save it instead of printing it")
    profile.set_defaults(func=cmd_profile)

    simulate = sub.add_parser("simulate", help="play simulated players through whole nights")
    simulate.add_argument("--persona", default="all",
                          choices=("all", "cartographer", "firestarter", "speedrunner", "host", "tinkerer"))
    simulate.add_argument("--seed", type=int, default=1)
    simulate.add_argument("--length", default="standard", choices=("short", "standard", "long"))
    simulate.add_argument("--out", default=None, help="write each persona's prompt, profile and developer view here")
    simulate.set_defaults(func=cmd_simulate)

    doctor = sub.add_parser("doctor", help="check the content and this computer")
    doctor.add_argument("--probe", action="store_true", help="send one short request to each installed model")
    doctor.set_defaults(func=cmd_doctor)

    bundle = sub.add_parser("bundle", help="write this whole program as one file")
    bundle.add_argument("--out", default=None, metavar="FILE", help=f"where to write it (default: {DEFAULT_NAME} here)")
    bundle.add_argument("--manual", default=None, metavar="PATH", help="the manual to carry inside it")
    bundle.add_argument("--no-manual", action="store_true", help="carry no copy of the manual")
    bundle.set_defaults(func=cmd_bundle)
    return parser


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or (argv[0] not in COMMANDS and argv[0] not in ("-h", "--help", "--version")):
        argv = ["play"] + argv
    for stream in (sys.stdout, sys.stderr):
        try:                                    # a name this console cannot print must not end the program
            stream.reconfigure(errors="replace")
        except (AttributeError, ValueError):
            pass
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except ContentError as exc:
        print(f"The authored content is invalid: {exc}", file=sys.stderr)
        return 1
    except (BundleError, PromptError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"A file could not be read or written: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print()
        return 130
