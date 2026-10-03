# THE BLANK DECK

Evidence class: **INERT** (how to run the oracle; it proves nothing about the Orison build)

A short text adventure that watches how you play and writes the description of a small game made for you. It is the front door of the process manual, **docs/AI_GAME_DEVELOPMENT_MANUAL.md**: the manual needs a creator's prompt, and this produces one from play instead of from a sentence.

You carry a deck of blank cards up through a strange house. At the top, the cards have faces. Then the Proprietor tells you what you will play, and a packet is written for whoever builds it.

No dependencies beyond Python itself (developed and tested on Python 3.12). Run every command from the repository root.

## Play

```bash
python -m oracle
```

Type what you do, in your own words. There is no list of commands. Type **quit** to leave; the house keeps your place.

```bash
python -m oracle resume
```

Useful switches:

| Switch | Effect |
|---|---|
| `--length short` | four rooms instead of six; `long` is eight |
| `--backend offline` | no model: the authored rooms, played from the page |
| `--backend codex` | narrate with a named backend (see below) |
| `--fast` | no typewriter effect and no pauses |
| `--dev` | print the house's reasoning after every turn |
| `--out DIR` | write the packet to a place you choose |
| `--no-save` | keep nothing on disk except the packet |
| `--seed N` | make the dealing of rooms reproducible |

## Who narrates

| Backend | What it needs |
|---|---|
| `anthropic` | `pip install anthropic` and **ANTHROPIC_API_KEY** in the environment. Model **claude-opus-5-5** unless `--model` says otherwise. |
| `claude` | the Claude Code command line, signed in (`claude` on the path, or the copy the desktop app installs) |
| `codex` | the Codex command line, signed in |
| `command` | `--backend-cmd "your program"`: anything that reads a prompt on standard input and writes text |
| `offline` | nothing |

The default, `auto`, sends one short request to each installed backend in that order and uses the first that answers. If none does, the night is played offline: the same house, with authored answers instead of improvised ones.

```bash
python -m oracle doctor --probe
```

shows what is installed and which backends actually answer.

With any backend except offline, what you type is sent to that service to be answered, under your own account with it. The game says which before the first prompt.

## What you get

When the night ends the packet is written, by default under the data directory:

| File | What it is |
|---|---|
| **GAME_DESCRIPTION.md** | the design: signals with their evidence, design implications, the Game Design Vector, negative constraints, personal callbacks, the feature nobody asked for, what is not known, and the visions as promises |
| **design_profile.json** | the same as data, with the evidence behind every value |
| **prophecy.md** | what you were told |
| **BUILDER_PROMPT.md** | the instruction to give an AI engineer |
| **transcript.md** | the night itself |
| **AI_GAME_DEVELOPMENT_MANUAL.md** | a copy of the process manual, when one is found beside the program |

To feed the manual: put the **oracle_packet** folder in an empty directory and give **BUILDER_PROMPT.md** to your AI engineer. The builder follows section 5.8 of the manual, which treats the packet as the creator's prompt and the visions as acceptance criteria.

## Have it built

Nothing is built unless you ask.

```bash
python -m oracle build --builder codex
```

or add `--build codex` to the play command to go straight from the reading to the build. Builders:

| Builder | What it is allowed to do |
|---|---|
| `codex` | Codex, sandboxed to write only inside the project directory |
| `claude` | Claude Code, allowed to edit files and run commands in the project directory |
| `command` | `--builder-cmd "your program {project}"`: whatever you give it |

The project is made under the data directory unless `--project DIR` says otherwise. While the builder works, a line in capitals appears each time the builder reports that something has actually happened, and only then: nothing is shown on a timer. Where an event names a proof file, the line is withheld unless the file exists. The build log is kept beside the project. The finished game is launched only if you say yes to the exact command.

A real build takes a builder a long time and has not been run from this program yet: the hand-off and the progress reader are tested against a stand-in builder only.

## What the house knew

```bash
python -m oracle dev --open
```

writes one HTML file with every observation, every dimension with its confidence and the evidence both ways, how the profile moved turn by turn, why each room was dealt, the design, the reading, the exact prompts sent, and the build events shown and withheld.

## What is kept, and erasing it

The game models play preferences only. It does not infer anything about you as a person, and text that tries to is removed.

Each night is one file under **~/.blank-deck** (or the directory named by **ORACLE_HOME**), with its packet, developer view and any game beside it.

```bash
python -m oracle list
```

```bash
python -m oracle forget
```

`forget` with a night's id erases that night; with none, every night. Packets and games you sent elsewhere with `--out` or `--project` are yours and are not touched.

## Simulated players and tests

```bash
python -m oracle simulate
```

plays five caricatured ways of playing through offline nights and prints the game each would be given, and how many design fields differ between them.

```bash
python -m unittest discover -s oracle/tests -t .
```

runs the 81 tests. No model is called and nothing is launched.

## Where things are

| Path | What |
|---|---|
| **DESIGN.md** | how it works and why: the model, the rooms, the selector, the synthesis, the boundary, and what was verified |
| **content/** | everything authored: dimensions, rooms, thresholds, signals, design rules, the reading, the prompts |
| **model.py** | the player model |
| **probes.py** | which room and which ways onward are dealt next |
| **engine.py** | the turn loop |
| **narrator.py**, **offline.py** | the house with and without a model |
| **backends.py** | the four ways to reach a model |
| **synthesis.py** | from profile to design and reading |
| **packet.py**, **builder.py** | the hand-off |
| **devview.py** | the developer view |
| **guard.py** | the boundary |
| **simulate.py** | the simulated players |
| **tests/** | the tests |

To change what the house contains, edit the files in **content/** and run `python -m oracle doctor`: the loader refuses content that does not match its contract, and says where.
