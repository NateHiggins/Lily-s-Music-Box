# THE BLANK DECK

Evidence class: **INERT** (how to run the oracle; it proves nothing about the Orison build)

A short text adventure that watches how you play and ends by handing you a prompt: one message to paste into an AI coding agent, which then builds a small game made for you by following the process manual, **docs/AI_GAME_DEVELOPMENT_MANUAL.md**.

You carry a deck of blank cards up through a strange house. At the top, the cards have faces. The Proprietor tells you what you will play, and the last card is for whoever builds it.

It is a standalone program. It needs Python and nothing else: no model, no account, no network. Nothing you type leaves your computer. It was developed on Python 3.12 and its tests also pass on 3.11; it is written to run on 3.9 or later, which has not been run.

There is also a version for a phone: an Android app, and the same game as a single page. See **On a phone** below.

## Play

From the repository root:

```bash
python -m oracle
```

Type what you do, in your own words. There is no list of commands. If the house does not follow you, ask it for a hint: the deck will show you a few words the room understands. Type **quit** to leave; the house keeps your place.

```bash
python -m oracle resume
```

| Switch | Effect |
|---|---|
| `--length short` | four rooms instead of six, about 15 minutes; `long` is eight |
| `--fast` | no typewriter effect and no pauses |
| `--copy`, `--no-copy` | copy the prompt to the clipboard without being asked, or never |
| `--out FILE` | also save the prompt to a file you choose |
| `--project FOLDER` | also make a folder ready for a builder (below) |
| `--no-save` | keep nothing on this computer: the prompt is then shown once, so copy it or name a file with `--out` |
| `--seed N` | make the dealing of rooms reproducible |
| `--dev` | print the house's reasoning after every turn |

## What you get

When the night ends you are told what you will play, and then, outside the fiction, the program shows one message between two lines. That message is the prompt. It is the same text in all four places:

| Where | How |
|---|---|
| On the screen | printed exactly, between the two rules |
| On the clipboard | you are asked once; say yes and it is ready to paste |
| In a file | under the data directory; the path is printed |
| Again, later | `python -m oracle prompt` prints it; add `--copy` or `--out FILE` |

It is about 2,800 words of plain text. It carries what the design stands on and the behaviour each signal was seen in, the Game Design Vector, the laws, the echoes of your night, what is not known, the reading as acceptance criteria, the scope, and a scoped grant. Read it before you use it. It is yours to edit: edit the copy you are about to paste, because the program keeps and re-prints the original.

## Have the game built

The prompt works with the manual. An AI coder needs both.

1. Make a folder for the game and put the manual in it. This does both, and saves the prompt there as **ORACLE_PROMPT.md**:

```bash
python -m oracle prompt --project path/to/new-game
```

2. Open your AI coder in that folder and paste the prompt. (Or tell it: read ORACLE_PROMPT.md and do what it says.)

The prompt tells the coder to read the manual's operating core in full, to treat the message as the day-zero prompt, and where the manual explains how (section 5.8, in **manual/REF_PROCESS.md**). It asks the coder to tell you, before anything else, what game it means to build: the prompt gives the signals and the constraints, and the coder invents the mechanic. It carries a standing grant in your voice: leave to do reversible work inside that folder without waiting for you, and to use its own judgement where the night gave evidence or left a field open. Everything the manual reserves to you stays yours, and so do the scope, every download and install, and anything outside the folder. Delete that section before pasting if you would rather be asked. If the coder cannot find the manual, the prompt tells it to stop and ask you.

This program does not start a coder and does not build anything. No AI coder has yet built a game from one of these prompts: that end of the chain is untested.

## One file

```bash
python -m oracle bundle
```

writes **blank_deck.pyz**: the whole program, every room, and a copy of the manual, in one file of about 285 KB. Copy it anywhere Python is installed and run it:

```bash
python blank_deck.pyz
```

Every command on this page works the same way with `python blank_deck.pyz` in place of `python -m oracle`. A copied **oracle** folder also runs on its own: `python path/to/oracle`.

## On a phone

```bash
python -m oracle.app.build
```

writes two files into **build/**:

| File | What it is |
|---|---|
| **blank_deck.apk** | the game as an Android app, about 135 KB, for Android 8.0 or later. It asks the phone for no permissions, so it has no network at all |
| **blank_deck.html** | the same game as one page, about 390 KB, for any current browser on any device |

It is the same game with a touch screen on it: the same rooms, the same reading, and the same prompt at the end, with a button that copies it and, in the app, one that hands it to another app. The ways onward are buttons. The deck is a button that asks for a hint. Everything else you still say in your own words. A night is kept on the phone after every turn; the menu's **Forget** erases what is kept there.

To put the app on a phone, copy **blank_deck.apk** to it and open it there: the phone asks once whether to allow an install from that source. Or, with the phone connected and USB debugging on:

```bash
adb install -r build/blank_deck.apk
```

The package is made with the Android SDK's own tools and a Java kit. There is no Gradle and nothing is downloaded; where the tools are missing, the command still writes the page and says what it did not find. The package is signed with a key made on this machine and kept under **~/.blank-deck/android**, so a later build installs over an earlier one. That key suits your own phone and not a store: `--keystore FILE` signs with another, and reads its password from the environment variable **BLANK_DECK_KEYSTORE_PASSWORD**.

The engine in the page is a second implementation, in JavaScript. The tests hold it to the first: they play the same nights through both and require the same words, the same evidence and the same prompt. The package has been built and read back with the SDK's tools, and the page has been played through in a desktop browser at a phone's width. Neither has been run on a phone: the machine that built them has no emulator, and no phone was attached.

## What the house knew

```bash
python -m oracle dev --open
```

writes one HTML file with every observation, every dimension with its confidence and the evidence both ways, how the profile moved turn by turn, why each room was dealt, the design, the reading and the exact prompt.

```bash
python -m oracle profile
```

prints the same profile as data.

## What is kept, and erasing it

The game models play preferences only. It does not infer anything about you as a person, and text that tries to is removed.

Each night is one file under **~/.blank-deck** (or the directory named by **ORACLE_HOME**), with its prompt and developer view beside it.

```bash
python -m oracle list
```

```bash
python -m oracle forget
```

`forget` with a night's id erases that night; with none, every night. A prompt or a project folder you sent elsewhere with `--out` or `--project` is yours and is not touched.

## A model as narrator (optional)

The authored rooms are the game. If you would rather have a model improvise the narration and read your free text, name one; nothing looks for a model unless you do.

| `--narrator` | What it needs |
|---|---|
| `offline` | nothing. This is the default |
| `anthropic` | `pip install anthropic` and **ANTHROPIC_API_KEY** in the environment. Model **claude-opus-5-5** unless `--model` says otherwise |
| `claude` | the Claude Code command line, signed in |
| `codex` | the Codex command line, signed in |
| `command` | `--narrator-cmd "your program"`: anything that reads a prompt on standard input and writes text |
| `auto` | the first of those that answers one short request, else offline |

With a model narrating, what you type is sent to that service to be answered, under your own account with it; the game says which before the first prompt. A turn through a command-line model can take twenty seconds or more.

## Simulated players and tests

```bash
python -m oracle simulate
```

plays five caricatured ways of playing through whole nights and prints the game each would be given, and how many design fields differ between them. Add `--out DIR` to write each one's prompt.

```bash
python -m unittest discover -s oracle/tests -t .
```

runs the 154 tests. No model is called and the clipboard is not touched. They launch this program itself; Node, to replay nights through the phone app's engine; and the Android SDK's tools, to build the package and read it back. The tests that need Node, the SDK or Python 3.12 are skipped where those are missing, and say so.

```bash
python -m oracle doctor
```

checks the content and says what this computer has: the clipboard tool, where the manual was found, how this copy is run.

## Where things are

| Path | What |
|---|---|
| **DESIGN.md** | how it works and why: the model, the rooms, the selector, the synthesis, the prompt, the boundary, and what was verified |
| **content/** | everything authored: dimensions, rooms, thresholds, signals, design rules, the reading, the fixed wording of the prompt |
| **model.py** | the player model |
| **probes.py** | which room and which ways onward are dealt next |
| **engine.py** | the turn loop |
| **offline.py** | the house as authored: matching a line to a room's options, and the hint card for a player who is stuck |
| **synthesis.py** | from profile to design and reading |
| **prompt.py** | the prompt, where it is kept, and the project folder |
| **clipboard.py**, **bundle.py** | the clipboard, and the single-file build |
| **app/** | the phone version: the page (**web/**), the Android shell around it (**android/**), and **build.py**, which makes both |
| **narrator.py**, **backends.py** | the optional model narrator |
| **devview.py** | the developer view |
| **guard.py** | the boundary |
| **simulate.py** | the simulated players |
| **tests/** | the tests |

To change what the house contains, edit the files in **content/** and run `python -m oracle doctor`: the loader refuses content that does not match its contract, and says where.
