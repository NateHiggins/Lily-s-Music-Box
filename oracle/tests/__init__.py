"""Tests for THE BLANK DECK. Run from the repository root:

    python -m unittest discover -s oracle/tests -t .

Every test keeps its files in a temporary ORACLE_HOME; nothing touches the
player's own data directory or clipboard, no model is called, and the only
thing launched is this program itself.
"""

import os
import tempfile

_HOME = tempfile.mkdtemp(prefix="blank-deck-tests-")
os.environ["ORACLE_HOME"] = _HOME
