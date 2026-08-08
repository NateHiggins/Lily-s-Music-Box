"""
engine/loader.py
----------------
Discovers and loads a game module by dotted Python path.

Contract: the module must expose a callable load() -> GameBundle.

Usage:
    bundle = load_module("games.lilys_music_box")
    Engine(bundle).run()
"""
from __future__ import annotations

import importlib
from engine.bundle import GameBundle


def load_module(module_path: str, dev_mode: bool = False) -> GameBundle:
    """
    Import module_path and call its load() function.
    Raises ImportError if the module can't be found.
    Raises AttributeError if load() is missing.
    Raises TypeError if load() doesn't return a GameBundle.
    """
    try:
        mod = importlib.import_module(module_path)
    except ModuleNotFoundError as e:
        raise ImportError(
            f"Game module {module_path!r} not found. "
            f"Make sure the package exists and is on sys.path."
        ) from e

    if not hasattr(mod, "load"):
        raise AttributeError(
            f"Game module {module_path!r} has no load() function. "
            f"Add: def load() -> GameBundle: ..."
        )

    load_fn = mod.load
    import inspect
    bundle = load_fn(dev_mode=dev_mode) if "dev_mode" in inspect.signature(load_fn).parameters else load_fn()

    if not isinstance(bundle, GameBundle):
        raise TypeError(
            f"Module {module_path!r}.load() returned {type(bundle).__name__!r}, "
            f"expected GameBundle."
        )

    return bundle
