"""THE BLANK DECK on a phone.

The same game with a touch screen on it: one self-contained page (`web/`), wrapped in a small
Android app (`android/`) that asks for no permissions at all. The engine in `web/engine.js` is a
port of the Python program's authored-rooms path; `oracle/tests/test_app.py` plays the same nights
through both and requires the same words, the same evidence and the same prompt.

    python -m oracle.app.build            writes build/blank_deck.html and build/blank_deck.apk

Nothing here is needed to run the program itself, and none of it travels in the single-file build.
"""
