"""Explicit repository/input roots and disposable native build directory."""
from pathlib import Path
import os

def repository_root():
    root=Path(os.environ['ORISON_RADIATOR_BUILD_ROOT']).resolve(strict=True)
    assert (root/'game/project.godot').is_file(),root
    return root

def output_directory():
    path=Path(os.environ['ORISON_RADIATOR_BUILD_OUT']).resolve()
    path.mkdir(parents=True,exist_ok=True)
    return path

def primitive_source():
    return Path(__file__).resolve().parent/'primitives.py'
