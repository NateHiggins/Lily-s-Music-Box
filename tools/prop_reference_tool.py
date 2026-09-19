#!/usr/bin/env python3
"""Entry point for tools/prop_reference. Run ``python tools/prop_reference_tool.py --help``."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.prop_reference.cli import main  # noqa: E402

if __name__ == "__main__":
    sys.exit(main())
