"""Command line for THE BLANK DECK.

    python -m oracle                 play a night
    python -m oracle resume          take up the last unfinished night
    python -m oracle list            the nights kept on this computer
    python -m oracle forget          erase them
    python -m oracle dev             write the developer view of a night
    python -m oracle packet          write the oracle packet of a finished night again
    python -m oracle build           hand a finished night's packet to an AI engineer
    python -m oracle simulate        play simulated players through offline nights
    python -m oracle doctor          what is installed, and whether the content is sound
"""

from __future__ import annotations

import argparse
import sys
import time
import webbrowser
from pathlib import Path

from . import __version__
from .backends import AutoBackend, Backend, BackendError, detect, make_backend
from .builder import FAILED_LINE, BuildError, offer_play, run_build
from .content import ContentError, coverage_report, load_registry
from .devview import write_devview
from .engine import Engine
from .model import PlayerModel
from .packet import find_manual, write_packet
from .session import Session, data_dir, forget, latest_session, list_sessions
from .synthesis import synthesize
from .ui import Console

COMMANDS = ("play", "resume", "list", "forget", "dev", "packet", "build", "simulate", "doctor")

TITLE = "T H E   B L A N K   D E C K"
HELP = ("Type what you do, in your own words: look at things, talk, take, try. There is no list of commands. "
        "Type quit to leave; the house keeps your place and `python -m oracle resume` returns you to it.")
LAYING_OUT = ("The Proprietor turns the deck face down, cuts it once, and begins to lay the cards out between "
              "you, slowly, in a pattern you do not recognise.")


# ---------------------------------------------------------------------------
# Choosing a voice
# ---------------------------------------------------------------------------

def choose_backend(args, ui) -> Backend | None:
    """Return a working backend, or None for an offline night. Says plainly which it is."""
    name = args.backend
    if name == "offline":
        return None
    if name == "auto":
        auto = AutoBackend(args.model)
        if not auto.chain:
            ui.note("No model is installed or signed in on this computer, so the house will speak from the "
                    "page: a complete night, with authored answers. `python -m oracle doctor` shows what a "
                    "live narrator needs.")
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
            ui.dev(f"backend {skip['backend']} skipped: {skip['kind']}: {skip['detail']}")
        if working is None:
            tried = ", ".join(f"{s['backend']} ({s['kind']})" for s in auto.skipped) or "nothing"
            ui.note(f"No model answered (tried: {tried}), so the house will speak from the page: a complete "
                    f"night, with authored answers.")
        return working
    try:
        return make_backend(name, args.model, getattr(args, "backend_cmd", None))
    except BackendError as exc:
        ui.note(f"The {name} backend is not available ({exc}). The house will speak from the page.")
        return None


def opening_notice(ui, backend: Backend | None) -> None:
    ui.plain("")
    ui.plain(TITLE.center(ui.width).rstrip())
    where = data_dir()
    if backend is None:
        sent = "Nothing you type leaves this computer."
    else:
        sent = (f"The house's voice tonight is {backend.label}: what you type is sent to it to be answered, "
                f"under your own account with that service. Nothing else leaves this computer.")
    ui.note(f"This game remembers. What you type, and what the house makes of it, is kept on this computer "
            f"until you erase it. {sent}")
    ui.plain(f"  kept in:   {where}")
    ui.plain("  erase it:  python -m oracle forget")
    ui.note(HELP)


# ---------------------------------------------------------------------------
# The night and its ending
# ---------------------------------------------------------------------------

def run_night(engine: Engine, ui) -> str:
    while not engine.finished:
        try:
            text = ui.ask()
        except EOFError:
            engine.s.save()
            return "eof"
        except KeyboardInterrupt:
            engine.s.save()
            ui.note(f"The house keeps your place. Return with: python -m oracle resume {engine.s.id}")
            return "quit"
        text = text.strip()
        if not text:
            continue
        low = text.lower()
        if low in ("quit", "exit", "/quit", "/exit"):
            engine.s.save()
            ui.note(f"The house keeps your place. Return with: python -m oracle resume {engine.s.id}")
            return "quit"
        if low == "/help":
            ui.note(HELP)
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
    """The reading, the packet, and (only if asked) the build."""
    s = engine.s
    engine.close_night()
    ui.narrate(LAYING_OUT)
    synthesis = synthesize(registry, engine.model, s, engine.backend, ui)
    s.synthesis = synthesis
    packet = write_packet(registry, engine.model, s, synthesis, out_dir=getattr(args, "out", None),
                          manual=getattr(args, "manual", None))
    s.phase = "done"
    s.save()
    present_reading(ui, synthesis)

    build = getattr(args, "build", "none") or "none"
    if build != "none":
        try:
            record = run_build(s, ui, preset=build, command=getattr(args, "builder_cmd", None),
                               project_dir=getattr(args, "project", None),
                               timeout_minutes=getattr(args, "build_timeout", 120.0))
        except BuildError as exc:
            ui.note(f"The build could not start: {exc}")
            record = None
        if record and record["status"] == "ok":
            ui.proprietor(synthesis["prophecy"]["final_line"])
            offer_play(record, ui)
        else:
            ui.banner(FAILED_LINE)
            if record:
                ui.note(f"The builder did not finish a playable game (status: {record['status']}). "
                        f"Its log is at {record['log']}. The packet is intact; you can build again with: "
                        f"python -m oracle build {s.id} --builder {build}")
    else:
        ui.proprietor(registry.reading["handoff_line"])
    footer(ui, s, packet)
    return 0


def footer(ui, session: Session, packet: Path) -> None:
    manual = (packet / "AI_GAME_DEVELOPMENT_MANUAL.md").is_file()
    ui.note("Out of the fiction now. The night produced a game description, written for whoever builds "
            "the game: a person or an AI engineer.")
    ui.plain(f"  the packet:            {packet}")
    ui.plain("    GAME_DESCRIPTION.md    the design, with the evidence behind it")
    ui.plain("    BUILDER_PROMPT.md      what to give your AI engineer")
    ui.plain("    design_profile.json    the same as data")
    if manual:
        ui.plain("    AI_GAME_DEVELOPMENT_MANUAL.md   the process manual the builder follows")
    ui.plain(f"  have it built:         python -m oracle build {session.id} --builder codex")
    ui.plain(f"  what the house saw:    python -m oracle dev {session.id} --open")
    ui.plain(f"  erase this night:      python -m oracle forget {session.id}")


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_play(args) -> int:
    registry = load_registry()
    ui = Console(fast=args.fast, plain=args.plain, dev=args.dev)
    backend = choose_backend(args, ui)
    session = Session.new({"length": args.length, "backend": args.backend, "model": args.model,
                           "backend_used": backend.name if backend else "offline",
                           "no_save": args.no_save}, seed=args.seed)
    opening_notice(ui, backend)
    engine = Engine(session, registry, ui, backend)
    engine.begin()
    if run_night(engine, ui) != "done":
        return 0
    return finish(engine, registry, ui, args)


def _resolve(session_id: str | None, unfinished: bool = False) -> Session | None:
    sid = session_id or latest_session(unfinished_only=unfinished)
    if not sid:
        return None
    try:
        return Session.load(sid)
    except (OSError, ValueError):
        return None


def cmd_resume(args) -> int:
    registry = load_registry()
    ui = Console(fast=args.fast, plain=args.plain, dev=args.dev)
    session = _resolve(args.session, unfinished=True)
    if session is None:
        ui.note("There is no unfinished night to return to. Start one with: python -m oracle")
        return 1
    if session.phase == "done":
        ui.note(f"That night is finished. Its packet is at {session.packet_dir}.")
        return 0
    backend = choose_backend(args, ui)
    session.config["backend_used"] = backend.name if backend else "offline"
    opening_notice(ui, backend)
    engine = Engine(session, registry, ui, backend)
    if session.phase != "reveal":
        engine.begin()
        if run_night(engine, ui) != "done":
            return 0
    return finish(engine, registry, ui, args)


def cmd_list(args) -> int:
    rows = list_sessions()
    if not rows:
        print(f"No nights are kept in {data_dir()}.")
        return 0
    print(f"Nights kept in {data_dir()}:")
    for r in rows:
        when = time.strftime("%Y-%m-%d %H:%M", time.localtime(r["updated"]))
        print(f"  {r['id']}  {when}  {r['phase']:9s} {r['turn']:3d} turns  {r['backend']}")
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
    session = _resolve(args.session)
    if session is None:
        print("No night found.")
        return 1
    path = write_devview(registry, session, args.out)
    print(f"Developer view written to {path}")
    if args.open:
        webbrowser.open(path.resolve().as_uri())
    return 0


def cmd_packet(args) -> int:
    registry = load_registry()
    session = _resolve(args.session)
    if session is None or not session.synthesis:
        print("No finished night found. A packet is written when a night reaches the reading.")
        return 1
    model = PlayerModel.from_list(registry, session.observations)
    packet = write_packet(registry, model, session, session.synthesis, out_dir=args.out, manual=args.manual)
    session.save()
    print(f"Packet written to {packet}")
    return 0


def cmd_build(args) -> int:
    ui = Console(fast=True, plain=args.plain)
    session = _resolve(args.session)
    if session is None or not session.synthesis:
        ui.note("No finished night found. Play one to the reading first.")
        return 1
    try:
        record = run_build(session, ui, preset=args.builder, command=args.builder_cmd,
                           project_dir=args.project, timeout_minutes=args.build_timeout)
    except BuildError as exc:
        ui.note(f"The build could not start: {exc}")
        return 1
    if record["status"] == "ok":
        ui.proprietor(session.synthesis["prophecy"]["final_line"], slow=False)
        offer_play(record, ui)
        return 0
    ui.banner(FAILED_LINE)
    ui.note(f"The builder did not finish a playable game (status: {record['status']}). Log: {record['log']}")
    return 2


def cmd_simulate(args) -> int:
    from .simulate import PERSONAS, gdv_difference, run_persona, summary
    registry = load_registry()
    names = list(PERSONAS) if args.persona == "all" else [args.persona]
    runs = []
    for name in names:
        run = run_persona(registry, name, seed=args.seed, length=args.length, save=bool(args.out))
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
            packet = write_packet(registry, run["model"], run["session"], run["synthesis"],
                                  out_dir=str(Path(args.out) / name))
            dev = write_devview(registry, run["session"], str(Path(args.out) / name / "devview.html"))
            print(f"   packet: {packet}\n   developer view: {dev}")
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
    print(f"          weights no room targets directly (evidence comes from thresholds or the narrator): "
          f"{', '.join(unprobed) or 'none'}.")
    print(f"Data directory: {data_dir()}")
    manual = find_manual()
    print(f"Process manual: {manual if manual else 'not found beside this copy (the packet will say so)'}")
    print("Narrator backends (signed-in state is only known by trying; `auto` tries them in this order):")
    for item in detect():
        mark = "found  " if item["available"] else "missing"
        print(f"  {item['name']:10s} {mark} {item['detail']}")
    if args.probe:
        print("Probing each installed backend with one short request:")
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


# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="python -m oracle",
        description="THE BLANK DECK: a short text adventure that reads how you play and writes the "
                    "description of a game made for you.")
    parser.add_argument("--version", action="version", version=f"The Blank Deck {__version__}")
    sub = parser.add_subparsers(dest="command")

    def voice(p) -> None:
        p.add_argument("--backend", default="auto",
                       choices=("auto", "anthropic", "claude", "codex", "command", "offline"),
                       help="who narrates (default: the first installed model that answers, else offline)")
        p.add_argument("--model", default=None, help="model name for the chosen backend")
        p.add_argument("--backend-cmd", default=None, help="command for --backend command (prompt on stdin)")
        p.add_argument("--fast", action="store_true", help="no typewriter effect and no pauses")
        p.add_argument("--plain", action="store_true", help="no colour")
        p.add_argument("--dev", action="store_true", help="show the house's reasoning after each turn")
        p.add_argument("--out", default=None, help="directory for the oracle packet (default: the data directory)")
        p.add_argument("--manual", default=None, help="path to the process manual to copy into the packet")
        p.add_argument("--build", default="none", choices=("none", "codex", "claude", "command"),
                       help="after the reading, hand the packet to this builder (default: none)")
        p.add_argument("--builder-cmd", default=None, help="command for --build command; {project} is replaced")
        p.add_argument("--project", default=None, help="directory in which the builder makes the game")
        p.add_argument("--build-timeout", type=float, default=120.0, help="minutes to allow the builder")

    play = sub.add_parser("play", help="play a night (the default)")
    voice(play)
    play.add_argument("--length", default="standard", choices=("short", "standard", "long"),
                      help="short is about 15 minutes, standard about 25, long about 35")
    play.add_argument("--seed", type=int, default=None, help="make the night's dealing reproducible")
    play.add_argument("--no-save", action="store_true", help="keep nothing on disk except the packet")
    play.set_defaults(func=cmd_play)

    resume = sub.add_parser("resume", help="return to an unfinished night")
    resume.add_argument("session", nargs="?", default=None)
    voice(resume)
    resume.set_defaults(func=cmd_resume)

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

    packet = sub.add_parser("packet", help="write the oracle packet of a finished night again")
    packet.add_argument("session", nargs="?", default=None)
    packet.add_argument("--out", default=None)
    packet.add_argument("--manual", default=None)
    packet.set_defaults(func=cmd_packet)

    build = sub.add_parser("build", help="hand a finished night's packet to an AI engineer")
    build.add_argument("session", nargs="?", default=None)
    build.add_argument("--builder", required=True, choices=("codex", "claude", "command"))
    build.add_argument("--builder-cmd", default=None)
    build.add_argument("--project", default=None)
    build.add_argument("--build-timeout", type=float, default=120.0)
    build.add_argument("--plain", action="store_true")
    build.set_defaults(func=cmd_build)

    simulate = sub.add_parser("simulate", help="play simulated players through offline nights")
    simulate.add_argument("--persona", default="all",
                          choices=("all", "cartographer", "firestarter", "speedrunner", "host", "tinkerer"))
    simulate.add_argument("--seed", type=int, default=1)
    simulate.add_argument("--length", default="standard", choices=("short", "standard", "long"))
    simulate.add_argument("--out", default=None, help="write each persona's packet and developer view here")
    simulate.set_defaults(func=cmd_simulate)

    doctor = sub.add_parser("doctor", help="what is installed, and whether the content is sound")
    doctor.add_argument("--probe", action="store_true", help="send one short request to each installed backend")
    doctor.set_defaults(func=cmd_doctor)
    return parser


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or (argv[0] not in COMMANDS and argv[0] not in ("-h", "--help", "--version")):
        argv = ["play"] + argv
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except ContentError as exc:
        print(f"The authored content is invalid: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print()
        return 130
