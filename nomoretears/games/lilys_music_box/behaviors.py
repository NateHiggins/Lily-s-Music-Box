"""
games/lilys_music_box/behaviors.py
------------------------------------
Dialogue trees for all Lily's Music Box NPCs.

NPC chain and gate logic:
  Slime Maiden (slime_lair)  → SolveNPC opens slime_gate   → exit 2 unlocks
  Guardian (guardian_hall)   → SolveNPC opens guardian_gate → exit 3 unlocks
  Cherry (cherry_bower)      → SolveNPC opens cherry_gate   → exit 4 unlocks (WIN path)

Each tree has:
  - root_selector that returns "solved_root" once the NPC is solved.
  - A flag set at the moment of resolution (for cross-NPC awareness).
  - A terminal farewell that fires SolveNPC and closes the dialogue.

Art-trivia extension (added after solve)
  Each NPC guards a favourite artist — but never says the name until the player
  has accumulated enough clues and correctly answers a multiple-choice question.

  Trivia clues are structured to be inferrable, not memorised:
    • biography clue   — period, place, patronage
    • material clue    — specific medium or technique
    • motif clue       — recurring visual vocabulary
    • composition clue — how figures/space are arranged
    • emotional clue   — what the work feels like
    • gameplay hint    — connects the art to the active ability

  Artist-guess gate
    Final node presents 3–4 multiple-choice artist options.
    Correct → SetFlag unlock + success line.
    Wrong   → gentle clue + loop back to trivia.

NPC → favourite artist mapping
  slime_maiden  → Gustav Klimt        (she unlocks the Klimt tileset)
  guardian      → Jean-Honoré Fragonard (guardian_gothic themed on The Swing)
  cherry        → Alphonse Mucha      (Art Nouveau linework matches cherry's design)
"""
from engine.dialogue import (
    DialogueTree, DialogueNode, DialogueChoice,
    FlagSet, NPCSolved, Not,
    SetFlag, SolveNPC, OpenGate, SetTileset,
)


# ── Slime Maiden ──────────────────────────────────────────────────────────────
#
# A gentle, lonely creature who tends the lower halls.
# Her favourite artist is Gustav Klimt — she unlocks the klimt_dining tileset,
# and the Klimt vine-climb ability is her gift to Lily.

def _slime_root(state) -> str:
    if state.is_npc_solved("slime_maiden"):
        return "solved_root"
    return "greeting"


SLIME_MAIDEN_TREE = DialogueTree(
    root_node="greeting",
    root_selector=_slime_root,
    nodes={

        # ── Gameplay introduction ─────────────────────────────────────────────

        "greeting": DialogueNode(
            node_id="greeting",
            text=(
                "Oh! Someone found the Mud Room. I'm the Slime Maiden — "
                "I keep the lower halls clean and damp. Not many visitors "
                "make it down here. Most people go straight up."
            ),
            choices=[
                DialogueChoice("Tell me about yourself.", next_node="her_story"),
                DialogueChoice("Nice to meet you!",       next_node="farewell"),
                DialogueChoice("I'm in a hurry, sorry.",  next_node=None),
            ],
        ),

        "her_story": DialogueNode(
            node_id="her_story",
            text=(
                "I've been here a very long time. The upper halls have the "
                "Guardian and Cherry — they get all the visitors. Down here "
                "it's just me and the mud and the quiet dripping. "
                "It's peaceful, mostly. Sometimes lonely."
            ),
            choices=[
                DialogueChoice("That does sound lonely.", next_node="farewell"),
                DialogueChoice("The quiet sounds nice.",  next_node="farewell"),
            ],
        ),

        "farewell": DialogueNode(
            node_id="farewell",
            text=(
                "Oh — thank you for stopping. Really. It means more than you know. "
                "I'll open the mid-hall passage for you. The Guardian is waiting. "
                "And Lily — the golden vines here will hold you, "
                "but the halls ahead are changing. Trust what you see."
            ),
            effects=[
                SetFlag("met_slime_maiden"),
                SolveNPC("slime_maiden"),
                SetTileset("guardian_gothic"),
            ],
            choices=[
                DialogueChoice("Goodbye, Slime Maiden.", next_node=None),
            ],
        ),

        # ── Post-solve: offer art trivia ──────────────────────────────────────

        "solved_root": DialogueNode(
            node_id="solved_root",
            text=(
                "Welcome back. The passage to Guardian's Hall stays open. "
                "Would you sit a moment? I've been thinking about something beautiful."
            ),
            choices=[
                DialogueChoice("Tell me.",                  next_node="art_clue_1"),
                DialogueChoice("I can't stay long.",        next_node=None),
            ],
        ),

        # ── Art trivia: Klimt clues (no artist name until the final question) ─

        "art_clue_1": DialogueNode(
            node_id="art_clue_1",
            text=(
                "There is an artist I love. He used gold — not paint that looked "
                "like gold, but actual gold leaf, pressed into the surface. "
                "The light doesn't reflect off it the way it does off paint. "
                "It catches differently. Like a mosaic."
            ),
            choices=[
                DialogueChoice("Tell me more.", next_node="art_clue_2"),
            ],
        ),

        "art_clue_2": DialogueNode(
            node_id="art_clue_2",
            text=(
                "His figures — the people he painted — seem to dissolve into "
                "the pattern around them. Skin and fabric and background are "
                "one continuous surface. You cannot find where the person ends "
                "and the ornament begins."
            ),
            choices=[
                DialogueChoice("That sounds strange.",  next_node="art_clue_3"),
                DialogueChoice("What kind of shapes?",  next_node="art_clue_motifs"),
            ],
        ),

        "art_clue_motifs": DialogueNode(
            node_id="art_clue_motifs",
            text=(
                "Spirals. Rectangles. Eyes. Flowers. "
                "The same shapes appear across everything he made — like a private "
                "alphabet only he knew how to read."
            ),
            choices=[
                DialogueChoice("Continue.", next_node="art_clue_3"),
            ],
        ),

        "art_clue_3": DialogueNode(
            node_id="art_clue_3",
            text=(
                "He painted grand public buildings first — formal commissions, "
                "ceiling murals for the most important rooms in the city. "
                "Then something changed. The buildings rejected his later work. "
                "He returned the money and kept the paintings. "
                "He left the official world and made stranger, more private things."
            ),
            choices=[
                DialogueChoice("What happened to him?",  next_node="art_clue_4"),
                DialogueChoice("I think I know who...",  next_node="artist_guess"),
            ],
        ),

        "art_clue_4": DialogueNode(
            node_id="art_clue_4",
            text=(
                "He founded a group — they called themselves the Secession, "
                "because they seceded from the accepted taste of their time. "
                "He was their first president. The building they made for "
                "themselves is still there: a white cube with a golden dome "
                "made of laurel leaves. Over the door: 'To every age its art, "
                "to art its freedom.'"
            ),
            choices=[
                DialogueChoice("And the vines here?",   next_node="art_hint_gameplay"),
                DialogueChoice("I think I know who...", next_node="artist_guess"),
            ],
        ),

        "art_hint_gameplay": DialogueNode(
            node_id="art_hint_gameplay",
            text=(
                "The vines in this hall follow his logic. He painted a great tree — "
                "the Tree of Life — where branches spiral outward forever. "
                "Where gold meets stone is where you find something solid. "
                "That is where you can hold on."
            ),
            choices=[
                DialogueChoice("Do you know who made it?", next_node="artist_guess"),
            ],
        ),

        "artist_guess": DialogueNode(
            node_id="artist_guess",
            text=(
                "Do you know whose work I love most? "
                "The man who made gold breathe, who let the pattern eat the figure."
            ),
            choices=[
                DialogueChoice("Gustav Klimt.",      next_node="guess_correct"),
                DialogueChoice("Alphonse Mucha.",    next_node="guess_wrong"),
                DialogueChoice("Egon Schiele.",      next_node="guess_wrong"),
                DialogueChoice("Aubrey Beardsley.",  next_node="guess_wrong"),
            ],
        ),

        "guess_correct": DialogueNode(
            node_id="guess_correct",
            text=(
                "Yes. Gustav Klimt. "
                "The Tree of Life, The Kiss, the Stoclet Frieze. "
                "He believed decoration was not superficial. "
                "It was another language — for love, for mortality, "
                "for things that cannot be said directly. "
                "The vines here remember him."
            ),
            effects=[
                SetFlag("slime_knows_artist_klimt"),
            ],
            choices=[
                DialogueChoice("Thank you for telling me.", next_node=None),
            ],
        ),

        "guess_wrong": DialogueNode(
            node_id="guess_wrong",
            text=(
                "Not quite. Think about the material — actual gold, not paint. "
                "Think about the way the body becomes pattern. "
                "Would you like another clue?"
            ),
            choices=[
                DialogueChoice("Yes, tell me more.",  next_node="art_clue_3"),
                DialogueChoice("Let me guess again.", next_node="artist_guess"),
            ],
        ),

    },
)


# ── Guardian ──────────────────────────────────────────────────────────────────
#
# Ancient protector of the middle halls.  Stoic and formal.
# His favourite artist is Jean-Honoré Fragonard — the guardian_gothic tileset
# is themed on Fragonard's "The Swing."

def _guardian_root(state) -> str:
    return "solved_root" if state.is_npc_solved("guardian") else "challenge"


GUARDIAN_TREE = DialogueTree(
    root_node="challenge",
    root_selector=_guardian_root,
    nodes={

        # ── Gameplay gate ────────────────────────────────────────────────────

        "challenge": DialogueNode(
            node_id="challenge",
            text=(
                "Halt. I am the Guardian of these halls. "
                "Before you pass, I ask one thing: "
                "did you stop to greet the keeper of the lower halls?"
            ),
            choices=[
                DialogueChoice(
                    "Yes — I spoke with the Slime Maiden.",
                    next_node="honoured",
                    condition=FlagSet("met_slime_maiden"),
                ),
                DialogueChoice(
                    "I came straight here.",
                    next_node="reproach",
                ),
            ],
        ),

        "honoured": DialogueNode(
            node_id="honoured",
            text=(
                "Good. She is too often overlooked. You have more grace "
                "than most who walk these halls. You may proceed."
            ),
            choices=[
                DialogueChoice("Thank you, Guardian.", next_node="passage"),
            ],
        ),

        "reproach": DialogueNode(
            node_id="reproach",
            text=(
                "A pity. She tends these halls faithfully and few bother "
                "to acknowledge her. I will let you pass — but remember: "
                "kindness costs nothing and means everything."
            ),
            choices=[
                DialogueChoice("I'll visit her on the way back.", next_node="passage"),
                DialogueChoice("Duly noted.",                     next_node="passage"),
            ],
        ),

        "passage": DialogueNode(
            node_id="passage",
            text=(
                "Cherry's Bower is through the upper-left passage. "
                "She has kept watch for a long time. Speak gently."
            ),
            effects=[
                SetFlag("guardian_passed"),
                SolveNPC("guardian"),
                SetTileset("escher_foyer"),
            ],
            choices=[
                DialogueChoice("I will. Thank you.", next_node=None),
            ],
        ),

        # ── Post-solve: offer art trivia ──────────────────────────────────────

        "solved_root": DialogueNode(
            node_id="solved_root",
            text=(
                "The upper passage remains open. Safe travels. "
                "If you have a moment — I find myself wanting to speak of something. "
                "Not duty. Something lighter."
            ),
            choices=[
                DialogueChoice("What is it?",       next_node="art_clue_1"),
                DialogueChoice("Safe travels.",     next_node=None),
            ],
        ),

        # ── Art trivia: Fragonard clues ──────────────────────────────────────

        "art_clue_1": DialogueNode(
            node_id="art_clue_1",
            text=(
                "There is a painter I have admired for a very long time. "
                "He painted pleasure — aristocratic pleasure, gardens, silk dresses, "
                "sunlight through trees. "
                "His world was made of laughter and warmth and ease."
            ),
            choices=[
                DialogueChoice("That sounds unlike you.", next_node="art_clue_contrast"),
                DialogueChoice("Tell me more.",           next_node="art_clue_2"),
            ],
        ),

        "art_clue_contrast": DialogueNode(
            node_id="art_clue_contrast",
            text=(
                "Perhaps. I have guarded cold stone halls for so long that "
                "light through leaves feels like something I can only observe, "
                "not inhabit. That is precisely why it moves me."
            ),
            choices=[
                DialogueChoice("I understand. Continue.", next_node="art_clue_2"),
            ],
        ),

        "art_clue_2": DialogueNode(
            node_id="art_clue_2",
            text=(
                "His figures seem to float. They are caught at the peak of motion — "
                "suspended between falling and flying. He painted "
                "the suspended moment, the instant before weight returns."
            ),
            choices=[
                DialogueChoice("What kind of scenes?", next_node="art_clue_3"),
            ],
        ),

        "art_clue_3": DialogueNode(
            node_id="art_clue_3",
            text=(
                "One of his most famous works shows a young woman at the "
                "highest point of a swing's arc. Her shoe is flying off her foot. "
                "Below her, hidden in the roses and shadows, is a young man "
                "looking up at her. The painting was a commission — "
                "the nobleman who paid for it wanted to be depicted as that man."
            ),
            choices=[
                DialogueChoice("That is a strange commission.",  next_node="art_clue_4"),
                DialogueChoice("I think I know who this is...", next_node="artist_guess"),
            ],
        ),

        "art_clue_4": DialogueNode(
            node_id="art_clue_4",
            text=(
                "It was. He was a court painter — he served the tastes of the "
                "very wealthy right up to the Revolution. "
                "When the old world ended, everything he had painted for "
                "was swept away. He died in obscurity. "
                "But the paintings survived."
            ),
            choices=[
                DialogueChoice("And this hall?",           next_node="art_hint_gameplay"),
                DialogueChoice("I think I know who...",    next_node="artist_guess"),
            ],
        ),

        "art_hint_gameplay": DialogueNode(
            node_id="art_hint_gameplay",
            text=(
                "This architecture is built on his principles — the suspended moment, "
                "the figure at the arc of flight. "
                "In these rooms, watch for platforms at their highest point. "
                "That is where the momentum carries you furthest."
            ),
            choices=[
                DialogueChoice("Do you know who painted The Swing?", next_node="artist_guess"),
            ],
        ),

        "artist_guess": DialogueNode(
            node_id="artist_guess",
            text=(
                "Can you name him? The painter of pleasure, "
                "of gardens and floating figures and silk?"
            ),
            choices=[
                DialogueChoice("Jean-Honoré Fragonard.",      next_node="guess_correct"),
                DialogueChoice("Antoine Watteau.",             next_node="guess_wrong"),
                DialogueChoice("François Boucher.",            next_node="guess_wrong"),
                DialogueChoice("William-Adolphe Bouguereau.", next_node="guess_wrong"),
            ],
        ),

        "guess_correct": DialogueNode(
            node_id="guess_correct",
            text=(
                "Yes. Fragonard. "
                "The Swing, A Young Girl Reading, The Progress of Love. "
                "He understood that joy is a form of beauty — not lesser than "
                "solemnity, not shallower than grief. "
                "This hall was built in his memory."
            ),
            effects=[
                SetFlag("guardian_knows_artist_fragonard"),
            ],
            choices=[
                DialogueChoice("I will remember.", next_node=None),
            ],
        ),

        "guess_wrong": DialogueNode(
            node_id="guess_wrong",
            text=(
                "Not quite. Think about the setting — an aristocratic garden, "
                "a woman on a swing at her highest arc, a man below. "
                "Think about what was lost when the Revolution came."
            ),
            choices=[
                DialogueChoice("Tell me another clue.", next_node="art_clue_3"),
                DialogueChoice("Let me guess again.",   next_node="artist_guess"),
            ],
        ),

    },
)


# ── Cherry ────────────────────────────────────────────────────────────────────
#
# A gentle dream-spirit who keeps the final hall before Lily's room.
# Her favourite artist is Alphonse Mucha — Art Nouveau linework, floral borders,
# flowing hair, the woman as the centre of a decorative cosmos.

def _cherry_root(state) -> str:
    return "solved_root" if state.is_npc_solved("cherry") else "soft_greeting"


CHERRY_TREE = DialogueTree(
    root_node="soft_greeting",
    root_selector=_cherry_root,
    nodes={

        # ── Gameplay gate ────────────────────────────────────────────────────

        "soft_greeting": DialogueNode(
            node_id="soft_greeting",
            text=(
                "Lily... you made it all the way up. "
                "I am Cherry — I keep the door to your room. "
                "Before I open it, tell me: are you truly ready to sleep?"
            ),
            choices=[
                DialogueChoice("Yes. I'm so tired.",       next_node="ready"),
                DialogueChoice("Not quite — one moment.",  next_node="linger"),
            ],
        ),

        "linger": DialogueNode(
            node_id="linger",
            text=(
                "Take your time. The door will wait. "
                "Rest here if you need — the bower is quiet."
            ),
            choices=[
                DialogueChoice("I'm ready now.",         next_node="ready"),
                DialogueChoice("Just a little longer.",  next_node=None),
            ],
        ),

        "ready": DialogueNode(
            node_id="ready",
            text=(
                "Then go, Lily. Your bed is waiting. "
                "The music box will play until you drift off."
            ),
            choices=[
                DialogueChoice("Thank you, Cherry.", next_node="open_door"),
            ],
        ),

        "open_door": DialogueNode(
            node_id="open_door",
            text="Goodnight.",
            effects=[
                SetFlag("cherry_blessed"),
                SolveNPC("cherry"),
                SetTileset("lily_bedroom"),
            ],
            choices=[
                DialogueChoice("Goodnight.", next_node=None),
            ],
        ),

        # ── Post-solve: offer art trivia ──────────────────────────────────────

        "solved_root": DialogueNode(
            node_id="solved_root",
            text=(
                "The door is open, Lily. Your room is just ahead. "
                "But you are not asleep yet — would you like to hear "
                "about something beautiful first?"
            ),
            choices=[
                DialogueChoice("Yes, please.",   next_node="art_clue_1"),
                DialogueChoice("Not tonight.",   next_node=None),
            ],
        ),

        # ── Art trivia: Mucha clues ──────────────────────────────────────────

        "art_clue_1": DialogueNode(
            node_id="art_clue_1",
            text=(
                "The artist I love most made work for everyone. "
                "Posters for theater productions. Advertisements for champagne, "
                "biscuits, soap. Beautiful things given to the street — "
                "not hidden in galleries."
            ),
            choices=[
                DialogueChoice("That sounds different.", next_node="art_clue_2"),
            ],
        ),

        "art_clue_2": DialogueNode(
            node_id="art_clue_2",
            text=(
                "His lines are unbroken and organic — like hair, like water, "
                "like vines. Nothing is ever harsh in his compositions. "
                "He placed women at the centre of decorative frames: "
                "halos, flowers, borders, scrollwork. "
                "Every figure became a stained-glass saint of ordinary life."
            ),
            choices=[
                DialogueChoice("What else did he make?", next_node="art_clue_3"),
            ],
        ),

        "art_clue_3": DialogueNode(
            node_id="art_clue_3",
            text=(
                "He was born in a small country in central Europe, "
                "but he found fame in Paris. He became so famous there "
                "that the style he worked in was named after him in some places — "
                "though he preferred to think of his work as something older, "
                "something connected to the decorative arts of his homeland."
            ),
            choices=[
                DialogueChoice("And later?",            next_node="art_clue_4"),
                DialogueChoice("I think I know him...", next_node="artist_guess"),
            ],
        ),

        "art_clue_4": DialogueNode(
            node_id="art_clue_4",
            text=(
                "Later in his life he put aside the posters and spent twenty years "
                "painting an enormous cycle — twenty large canvases about the history "
                "and mythology of the Slavic peoples. "
                "He wanted to give his people an epic. "
                "He donated it to his homeland. "
                "It was not what his admirers expected."
            ),
            choices=[
                DialogueChoice("And this bower?",      next_node="art_hint_gameplay"),
                DialogueChoice("I think I know him.", next_node="artist_guess"),
            ],
        ),

        "art_hint_gameplay": DialogueNode(
            node_id="art_hint_gameplay",
            text=(
                "Cherry's Bower was designed after his principles — "
                "everything framed, everything in bloom. "
                "The petals around the platforms are his vocabulary. "
                "Look for the most decorated edge. That is the safe one."
            ),
            choices=[
                DialogueChoice("Who is he?", next_node="artist_guess"),
            ],
        ),

        "artist_guess": DialogueNode(
            node_id="artist_guess",
            text=(
                "Do you know his name? "
                "The painter of posters and saints and national epics?"
            ),
            choices=[
                DialogueChoice("Alphonse Mucha.",   next_node="guess_correct"),
                DialogueChoice("Gustav Klimt.",     next_node="guess_wrong"),
                DialogueChoice("Henri de Toulouse-Lautrec.", next_node="guess_wrong"),
                DialogueChoice("Jan Toorop.",       next_node="guess_wrong"),
            ],
        ),

        "guess_correct": DialogueNode(
            node_id="guess_correct",
            text=(
                "Yes. Alphonse Mucha. "
                "He believed beauty was not a luxury — it was a right. "
                "That art should live in the street, in the café, "
                "in the hands of anyone who reached for it. "
                "I think about that often, alone in this bower."
            ),
            effects=[
                SetFlag("cherry_knows_artist_mucha"),
            ],
            choices=[
                DialogueChoice("Goodnight, Cherry.", next_node=None),
            ],
        ),

        "guess_wrong": DialogueNode(
            node_id="guess_wrong",
            text=(
                "Not quite. Think about the posters — theater in Paris, "
                "the unbroken flowing lines, the woman always at the centre "
                "of a circle of flowers. Think about the small country, "
                "the enormous Slavic cycle, the homeland."
            ),
            choices=[
                DialogueChoice("Tell me another clue.", next_node="art_clue_3"),
                DialogueChoice("Let me guess again.",   next_node="artist_guess"),
            ],
        ),

    },
)


# ── Module export ──────────────────────────────────────────────────────────────

DIALOGUE_TREES: dict[str, DialogueTree] = {
    "slime_maiden": SLIME_MAIDEN_TREE,
    "guardian":     GUARDIAN_TREE,
    "cherry":       CHERRY_TREE,
}
