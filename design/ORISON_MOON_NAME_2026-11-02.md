# Adela's name in the Moon

Evidence class: **INERT**. Writers' room result, 2026-11-02, on Lily's rulings below, built as a first draft the same day. All of it is invented fiction, and it isn't in the Bible. The story stays **design/THE_YEAR_YOU_DIED_TREATMENT_2026-10-30.md**, except where a ruling here says otherwise. Her read decides what stays.

## 1. Lily's rulings, 2026-11-02

| Question | Ruling |
|---|---|
| The idea | Lily writes Adela's name on the Moon with alien technology, in a bonus comic that stands alone. It can be seen on the Moon afterwards, and its consequences go into the plot |
| When | **After July:** Saturday 21 September 1929 |
| How long | **To the end.** It stays through the 9 November evening and both endings |
| Who sees it | **Everyone on Earth** |
| How it looks | "Alter the moon's surface so the name is in shadowed relief of the terrain, hard to see except at certain phases of the moon but distinct in the telescope otherwise" |

**Three earlier rules yield to these rulings, and only as far as the Moon.** My note in **design/V2_ADELA_SOUND_PICTURE_PLOT_2026-11-01.md** said her death doesn't make the act, with no memorial and no eternal wake. **design/ORISON_YEAR_SUBPLOTS_2026-11-01.md** kept S15, S16, both endings and the 9 November evening undressed, and it kept the parties a Queens joke. See section 5 for how each survives.

## 2. The story

The comic script is private, outside this repo. The plot is this.

By the end of August Lily has one ugly print, a bench full of grease pencil, and a two-line notice in the Record. The last reel of Adela singing was cut, rightly, at Rhea's asking. Adela wanted her name on a bill.

On Thursday 12 September, in the middle of a sentence, Lily is received. It's the party everyone else has been to. She alone looks at the light, because Adela always asked what it was like and never got invited. She comes back holding a cup with a spoonful of that light in it.

**The alien technology is the cup,** the one thing the parties ever leave anyone with. What's in it pours away from whoever holds it, whichever way the cup is tipped, and it's on its way somewhere else. And it **cuts**: it takes a little off whatever it lands on. A cupful through her hand leaves her hand sunk into a neighbour's bricks, invisible at noon, plain at five o'clock when the sun comes down the shaft.

One cup is a hand in a wall, so for the Moon she wants eleven. She goes door to door and asks everybody who's been asked: Mrs. Albers, a coal dealer, Evelyn, Lena, Omar, Peter, the woman who couldn't tell a Graflex from a breadbox, who Adela was so rude about. Rhea has no cup and is asked anyway: "Did she say you could?" "No." "Then I'd like that noted." Juno asks whether she asked. "Who?"

She takes the name from the seventh Ravenswood letter, where Adela signed across clause six in grease pencil at twice the company's size. She traces it onto glass, going over the E eleven times, and pins the plate into the hat, which has four pins and comes off with one hand. **Eleven cups and a hat.**

On Saturday 21 September she goes up the Ravenswood Sound Shorts Company's stage wall in the silk, sets the cups in a ring on its premiere searchlight, and times the exposure the only way she knows, on a snare: the last eight bars of the slow song. Then **she puts Adela's two bars back,** the ones Adela finally took out in June. The Moon moves during those two bars, so the first letter slides downhill. Ten bars.

**Nothing happens.** It's a nearly full Moon, flat lit, with not a mark on it. Observatories find it that night and nobody else can. She carries the cups home.

On Thursday 26 September the Moon comes up near the quarter, the sun rakes across it, and any fool on a roof can read **ADEL**, the last of it lost in the glare. It's a cut, not a stain. You want the light from the side, as any photographer could have told her. "Nobody ever looks at the light."

She could go back and straighten it, because she has the plate. But Adela once hired a man who hung her pictures crooked on the left, and kept him on, because it annoys the right sort of person. **"I keep the negative."**

## 3. What's in the sky

**A cut in the terrain, not a mark.** It's cut into the Moon's real LOLA heights in **game/shaders/skywatch_moon.gdshaderinc**, so it lights and shadows by the same code as every crater. Its floor is also darker rock: more so in low sun, where its walls would shade it whole, and otherwise only under magnification. No generated texture is involved, so RUL-008 isn't touched. It appears over forty seconds from 22:40 on 21 September 1929, and it's a pure function of the date, so travelling back before that shows a clean Moon.

| Phase | With the eye | In a telescope | Dates |
|---|---|---|---|
| Near full | Nothing | **ADELA**, darker rock in the ground | 18 Oct |
| Gibbous | At most a letter along the shadow line | **ADELA** | 21 Sep |
| Near the quarters | **ADEL**: a ghost in the earthshine on the dark side, black along the shadow line, the last letter lost in the glare | **ADELA**, hard shadows at the line | 26 Sep, 10 Oct, 25 Oct, 9 Nov |
| New | Nothing, there's no Moon to see | Nothing | 2 Oct, 1 Nov |

**So nobody reads the whole name with the naked eye.** Unknown to the plan, the dark side's earthshine carries it as a ghost, which I kept because it's the best thing in the render. In a telescope it reads at any lit phase. **The game has no installed telescope yet:** the telescope column is proved only on the optical bench, at a 2 degree field. The eye column is at a 14 degree field at 1280 x 720; **at the player's wider normal view it will be harder, and it hasn't been looked at there.**

**On the last evening, 9 November, the first-quarter Moon shows ADEL.** See section 5.

## 4. What it does to the year

**Everyone on Earth can see it, and nobody knows who she is.** No paper, court or person outside the bar connects the name to Miss Voss of Long Island City. The borough has two hundred and twelve Adelas. Everybody knows an Adela. **The player knows.** That's the whole of the plot consequence: she spends the last seven weeks of the year under her own name, half of it at a time, and can't correct it.

**The papers.** Seven back pages, **1929-09-22** both papers to **1929-11-03**:

- The observatories first, and nobody can see it. The Speaker goes up on the roof and calls it a stunt.
- **ADEL** at the end of September. The Speaker's fifty-dollar reward fills Borden Avenue with four hundred and six women named Adela, who sing.
- The Adela hat, low on the left. Almanacs, the tax commission, the clergy.
- On 12 October the thing from the sea crosses in front of the name "and it never looked".
- The Crash week: "the only figure in the city" with no change, and clerks on the roofs looking up.
- A paid notice, the two hundred and twelfth of its kind: "To Adela: I am sorry about everything." It's not from Mae and not about anything.
- The reward stands. Nobody comes forward.

**Ravenswood.** "We note your client's billing. Under clause six, the Company retains the negative. Suggest smaller letters. Kindly advise."

**The threads,** all first drafts, from 27 September except where shown:

| Thread | Who | What |
|---|---|---|
| **li_cup** (13 to 21 Sep) | Lily | The cup, the light, and she's asking everyone who's been asked |
| **li_moon** | Lily | "It's crooked." **The one correction the player ever gets to make,** and it changes nothing |
| **li_bill** (from 1 Oct) | Lily | Suggest smaller letters |
| **jk_moon** | Juno | She gave two cups. It's the only thing in the borough she can't keep |
| **rs_moon** | Rhea | "It's her name. Nobody asked her." She knows where it is behind the blind |
| **ob_moon** | Omar | He's been up with a level. "I know how far it is." His wound stays unspent |
| **lo_moon** | Lena | The hat doesn't sit like that |
| **em_moon** | Evelyn | "Moon: incorrect." The cup came back washed |
| **pw_moon** | Peter | Who should he write to? |
| **tv_moon** | Teresa | "A friend of mine, she had terrible capitals, drink your water." |
| **ev_moon** (to 4 Oct) | Emil | "That's her E." No jokes, as his tree requires |
| **mk_moon** | Mae | "Somebody has written on something that does not belong to them." |
| **m_moon_name** | Companion | It has shadows it didn't have before. "I do not read what I witness." |

## 5. How the older rules survive

| Rule | How it stands |
|---|---|
| The murder, the dark hours, the solve | Untouched. Nothing here happens before 21 September except the party on the 12th. No case flag, carrier or O2 line |
| Mae | No confession and no evidence. Her line is ownership grammar and her bigotry stays unmentioned. **Her blinds aren't a clue,** and no thread opens from them |
| Lily holds nothing in the case | She still holds nothing. She doesn't know what happened on the roof, and the Orison's roof isn't used: **she does it from the Ravenswood stage, in Astoria** |
| Nadia alone learns the rider | Lily says "You've got eyes, for a man with a wrench" and draws nothing |
| The parties are a Queens joke | The world sees the name but **nobody outside Queens knows about the cups.** No word passes at the party. It's still a room and some backs. **Cups only** |
| Nobody loses time | Zero time passes at Lily's party, as at any other |
| Law VII.8 | Five letters is five marks, none of them empty. Ten bars, not a count, and no drum pattern is lettered |
| S15, S16, both endings, the 9 November evening | **Lily ruled it stays.** They aren't interrupted, no line in them changes, and nobody mentions it. **The only change is that ADEL is in the sky on the 9th if you look up.** Her read decides whether that's too much. It's a one-line date change if so |
| Her death doesn't make the act | Yields as far as this: a name, by a friend, with no money in it. There's still no memorial release, no posthumous success and no recording. Nobody learns who she was |
| Rhea's privacy | Kept. Her objection stands and isn't answered |
| Clues | **None here.** Lily ruled on 2 November that clues can be bought, and this doesn't sell one |

**Real people and places.** Astoria and the Exchange are real. No real person is named. The observatories are unnamed. The whole of the event is fiction.

## 6. What's built and what isn't

**Built, first draft.** The cut, the date driver and a review bench; seven back pages; twelve threads and one companion line.

**Not built.** An installed telescope, the cups as props, Lily's trip, the Ravenswood stage, crowds on roofs, and any change to the endings. The comic is a private script with nothing rendered. Adela's and Lily's threads still open only through the F9 playtest panel.
