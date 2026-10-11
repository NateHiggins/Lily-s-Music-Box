"""The whole program as one file.

`python -m oracle bundle` writes `blank_deck.pyz`: the code and every authored
room in a single archive that Python runs directly (`python blank_deck.pyz`).
Copy that one file anywhere; it needs nothing beside it. When a copy of the
manual is found it is carried inside too, so that `--project` can lay it down
in a new folder wherever the file ends up.

Built with the standard library's zipapp. Nothing is downloaded.
"""

from __future__ import annotations

import shutil
import sys
import tempfile
import zipapp
from importlib import resources
from pathlib import Path

from .prompt import KIT_DIR, Manual, find_manual

DEFAULT_NAME = "blank_deck.pyz"
MAIN = '''"""THE BLANK DECK, as one file. Run it with:  python {name}"""
import sys

from oracle.cli import main

if __name__ == "__main__":
    sys.exit(main())
'''
SKIP_DIRS = {"tests", "__pycache__", KIT_DIR, "app"}       # app: the phone build, which is not this program
KEEP_SUFFIXES = {".py", ".json", ".md"}
SKIP_FILES = {"README.md", "DESIGN.md"}          # documents about the program, not parts of it


class BundleError(Exception):
    """The single file could not be written."""


def running_bundle() -> Path | None:
    """The archive this copy is running from, if it is running from one."""
    package = resources.files(__package__)
    if isinstance(package, Path):
        return None
    archive = Path(__file__).resolve().parent.parent
    return archive if archive.is_file() else None


def build_bundle(out: str | None = None, manual: Manual | None = None, with_manual: bool = True) -> dict:
    """Write the single file. Returns where it is and what it carries."""
    target = Path(out) if out else Path.cwd() / DEFAULT_NAME
    if target.is_dir():
        target = target / DEFAULT_NAME
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        already = running_bundle()
        if already is not None:                   # a bundle cannot rebuild itself; it can copy itself
            if already.resolve() != target.resolve():
                shutil.copyfile(already, target)
            return {"path": target, "bytes": target.stat().st_size, "manual": None, "copied": True}
    except OSError as exc:
        raise BundleError(f"could not write {target}: {exc}") from exc

    source = Path(resources.files(__package__))
    if manual is None and with_manual:
        manual = find_manual()
    with tempfile.TemporaryDirectory(prefix="blank-deck-bundle-") as tmp:
        stage = Path(tmp)
        package = stage / source.name
        count = 0
        for path in sorted(source.rglob("*")):
            relative = path.relative_to(source)
            if SKIP_DIRS & set(relative.parts) or not path.is_file():
                continue
            if path.suffix not in KEEP_SUFFIXES or (len(relative.parts) == 1 and path.name in SKIP_FILES):
                continue
            destination = package / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)
            count += 1
        if manual is not None and with_manual:
            for name, data in manual.files():
                destination = package / KIT_DIR / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(data)
                count += 1
        (stage / "__main__.py").write_bytes(MAIN.format(name=target.name).encode("utf-8"))
        try:
            zipapp.create_archive(stage, target, compressed=True)
        except (OSError, zipapp.ZipAppError) as exc:
            raise BundleError(f"could not write {target}: {exc}") from exc
    carried = manual if (manual is not None and with_manual) else None
    return {"path": target, "bytes": target.stat().st_size, "files": count,
            "manual": carried.where if carried else None,
            "reference": carried.reference_count() if carried else 0, "copied": False,
            "python": f"{sys.version_info.major}.{sys.version_info.minor}"}
