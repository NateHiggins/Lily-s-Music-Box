"""The boundary: this program models play preferences and nothing else.

The structured half of every observation cannot cross that boundary by
construction: evidence can only be filed on the registered play dimensions,
and there is no dimension for anything else. What could cross it is free text
written by the narrator model (the description of an action, a reason, a
remembered moment). So the free text is checked:

- `sensitive` / `scrub`: text that makes a claim about the player's health,
  diagnosis, intelligence, sexuality, politics, religion, age, gender,
  ethnicity or disability is replaced by a placeholder and the event logged.
  The dimension evidence beside it is kept; only the words are dropped.
- `narration_leaks`: narration must never talk about profiles or measurement
  during play. Logged for the developer view.
- `prophecy_problems`: the reading must not use the language of analysis.
"""

from __future__ import annotations

import re

PLACEHOLDER = "[removed: outside play preferences]"

# Clinical and identity vocabulary has no place in a game-design reading, wherever it appears.
_TRAIT_TERMS = re.compile(
    r"\b("
    r"depress(ion|ed|ive)|anxiety disorder|adhd|autis\w*|ocd|bipolar|schizo\w*|narcissis\w*|"
    r"psychopath\w*|sociopath\w*|ptsd|neurodiverg\w*|neurotypical|suicid\w*|self[- ]harm|"
    r"diagnos\w*|personality disorder|mental(ly)? (ill\w*|health|disorder)|"
    r"iq|sexual orientation|sexuality|heterosexual|homosexual|lesbian|bisexual|transgender|"
    r"political (view|views|leaning|leanings|belief|beliefs|affiliation)|republican|democrat|"
    r"left[- ]wing|right[- ]wing|"
    r"christian|muslim|jewish|hindu|buddhist|atheist|religious (belief|beliefs|background)|"
    r"ethnicity|ethnic background|racial|nationality|immigrant|"
    r"disabled|disability|handicapped"
    r")\b", re.IGNORECASE)

# The same ordinary words are fine in fiction ("the old man", "a smart use of the pole")
# and out of bounds as a claim about the person playing.
_ABOUT_PLAYER = re.compile(
    r"\b(player|bearer|user|they|he|she|this person|someone|anyone)(\s+who)?\s+"
    r"(is|are|seems?|appears?|sounds?|must be|may be|might be|could be|is probably|is likely|is clearly)\s+"
    r"(an? |not |very |quite |rather |really |so |too |probably |likely )*"
    r"(child|kid|teen\w*|minor|adult|elderly|old|young|man|woman|boy|girl|male|female|"
    r"smart|stupid|dumb|clever|intelligent|unintelligent|genius|slow|"
    r"addict\w*|traumati[sz]ed|anxious|depressed|lonely|autistic|gay|straight|trans|"
    r"religious|liberal|conservative)\b"
    r"|\b(their|his|her|the (player|bearer|user)'s)\s+"
    r"(age|gender|sex|race|religion|politics|intelligence|iq|mental|trauma|orientation|disability|"
    r"childhood|upbringing|marriage|job|income|health)\b",
    re.IGNORECASE)

_NARRATION_LEAK = re.compile(
    r"\b(profil\w+|your preferences?|personality|data ?points?|"
    r"being (tested|studied|observed|evaluated|assessed)|player model|questionnaire|archetype|"
    r"confidence score|what (kind|sort|genre)s? of games?|as an ai|language model)\b", re.IGNORECASE)

_ANALYSIS_WORDS = re.compile(
    r"\b(profile|preference|preferences|data|percent|based on|you like|you tend to|you prefer|"
    r"archetype|player type|analysis|analy[sz]ed|metric|metrics|algorithm|personality)\b|\d+\s?%",
    re.IGNORECASE)


def sensitive(text) -> bool:
    """True when free text strays into a category this program must not model."""
    if not isinstance(text, str) or not text:
        return False
    return bool(_TRAIT_TERMS.search(text) or _ABOUT_PLAYER.search(text))


def scrub(text, log: list | None = None, where: str = "", turn: int | None = None) -> str:
    """Return the text, or a neutral placeholder if it is out of bounds."""
    text = text if isinstance(text, str) else str(text)
    if sensitive(text):
        if log is not None:
            log.append({"guard": "sensitive_text_removed", "where": where, "turn": turn})
        return PLACEHOLDER
    return text


def removed(text) -> bool:
    return isinstance(text, str) and text.startswith("[removed")


def narration_leaks(text: str) -> list[str]:
    """Phrases in the narration that would expose the machinery."""
    return sorted({m.group(0).lower() for m in _NARRATION_LEAK.finditer(text or "")})


def prophecy_problems(texts: list[str]) -> list[str]:
    """Analytics language found in a reading."""
    found: set[str] = set()
    for text in texts:
        found.update(m.group(0).lower() for m in _ANALYSIS_WORDS.finditer(text or ""))
    return sorted(found)
