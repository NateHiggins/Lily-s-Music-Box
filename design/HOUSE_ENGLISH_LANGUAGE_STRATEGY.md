# House English: language as investigative equipment

Status: approved direction; opening-shift vertical slice first. House English
is an alternate-history New York occupational contact language. It is not an
ethnic accent generator and not a claim that one historical community spoke a
single pidgin.

## Product promise

The player begins able to perform simple work while understanding only part of
what the house says. Repeated words, apparatus states, gestures and
consequences teach a compact vocabulary. Later cases recombine known words to
describe impossible facts. Fluency is player knowledge, not an XP statistic.

The target moment is:

> The tenant says square. The paper says square. The house keeps owing.

The player should understand why those statements contradict one another
without opening a conventional quest explanation.

## Historical foundation and invention boundary

Primary corpus work begins with immigrant-authored New York writing,
multilingual newspapers, trade manuals, advertisements and worker testimony.
Useful starting collections:

- Abraham Cahan, *Yekl* (1896) and *The Rise of David Levinsky* (1917):
  immigrant-authored accounts of English vocabulary entering Yiddish and of
  language marking apprenticeship, status and belonging. Digital texts:
  <https://www.gutenberg.org/ebooks/36715> and
  <https://www.gutenberg.org/ebooks/2803>.
- New York Public Library / Historical Jewish Press holdings: the Yiddish and
  Ladino press ecology read by New Yorkers during the 1910s and 1920s:
  <https://www.nypl.org/blog/2020/08/12/nypl-historical-jewish-press-project>.
- *Il Progresso Italo-Americano*, a New York Italian daily:
  <https://www.nypl.org/research/research-catalog/bib/b12639057>.
- Library of Congress Federal Writers' Project New York worker life histories,
  especially Philip Dash and the industrial-lore collection. These are
  1936–40 retrospective testimony, useful for occupational rhythm but never
  silently represented as verbatim 1928 speech:
  <https://www.loc.gov/item/wpalh001494/> and
  <https://www.loc.gov/collections/federal-writers-project/articles-and-essays/industrial-lore/>.
- Period telephone, electrical, steam, elevator, fire-service and watch-system
  manuals already cited by Orison's apparatus work.

Every adopted expression must record source, date, community, occupation,
historical meaning, Orison transformation, register and cultural-review risk.
Authentic quotation, historical inference and alternate-history invention are
separate fields. Phonetic eye-dialect is forbidden by default.

## The language

House English is readable English compressed around work. Its special strength
is evidentiality: who or what says a fact is as important as the fact.

Core evidence terms:

- **tenant-says** — reported by an occupant, not yet proved;
- **glass-says** — directly visible through an inspection surface;
- **line-says** — electrically or telephonically indicated;
- **hand-proved** — physically tested by the speaker;
- **house-says** — several independent building systems agree;
- **dream-says** — experienced, but ownership and reliability are unresolved.

Core state terms:

- **square** — restored, accounted for and honestly recorded;
- **cross** — obstructed, wrong, or contradicting another indication;
- **hot** — energized, pressurized or immediately consequential;
- **blind** — operating without a truthful indication;
- **walking** — a fault propagating through connected systems;
- **sleeping** — inactive but capable of returning;
- **owing** — a consequence or accountable action remains;
- **carrying** — custody currently rests with a person.

Ordinary objects gain stable occupational compounds: **heat-iron** (radiator),
**house-line** (building communication circuit), **lift-cage**, **night-paper**
(register sheet), and **work-paper** (work order). Compounds must be consistent;
writers cannot invent synonyms merely for color.

## Three text strata

1. Diegetic text uses House English: speech, notes, work papers, apparatus
   legends and case observations.
2. Safety and navigation remain immediately legible: apartment numbers,
   amperage, floor numbers, LINE OPEN and physical units are never riddles.
3. Platform and accessibility text remains ordinary localized language:
   settings, saves, legal warnings and accessibility controls.

The default presentation may be demanding only because it ships with Full
House English, learned interpretation, parallel subtitles, plain-language
subtitles, hold-to-interpret and reduced-complexity modes.

## Learning design

The opening shift teaches no more than 25 terms. Each appears physically before
it becomes narratively essential. The notebook records hypotheses that improve
with evidence rather than exposing an omniscient dictionary. Terms recur across
mechanisms so knowledge transfers: a blind gauge prepares the player to
understand a blind clock, witness or mirror.

Success criterion for the vertical slice: after contextual exposure, players
correctly act on one unseen instruction assembled from familiar terms and can
explain its evidential status. Measure comprehension, time-to-action, mistaken
actions, interpretation-option use and qualitative delight—not just completion.

### A11 vignette teaching sequence

“The House Heard Big” uses invented House English, not attributed immigrant
slang. Its four phrases must be learned from visible causality in this order:

1. **coin-says YES / coin-says NO** — the player watches which weighted trough
   closes its switch and which axis the head takes. Plain presentation: “The
   coin selected YES; the head nodded.”
2. **hand-asks** — the separate plunger makes clear that a hand requests the
   selected answer; neither coin nor current completes it alone. Plain:
   “Working the plunger asked the machine to show its selection.”
3. **house-heard** — several independent instruments present ordinary facts
   after the answer. The phrase claims correlation, not supernatural causation.
   Plain: “Several building systems began asking for the player.”
4. **heard big** — too many owners address one responsible hand across the
   house. “Big” means scope of accountability, never body size, age, ethnicity
   or intelligence. Plain: “The player accepted more responsibility than one
   person can answer at once.”

The reversal is **hear one**: return shared custody, release the live line and
select one resident’s report. It must not be rendered as **make square**, because
the point is attention rather than completion. Safety text retains literal
CURRENT, YES, NO, LINE OPEN and physical units.

## Character rule

The shared cant has individual idiolects. Mina favors line and circuit
evidence; Lena strain, seam and material language; Omar fit and workmanship;
a nurse distinguishes quiet, sleeping, fading and gone. No nationality receives
a canned grammar or misspelling filter. Cultural readers review the residents
whose languages contribute concepts.

## Implementation contract

Authored semantic records are the source of truth. A deterministic renderer
selects controlled House English and plain-language surfaces. No runtime model
paraphrases dialogue. This preserves terminology, localization, testing and
performance, and allows comprehension modes without duplicating story state.

`game/data/house_english_lexicon.json` is the initial provenance-bearing
lexicon. `game/scripts/language/house_english.gd` is a deliberately small
prototype renderer. It owns no dialogue, case, job, save or UI state.
Real candidate expressions and their integration risks live in the maintained
`design/HOUSE_ENGLISH_ARTIFACT_APPENDIX.md`; writers must consult it before
adding historical flavor.

Before broad conversion:

1. Audit every opening-shift player-facing string by stratum.
2. Author semantic records for the first report and first maintenance action.
3. Teach 10–12 terms through the clock, register, report and apparatus.
4. Build comprehension and accessibility presentations over identical facts.
5. Run blind player tests before converting later cases.
6. Commission historical-linguistic and community review.

## Failure conditions

Stop or narrow the system if it becomes phonetic caricature, makes residents
interchangeable, hides safety/navigation information, requires glossary
memorization before action, breaks localization, or causes players to skip
dialogue rather than infer it. In that event retain House English as
occupational texture instead of universal presentation.
