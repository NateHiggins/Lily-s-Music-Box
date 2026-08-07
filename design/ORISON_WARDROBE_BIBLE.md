# THE ORISON WARDROBE BIBLE

Appearance and fashion criteria for the eighteen residents, written so
that A-pose generation prompts can be derived directly from each entry.

Companion to `ORISON_BIBLE.md` §IV (identity, face, wound) and
`ORISON_RELATIONSHIP_WEB.md`. Where this document adds backstory it
*extends* those; it does not contradict them. Signature garments named
in the bible are canon and appear here unchanged.

---

## I. THE RULE, APPLIED TO CLOTHES

The bible's engine is **both true**: the Orison is a real prewar block in
Queens *and* it is purgatory; the residents have leases *and* some have
been here for centuries. Neither reading is allowed to win.

Clothing obeys this or it breaks the game. Every outfit must read as
**ordinary contemporary dress** — a real person who bought real things
in a real borough — *and* as very slightly **out of time**, in a way no
single garment can be blamed for.

The way to achieve that is not costume. It is **persistence**: things
kept far past their replacement date, mended rather than replaced, worn
in a cut that stopped being current a while ago and was never updated.
A cardigan from a shop that closed. A coat re-lined twice. Shoes resoled
so often the shape has changed. Read one way, this is a person who does
not shop much. Read the other way, it is a person for whom time has not
been passing normally. **Both true.**

Forbidden, because they resolve the ambiguity:
- Explicit period costume (nobody is in 1926 dress).
- Loud current-season fashion, visible brand marks, slogans, logos.
- Anything supernatural, uncanny, or "wrong" as a garment. The clothes
  are never the horror. The clothes are the ordinary reading, held
  perfectly, for as long as possible.

---

## II. THE THREE STATES

Each resident gets three models. They are not three outfits — they are
three degrees of **presentation**, and the character is what survives
between them.

**1. STREET — going out to the shop and back.**
Fully presented: outerwear, hair done, whatever face they put on.
Not "dressed up" — this is the twenty-minute errand, which is exactly
why it is revealing. What does this person consider the *minimum*
acceptable state for being seen by neighbours? Evelyn's minimum is a
different planet from Cam's. Carries the thing they never leave without.

**2. LATE NIGHT — dishevelled, in their own apartment, 3 a.m.**
The hour the game lives in. Nobody is coming over. Layers shed,
softened, mismatched; the day's structure abandoned but not replaced.
Feet are the tell here — bare, socked, slippers with the backs trodden
flat. Hair released from whatever held it. Face bare or half-removed.
This is the state most residents are actually *in* when the player meets
them, so it carries the most weight.

**3. TOWEL — interrupted in the shower.**
A single towel, wet hair, no makeup, no jewellery except what never
comes off. The purpose is not exposure; it is the removal of every
authored signal at once. Whatever still reads as this person here —
posture, hair, the mark on the skin, the one ring they never take off —
is the irreducible character. Model modestly and practically: towel
secured, natural stance, the expression of someone who has answered a
door they wish they hadn't.

Cross-state rules:
- **The body is constant.** Height, build and canon body scales come
  from `resident_hero_models.json` / the applied body factors. Wardrobe
  never changes silhouette mass.
- **The signature item persists where it plausibly can.** Cal's hearing
  aid is in all three. Mae's gloves are in one. Evelyn's pencil is in
  two. Deciding which survives into the towel is the character work.
- **Wear state is consistent.** A garment worn thin in STREET is worn
  thin in LATE NIGHT.

---

## III. WHAT EVERY A-POSE PROMPT MUST CARRY

These are mesh-and-texture source images. The pipeline is the same as
the existing dump route (`art/blender/meshy/<set>/` →
`convert_dump_characters.py` → retarget onto the shared 22-joint
resident skeleton via `resident_moves.glb`), so the images must be
generation-friendly first and beautiful second.

Every prompt states, in this order:

1. **A-pose, standing, symmetrical**, arms down and out at roughly 45°,
   palms facing the body, feet shoulder-width, weight even, looking
   straight ahead. No contrapposto, no attitude, no crossed limbs.
2. **Full body, head to below the feet, nothing cropped**, orthographic
   or long-lens front view, subject centred, plain flat mid-grey
   background.
3. **Flat even diffuse studio lighting, no cast shadows, no rim light,
   no dramatic key.** Shadow baked into a texture is a defect forever.
4. **Neutral face, mouth closed, eyes open, no expression.**
5. The garments, top to bottom, **each with fabric, cut, colour and
   wear state** — never "a jacket", always "a boiled-wool car coat,
   bottle green, cuffs gone shiny, one button replaced in the wrong
   shade".
6. Hair and face state.
7. Footwear (or bare feet), stated explicitly — feet are cropped or
   invented otherwise.
8. **No props held in the hands.** The A-pose must keep hands clear.
   Signature items are worn, pocketed, or slung — never gripped.
9. Closing tech: *neutral colours under neutral light, no stylisation,
   no filter, photoreal, consistent character, full figure visible.*

---

## IV. SHARED VOCABULARY

Use these exact terms so eighteen characters stay in one world.

**Wear states**, weakest to strongest: *fresh · settled (washed soft,
holding shape) · shiny (cuffs, elbows, seat) · thin (weave visible at
stress points) · mended (a repair that matches) · visibly repaired (a
repair that does not match, and was allowed to show) · failing.*

**Palette discipline.** The building is plaster cream, oak amber, dull
brass, cold night blue. Residents are muted and desaturated against it,
each owning **one** colour that is theirs. No two adjacent units share a
signature colour. Nobody wears pure black or pure white — both read as
graphic-design, not laundry.

**Fabrics that carry the world:** boiled wool, brushed cotton, corduroy,
flannel, worn denim, ribbed knit, waffle thermal, oilcloth, cotton
twill, quilted nylon, terrycloth. **Fabrics to avoid:** technical
athleisure, sequins, latex, anything with a visible logo weave.

---

## V. THE RESIDENTS

Each entry: **Extension** (backstory added here, to motivate dress) ·
**Colour · Silhouette · Fabrics · Hair/face · Signature** · then the
three states.

---

### 1A — Evelyn Marsh · retired teacher
**Extension.** Taught fourth grade thirty-one years in the same
building; retired the year they repainted her room and did not tell her.
Buys clothes to last and is quietly proud of how long she has made them
last. Irons things nobody will see.
**Colour** plum. **Silhouette** neat, closed, buttoned to the second
button. **Fabrics** lambswool, cotton poplin, tweed. **Hair/face** short
set grey, brushed; a little powder, no more. **Signature** red pencil.

- **STREET** — Plum lambswool cardigan, settled, over an ironed
  cream blouse buttoned high; grey wool A-line skirt to mid-calf;
  fawn mac, unbelted; flat brown lace-ups resoled twice; small stiff
  handbag. Red pencil through her hair above the ear.
- **LATE NIGHT** — Same cardigan over a long nightgown, sleeves pushed
  up; wool socks; tartan slippers trodden flat. Reading glasses pushed
  up into the hair. Pencil on her, still.
- **TOWEL** — Cream towel, tucked and firmly held. Wet grey hair pushed
  straight back. No spectacles. Thin gold wedding band she has not
  removed since 1979.

### 1D — Teresa Vale · night nurse
**Extension.** Twenty-two years of nights. Sleeps 10 a.m. to 5 p.m. and
does the shop on the way home in yesterday's clothes. Owns nothing that
needs ironing.
**Colour** navy. **Silhouette** utilitarian, pocketed, nothing loose.
**Fabrics** poly-cotton scrub twill, fleece. **Hair/face** dark hair
scraped into a low bun, flyaway; bare face, permanent under-eye
shadow. **Signature** dented steel thermos.

- **STREET** — Navy scrub top and trousers, laundered thin, worn *out*
  of the hospital because there was no point changing; grey fleece
  half-zip over it; white trainers scuffed grey. Lanyard tucked into
  the neckline. Thermos under one arm.
- **LATE NIGHT** — Scrub trousers, oversized faded T-shirt, no fleece;
  thick hospital socks, no shoes. Bun collapsed. Blackout-curtain
  daylight in the room behind her.
- **TOWEL** — Navy towel. Wet hair flat. Bare face. The watch stays on:
  she times things without deciding to.

### 2A — Mina Vale · caption editor, former court reporter
**Extension.** Twenty-two years certified; her ears began editing the
record and four blank seconds ended it. Dresses as though still due in
court — sharp, contained, correct — for work she does alone in a room.
**Colour** slate. **Silhouette** structured, precise, everything
aligned. **Fabrics** worsted wool, cotton shirting. **Hair/face** dark
hair, blunt shoulder-length, exactly level; concealer, defined brow.
**Signature** an editing stylus behind the ear.

- **STREET** — Slate-grey blazer, shoulders holding their shape,
  buttoned once; white shirt, collar crisp; straight charcoal trousers,
  hem exact; low block-heel boots polished. Small crossbody. Overdressed
  for the shop and aware of it.
- **LATE NIGHT** — Shirt untucked and half-unbuttoned over soft shorts;
  cardigan slipping off one shoulder; bare feet. Hair behind one ear.
  Makeup half-removed — one eye done, one clean. The most undone anyone
  in this building gets.
- **TOWEL** — Grey towel. Wet hair pushed back, the blunt cut obvious.
  Bare face, and the contrast is severe: without the line she looks
  years younger and much less certain.

### 2B — Lena Ortiz · seamstress
**Extension.** Alters for half the block and refuses payment from three
of them. Her own hems are pinned, not sewn — she means to get to them.
**Colour** burgundy. **Silhouette** layered, soft, sleeves always
pushed. **Fabrics** knit, cotton lawn, wool suiting offcuts. **Hair/face**
black hair in a low twist held by a fabric scrap; bare, warm.
**Signature** shears; a pincushion band at the wrist.

- **STREET** — Burgundy knit cardigan, visibly repaired at both elbows
  in contrasting thread and *proud of it*; cotton print blouse she made;
  wide navy trousers, one hem pinned; canvas shoes. Tape measure round
  the neck she forgot to take off.
- **LATE NIGHT** — Same cardigan over a slip, belted with a scrap;
  wool socks. Twist loosened. Pincushion still on her wrist.
- **TOWEL** — Deep red towel. Wet black hair down, much longer than
  anyone sees. The pincushion band is *off* — this is the only state
  where it is, and that is the point.

### 2C — Juno Kells · audio artist
**Extension.** Her piece was taken, uncredited, by someone who is now
better known. Buys almost everything second-hand and cuts the labels
out. Dresses for a night bus and a long walk.
**Colour** oxidised teal. **Silhouette** boxy, oversized, hood up.
**Fabrics** heavy cotton, quilted nylon, ripstop. **Hair/face**
asymmetric crop, bleached ends grown out two inches; smudged liner.
**Signature** field recorder on a strap; foam windscreen.

- **STREET** — Teal quilted jacket, one cuff frayed, over an oversized
  washed-black tee; wide grey cargo trousers; heavy boots unlaced at the
  top. Recorder slung across the body, headphones round the neck.
- **LATE NIGHT** — Tee and boxer shorts, thermal socks; the jacket over
  it because the flat is cold. Crop pushed flat on one side from lying
  down. Liner from yesterday.
- **TOWEL** — Teal towel. Wet crop pushed off the face, showing how
  uneven the grow-out is. Small silver ear cuff that never comes off.

### 3A — Malcolm Reed · horticulturist
**Extension.** Keeps a cutting alive that was taken from a plant in a
house he no longer visits. Everything he owns has soil in the seam.
**Colour** moss. **Silhouette** heavy, practical, sleeves rolled.
**Fabrics** waxed cotton, moleskin, wool. **Hair/face** greying curls
too long, pushed back; weathered, unshaven two days. **Signature**
secateurs in a hip sheath; earth under the nails, permanently.

- **STREET** — Olive waxed jacket, reproofed until it has gone dark at
  the shoulders; moss-green moleskin trousers, knees shaped; brown
  jumper thin at the elbow; boots caked at the welt. Sheath on the belt.
- **LATE NIGHT** — Jumper over long johns, no trousers; thick socks.
  Curls flat. Reading a seed catalogue is implied, not held.
- **TOWEL** — Green towel. Wet curls. Hands and forearms noticeably
  darker than the rest, and the nails still not clean.

### 3B — Omar Bell · repair technician
**Extension.** Cannot say a thing is unrepairable; the flat is stacked
with other people's broken things they never came back for. His own
clothes are the most repaired in the building.
**Colour** ochre. **Silhouette** aproned, pocketed, everything to hand.
**Fabrics** duck canvas, chambray, leather. **Hair/face** close-cropped,
receding, neat; steel-rimmed glasses, always slightly smudged.
**Signature** work apron with categorised tool pockets.

- **STREET** — Ochre duck-canvas work apron over a chambray shirt —
  worn to the shop because taking it off is a decision; brown cords;
  boots with mismatched laces, one replaced with cord. Reading glasses
  hooked in the apron bib.
- **LATE NIGHT** — Chambray shirt open over a vest, apron finally off
  and hung visibly in frame; pyjama trousers; bare feet. Glasses on.
- **TOWEL** — Ochre towel, faded to sand. Wet head. Without the apron
  he reads oddly unarmoured — no pockets, nothing to hand.

### 3D — Rhea Sato · vocal coach
**Extension.** Every error she has made is filed somewhere she can find
it. Dresses with total control because the voice is the thing she cannot
control.
**Colour** ink blue. **Silhouette** severe, clean-lined, high neck.
**Fabrics** fine merino, silk, matte crepe. **Hair/face** severe black
bob, blunt, exact; matte skin, strong lip. **Signature** tuning fork on
a neck chain.

- **STREET** — Ink-blue high-neck merino, no ornament; long matte crepe
  skirt; charcoal wool coat, straight, belted; polished ankle boots.
  Tuning fork on its chain, outside the collar. Immaculate for a shop
  run and immaculate on purpose.
- **LATE NIGHT** — Silk robe over a camisole, cord tied twice; bare
  legs, one sock. Bob unpinned on one side. Lip gone, leaving stain in
  the lip line only. Steam mug implied by a scarf round the throat.
- **TOWEL** — Ink towel. Wet bob dead straight. Bare mouth. Fork chain
  still on — she does not take it off, and here it is the only line on
  her.

### 4A — Peter Wren · legal clerk
**Extension.** Files a form to avoid a decision. Nothing he wears fits,
because being measured is also a decision.
**Colour** brown. **Silhouette** rumpled, slightly too large, untucked.
**Fabrics** poly-blend suiting, brushed cotton. **Hair/face** thinning
brown hair, side part collapsing; permanently apologetic.
**Signature** overfilled wallet distending the pocket.

- **STREET** — Brown poly-blend suit jacket, shiny at the elbows and
  cuffs, over a tan shirt gone cream at the collar; trousers half an
  inch too long, breaking twice on brown shoes; wallet visibly
  distorting the inside pocket. No coat, wrong weather.
- **LATE NIGHT** — Shirt untucked over pyjama trousers, socks with
  shoes just removed; cardigan buttoned wrong by one. Hair flattened.
- **TOWEL** — Brown towel held with one hand, clearly not confident it
  will hold. Wet thin hair to the scalp. Sunburn line at the collar
  from a single afternoon outdoors.

### 4C — Cam Ortiz · bicycle courier
**Extension.** Ortiz family, with Lena, who mends the shell they will
not replace. Rest reads as collapse, so they are always mid-motion.
**Colour** maroon. **Silhouette** close, layered, nothing to catch.
**Fabrics** ripstop nylon, merino base, lycra. **Hair/face** dark hair
shaved at the sides, sweat-damp at the front; wind-reddened cheeks.
**Signature** messenger bag — *worn over one shoulder with the second
stabilising strap across the chest*, which is the detail that makes it a
working bag and not an accessory.

- **STREET** — Maroon ripstop cycling shell, one shoulder mended in
  non-matching thread (Lena's work, and it shows); black merino long
  sleeve under; three-quarter cycling tights over calf socks; stiff
  flat-soled shoes. Bag on, cross-strap fastened. Cycling cap, peak up.
- **LATE NIGHT** — Base layer and shorts, one sock; the shell over it
  because they came in and did not fully undress. Cap off, hair flat in
  a ring. Still not sitting.
- **TOWEL** — Maroon towel. Wet hair pushed up. Tan lines are the story:
  hard cuts at mid-bicep, mid-thigh and sock height, the rest pale.

### 4C — Noel Price · museum preparator
**Extension.** Preserved the family life into untouchability; every
object in the flat is placed and nothing is used. Dresses in the museum
register at home.
**Colour** indigo. **Silhouette** clean, square, deliberate.
**Fabrics** cotton drill, chore-coat twill. **Hair/face** dark hair
neatly grown out; calm, closed. **Signature** nitrile gloves — **blue-
purple, not white cotton**; nitrile is the actual museum standard
(vinyl goes acidic, latex tarnishes silver), and the white-cotton
version is a film invention.

- **STREET** — Indigo cotton chore coat, settled, pockets flat and
  empty; grey crew jumper; straight dark trousers, cuffed once; plain
  leather shoes kept clean. A folded pair of blue nitrile gloves in the
  breast pocket, not worn.
- **LATE NIGHT** — Chore coat off and *hung*, in frame; jumper and soft
  trousers; slippers with the backs intact, because he does not tread
  them down. The tidiest 3 a.m. in the building.
- **TOWEL** — Indigo towel, folded edge aligned. Wet hair combed even
  now. Hands bare, and they look strange bare.

### 4D — Transient Guests · a replaceable pair
**Extension.** Perpetually about to leave. Never fully unpacked, so they
wear the top layer of the case.
**Colour** none of their own — greys and whatever was on top.
**Silhouette** mismatched, travel-creased. **Fabrics** wrinkled
poly-cotton, packable nylon. **Hair/face** indeterminate, tired.
**Signature** mismatched luggage; a coat still with a baggage tag.

- **STREET** — Both in creased layers that do not agree with each other
  or the season; one in a packable nylon jacket still folded-marked, one
  in an overcoat with an airline tag on the loop; wheeled case and a
  soft holdall that do not match.
- **LATE NIGHT** — Hotel-logic sleepwear: a T-shirt and unfamiliar
  shorts, one in yesterday's shirt. Case open on the floor, still
  packed.
- **TOWEL** — Mismatched towels, one clearly the building's. Wet hair.
  Nothing personal on either of them at all — no ring, no chain, no
  mark. *They carry no signature, and that is the character.*

### 5A — Nadia Quell · architect
**Extension.** Was silenced about violations once and signs the
welcome letter "Management" rather than her name. Dresses for authority
she is not sure she still has.
**Colour** oxblood. **Silhouette** sharp, tailored, one bold line.
**Fabrics** heavy wool, structured cotton. **Hair/face** dark hair
pulled back severely; strong brow, oxblood lip. **Signature** slim
folding rule in the coat pocket.

- **STREET** — Oxblood wool coat, sharply cut, buttoned; black
  high-neck; wide charcoal trousers with a hard crease; architectural
  flat shoes. Folding rule in the pocket, protruding. Reads as somebody
  going to a meeting, buying milk.
- **LATE NIGHT** — High-neck and wide trousers with the coat gone and
  the crease collapsed; hair released; lip gone. Barefoot on a floor she
  probably has opinions about.
- **TOWEL** — Oxblood towel. Wet hair back. Bare face and the brow is
  still the strongest thing about her.

### 5B — Cal Dwyer · radio collector
**Extension.** Tunes to preserve moments by preventing their ending. The
cardigan is the one he was wearing on a night he will not describe.
**Colour** mustard. **Silhouette** soft, sagged, pocket-heavy.
**Fabrics** thick wool knit, brushed flannel. **Hair/face** white hair,
soft and uncombed; hearing aid, beige, plainly visible. **Signature**
the hearing aid — **in all three states**, because it is not a costume
choice.

- **STREET** — Mustard cardigan, pockets sagging with objects, elbows
  gone thin; checked flannel shirt buttoned to the top; brown trousers
  with a belt on a worn hole; slip-on shoes. Cap. Hearing aid clear of
  the ear.
- **LATE NIGHT** — Same cardigan over pyjamas — he does not take it off;
  slippers flattened past use. Hair up on one side. Aid still in, at
  3 a.m., which says everything.
- **TOWEL** — Mustard-yellow towel gone pale. Wet white hair. Aid **out**
  and held-not-held — set aside in frame. The one state where he cannot
  hear, and the only image of him without it.

### 5C — Iris Bell · painter
**Extension.** Works for imagined audiences and cannot stop performing
for them. Her coveralls are the most honest object she owns.
**Colour** ultramarine. **Silhouette** loose, wrapped, sleeves shoved.
**Fabrics** cotton duck, jersey, headscarf cotton. **Hair/face** hair
wrapped in a printed scarf; paint on the hands and one cheekbone.
**Signature** the ruined coveralls; a scarf.

- **STREET** — Paint-ruined cotton coveralls, decades of layered
  colour, worn *out* — she has stopped noticing; long cardigan over;
  printed headscarf; canvas shoes stiff with dried paint. Ultramarine
  dominates the accretion.
- **LATE NIGHT** — Coveralls off the shoulders and tied at the waist by
  the sleeves; vest; bare feet with paint on them. Scarf off, hair a
  flattened mass.
- **TOWEL** — Blue towel. Wet hair, and it is far longer than the scarf
  implies. Paint **still** on the hands and under the nails after
  washing — the one thing that does not come off.

### 6A — Sacha Reed · photographer-documentarian (they/them)
**Extension.** The recording displaced the experience; there is almost
no photograph of them. Dresses in what has pockets and does not rustle.
**Colour** slate green. **Silhouette** utilitarian, strapped, layered.
**Fabrics** cotton canvas, fleece, nylon webbing. **Hair/face** shaved
close at the back, longer on top; bare face, sharp eyes.
**Signature** a tangle of camera straps and adapters round the neck.

- **STREET** — Slate-green canvas jacket with too many pockets, all
  used; grey tee; dark utility trousers; low canvas boots. Two straps
  crossed at the chest, adapters clipped to the webbing. No visible
  camera body — the tangle without the camera is the character.
- **LATE NIGHT** — Tee and loose shorts, one strap *still* round the
  neck out of habit; socks. Hair up on one side.
- **TOWEL** — Slate towel. Wet hair pushed back. The strap is off, and
  the tan line where it crosses the neck is the only mark on them.

### 6B — Jonah Price · insomniac writer
**Extension.** Avoids endings until they bite. Has not fully dressed on
a weekday in a long time; the robe has become the outfit.
**Colour** navy. **Silhouette** enveloped, corded, collar up.
**Fabrics** heavy cotton robe, brushed flannel, wool. **Hair/face**
unbrushed brown hair, a week unshaven; ink on the fingers.
**Signature** navy robe; annotated notebook in the pocket.

- **STREET** — Navy robe replaced — barely — by a navy overcoat worn
  *over pyjama trousers*, which is the joke and the tragedy; flannel
  shirt; unlaced shoes. Notebook in the coat pocket, corner out. He is
  going to the shop and everyone can tell what he is not wearing.
- **LATE NIGHT** — The robe, corded twice, over a shirt; bare shins;
  slippers trodden flat. This is his default and it looks it.
- **TOWEL** — Navy towel. Wet hair pushed straight back off the face,
  which makes him look startlingly awake. Ink still on two fingers.

### 6C — Mae Kessler · antiques appraiser
**Extension.** Certainty is not memory: she has authenticated things she
now doubts. Dresses in objects she has appraised and quietly kept.
**Colour** bottle green. **Silhouette** long, structured, buttoned.
**Fabrics** heavy wool melton, silk lining, kid leather.
**Hair/face** silver hair set and pinned; powder, a soft dark lip.
**Signature** white gloves — hers *are* cotton, because she is not a
conservator; she is a dealer of a certain age, and that is a different
and older habit.

- **STREET** — Bottle-green wool melton coat to mid-calf, re-lined
  twice (a flash of a lining that does not match the outside);
  high-collared blouse with a brooch; long grey skirt; polished heeled
  boots. White cotton gloves, worn.
- **LATE NIGHT** — Coat gone, blouse unbuttoned at the throat, brooch
  off and *placed* in frame; long cardigan; stockinged feet. Hair
  released from its pins, still holding the set's shape.
- **TOWEL** — Green towel. Wet silver hair, the set gone completely.
  Gloves off, and the hands are much older than the face she maintains.
  This is the most exposed image in the building.

---

## VI. SEQUENCING

54 models is too many to commit to blind. Take **one character fully
through the pipeline first** — image → mesh → texture → retarget onto
the shared skeleton → in-engine at the right body scale → walk them —
and only then batch the rest.

Recommended first subject: **Cal Dwyer (5B)**. He carries a persistent
signature (the aid) across all three states, one of which removes it, so
he tests the hardest continuity rule; and mustard against navy night
lighting is a real palette test.

Then batch by floor, in this order — F01, F02, F03 (the units the player
reaches first), then F04–F06.

**Verify before batching:** that the retarget holds on a figure in a
long coat (Mae) and on one in a robe (Jonah). Loose hanging garments are
where the shared skeleton is most likely to break, and finding that out
on model 54 is the expensive way.
