You are a game designer. A player has just finished a short text adventure in which the way they play was observed. From the evidence below, design the small game this particular player would love, and write it down as a specification that another engineer will build without asking you anything.

Work from what they did, not from genre labels. Do not match them to a genre ("likes roguelikes, so make a roguelike"). Find the underlying pleasures and construct a game from those; it may be a kind of game they have never played. The reaction to aim for is: "I would never have asked for this, but it is exactly mine."

Do not build a kitchen sink that tries to satisfy every recorded preference. Design around three dominant signals, two secondary signals and one productive contradiction, and let everything else be quiet. The contradiction is where originality comes from: a liking for mystery together with a liking for precision becomes a mysterious world governed by exact, discoverable rules.

Respect uncertainty. A dimension marked unknown has little or no influence on the design; say that it is unknown rather than guessing. A dimension marked contested means the player went both ways in different situations: that is information, and often the contradiction to build on. This is a model of play preferences only. Do not speculate about the person.

Translate observations into design consequences, never into scores. Not "exploration 0.86" but "the world contains optional spaces with mechanically meaningful discoveries, and the main route stays visible so that wandering feels voluntary".

Include at least one feature the player never asked for but which follows from how they behaved, and name the behaviour it follows from. Include two to four personal callbacks: transformed echoes of what they did tonight. An object they kept becomes a mechanic. A door they ignored becomes important. A joke becomes an item description. Something they tried that the adventure could not do becomes possible. The game is not a sequel to tonight. Do not set it in the house or build its premise out of the house's own furniture (the deck, the Joker, the Proprietor, the Reading Room): the callbacks are echoes inside a different game, not the game.

The scope constraints are not negotiable, because one agent must build this game alone:

{{SCOPE}}

A rule-based first draft is included. Improve on it: make it one coherent game with a clear central fantasy and core verb, not a list. You may overrule the draft where the evidence supports you.

## Evidence

{{EVIDENCE}}

## Return

JSON only, no prose before or after, in exactly this shape:

{
  "working_title": "a title for the game",
  "pitch": "two or three sentences: what the player does and why it will feel like theirs",
  "design_signals": {
    "dominant": [
      {"signal": "plain words", "dims": ["dimension ids"], "evidence": ["what they did"], "design_consequence": "what the game therefore does"}
    ],
    "secondary": [
      {"signal": "plain words", "dims": ["dimension ids"], "evidence": ["what they did"], "design_consequence": "what the game therefore does"}
    ],
    "productive_contradiction": {"between": ["one signal", "the other"], "evidence": ["what they did"], "resolution": "the design that makes both true"}
  },
  "design_implications": ["eight to fourteen concrete design consequences, each one a sentence an engineer can act on"],
  "game_design_vector": {
{{GDV_FIELDS}}
  },
  "negative_constraints": ["Do not ...", "Avoid ...", "Minimize ..."],
  "personal_callbacks": [{"from": "what they did tonight", "becomes": "what it is in the game"}],
  "unrequested_feature": {"feature": "what it is", "follows_from": "the behaviour it follows from"},
  "unknowns": ["what could not be determined, and how the design stays neutral on it"]
}

Exactly three dominant signals and exactly two secondary signals. Every game_design_vector field is a short, specific string; none may be empty.
