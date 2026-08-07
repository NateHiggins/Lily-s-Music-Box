# A-POSE GENERATION PROMPTS

54 prompts: eighteen residents × three states. Derived from
`ORISON_WARDROBE_BIBLE.md`; read §I–IV of that first.

## How to assemble

Every prompt is **PREAMBLE + BODY + TAIL**. Paste the three together in
that order.

This is not laziness. These images feed a mesh-and-texture pipeline, and
the part the pipeline depends on is the pose, framing and lighting spec
— which must be *byte-identical* across all 54 or model 40 will retarget
differently from model 3. Writing 54 self-contained paragraphs
guarantees that drift. Here the invariant part exists once, and the only
thing that varies between prompts is the only thing that should.

Filenames: `<sprite>_<state>.png`, e.g. `cal_dwyer_street.png`,
`cal_dwyer_night.png`, `cal_dwyer_towel.png`. Sprite names are the
`RESIDENTS` table in `building_root.gd`.

---

## PREAMBLE  *(fixed — never edit per character)*

```
Full-body character reference sheet of a single adult standing in a
strict A-pose: standing upright and symmetrical, both arms straight and
lowered away from the body at roughly 45 degrees, palms facing the
thighs, fingers relaxed and slightly apart, feet flat and shoulder-width
apart, weight even on both legs, shoulders level, head straight and
facing directly forward. No contrapposto, no weight on one hip, no
crossed limbs, no turned head, no gesture, no attitude. Neutral relaxed
face, mouth closed, eyes open, no expression, no smile. Entire figure
visible from above the head to below the feet with nothing cropped.
Straight-on front view, long lens, no perspective distortion, subject
centred on a plain flat mid-grey background.
```

## TAIL  *(fixed — never edit per character)*

```
Flat even diffuse studio lighting from the front, completely shadowless:
no cast shadows, no contact shadow on the ground, no rim light, no key
light, no dramatic lighting, no coloured light. Colours as they are
under neutral daylight. Photorealistic, natural proportions, ordinary
real person, not stylised, not idealised, no filter, no grain, no
vignette, no text, no watermark, no logo, no border. Both hands empty
and clearly visible. High resolution, sharp throughout, suitable for
photogrammetry and 3D character reconstruction.
```

**Why the tail says what it says.** Baked shadow is permanent — it
becomes texture and can never be lit away. Empty hands keep the A-pose
clean and let signature items be worn, slung or pocketed instead.

---

# THE BODIES

Format: **STREET** · **NIGHT** · **TOWEL** per resident.

---

## 1A · Evelyn Marsh — `evelyn_marsh`
- **STREET** — A woman in her seventies, short set grey hair brushed neatly, light powder and nothing else. She wears a plum lambswool cardigan, soft with age but holding its shape, buttoned to the second button over an ironed cream cotton blouse fastened high at the throat; a grey wool A-line skirt to mid-calf; an unbelted fawn raincoat hanging open; flat brown leather lace-up shoes, resoled and polished. A red pencil is pushed into her hair above one ear. A small stiff-framed handbag hangs from one forearm.
- **NIGHT** — A woman in her seventies, short grey hair flattened on one side, face bare, reading glasses pushed up into her hair. She wears the same plum lambswool cardigan with the sleeves pushed to the elbow over a long pale cotton nightgown to mid-calf; thick cream wool socks; tartan slippers with the backs trodden flat. A red pencil is still pushed into her hair.
- **TOWEL** — A woman in her seventies wrapped in a cream bath towel, tucked securely under the arms and reaching the knee, held with one hand. Wet grey hair pushed straight back from the face. Bare face, no glasses, no jewellery except a thin worn gold wedding band. Bare feet.

## 1D · Teresa Vale — `teresa_vale`
- **STREET** — A tired woman in her forties, dark hair scraped into a low bun with flyaway strands, bare face with pronounced shadows under the eyes. She wears navy hospital scrubs, top and drawstring trousers, laundered thin and slightly faded; a grey fleece half-zip pulled over the scrub top; white trainers scuffed grey at the toe. A hospital lanyard is tucked into the neckline. She carries a dented steel thermos under one arm.
- **NIGHT** — A tired woman in her forties, dark hair half out of a collapsed bun, bare face. She wears navy scrub trousers and a large faded oversized cotton T-shirt, no fleece; thick grey hospital socks; no shoes. A plain functional wristwatch.
- **TOWEL** — A woman in her forties wrapped in a navy bath towel tucked under the arms to the knee. Wet dark hair pushed flat back. Bare face, deep shadows under the eyes. Bare feet. A plain functional wristwatch still on the wrist.

## 2A · Mina Vale — `mina_vale`
- **STREET** — A composed woman in her forties, dark hair in a blunt shoulder-length cut exactly level, concealer and a defined brow. She wears a slate-grey wool blazer holding its shoulder line, buttoned once, over a crisp white cotton shirt; straight charcoal trousers with an exact hem; polished low block-heel ankle boots. A small structured crossbody bag. An editing stylus is tucked behind one ear.
- **NIGHT** — A woman in her forties, dark blunt-cut hair tucked behind one ear, makeup half removed so one eye is defined and the other is bare. She wears a white cotton shirt untucked and half unbuttoned over soft dark shorts, with a grey cardigan slipping off one shoulder; bare feet, bare legs.
- **TOWEL** — A woman in her forties wrapped in a grey bath towel tucked under the arms to the knee. Wet dark hair pushed straight back, the blunt cut obvious. Completely bare face, no makeup, and she looks younger and less certain without it. Bare feet, no jewellery.

## 2B · Lena Ortiz — `lena_ortiz`
- **STREET** — A warm woman in her fifties, black hair in a low twist held by a scrap of printed fabric, bare face. She wears a burgundy knit cardigan mended at both elbows with visibly contrasting thread, over a homemade cotton print blouse; wide navy trousers with one hem pinned rather than sewn; flat canvas shoes. A cloth tape measure hangs forgotten around her neck and a pincushion band is strapped to one wrist.
- **NIGHT** — A woman in her fifties, black hair loosened out of its twist, bare face. She wears the same mended burgundy cardigan over a plain slip, belted at the waist with a scrap of fabric; thick wool socks. The pincushion band is still on her wrist.
- **TOWEL** — A woman in her fifties wrapped in a deep red bath towel tucked under the arms to the knee. Wet black hair loose and much longer than expected, past the shoulders. Bare face. Both wrists bare. Bare feet.

## 2C · Juno Kells — `juno_kells`
- **STREET** — A woman in her late twenties with an asymmetric crop, bleached ends grown out about two inches showing dark roots, smudged dark eyeliner. She wears a boxy oxidised-teal quilted jacket with one cuff frayed through, over an oversized washed-black T-shirt; wide grey cargo trousers; heavy boots left unlaced at the top. A small field recorder on a strap across her body and headphones round her neck.
- **NIGHT** — A woman in her late twenties, asymmetric crop pushed flat on one side, yesterday's eyeliner smudged. She wears an oversized washed-black T-shirt and boxer shorts with thick thermal socks, the teal quilted jacket pulled on over the top because the flat is cold.
- **TOWEL** — A woman in her late twenties wrapped in a teal bath towel tucked under the arms to the knee. Wet cropped hair pushed off the face, the uneven bleached grow-out obvious. Bare face. A small silver ear cuff. Bare feet.

## 3A · Malcolm Reed — `malcolm_reed`
- **STREET** — A weathered man in his sixties, greying curls grown too long and pushed back, two days unshaven. He wears an olive waxed cotton jacket gone dark at the shoulders from reproofing, over a thin brown wool jumper worn through at one elbow; moss-green moleskin trousers shaped at the knee; heavy boots caked with dried soil at the welt. A leather secateurs sheath on his belt. Permanent dirt under the fingernails.
- **NIGHT** — A man in his sixties, grey curls flattened, unshaven. He wears the thin brown wool jumper over long johns with no trousers; thick wool socks; bare feet in the socks, no slippers.
- **TOWEL** — A man in his sixties wrapped in a green bath towel secured at the waist, bare chest. Wet grey curls. Forearms and hands noticeably more weathered and darker than the rest of him, with dirt still under the fingernails after washing. Bare feet.

## 3B · Omar Bell — `omar_bell`
- **STREET** — A methodical man in his fifties, close-cropped receding hair, steel-rimmed glasses slightly smudged. He wears a heavy ochre duck-canvas work apron with many categorised tool pockets, worn over a blue chambray shirt; brown corduroy trousers; work boots with mismatched laces, one replaced with plain cord. A pair of reading glasses hooked into the apron bib.
- **NIGHT** — A man in his fifties, close-cropped hair, steel-rimmed glasses on. He wears a blue chambray shirt hanging open over a white vest, no apron; soft pyjama trousers; bare feet.
- **TOWEL** — A man in his fifties wrapped in a faded ochre bath towel secured at the waist, bare chest. Wet head. Steel-rimmed glasses still on, slightly fogged. Bare feet. Without pockets he looks noticeably unarmoured.

## 3D · Rhea Sato — `rhea_sato`
- **STREET** — A precise woman in her forties, severe blunt black bob, matte skin and a strong defined lip. She wears an ink-blue fine merino high-neck top with no ornament; a long matte crepe skirt; a straight charcoal wool coat, belted; polished ankle boots. A small tuning fork hangs on a fine chain outside the collar.
- **NIGHT** — A woman in her forties, black bob unpinned and falling on one side, lip colour gone leaving only a stain in the lip line. She wears a silk robe over a camisole, the cord tied twice; bare legs; one sock on and one foot bare. A light scarf wrapped round her throat.
- **TOWEL** — A woman in her forties wrapped in an ink-blue bath towel tucked under the arms to the knee. Wet black bob hanging dead straight. Completely bare mouth and face. A fine chain with a small tuning fork still round her neck, the only line on her. Bare feet.

## 4A · Peter Wren — `peter_wren`
- **STREET** — An apologetic man in his fifties, thinning brown hair with a collapsing side part. He wears a brown poly-blend suit jacket gone shiny at the elbows and cuffs over a tan shirt whose collar has faded to cream; suit trousers half an inch too long, breaking twice over brown shoes. A thick overfilled wallet visibly distorts the inside breast pocket. No coat, dressed for the wrong weather.
- **NIGHT** — A man in his fifties, thin hair flattened. He wears a tan shirt untucked over pyjama trousers, with a cardigan buttoned wrong by one button; dark socks with the shoes just removed.
- **TOWEL** — A man in his fifties wrapped in a brown bath towel at the waist, held with one hand and clearly not trusted to stay. Wet thin hair flat to the scalp. A distinct sunburn line at the collarbone from a single afternoon outdoors. Bare feet.

## 4C · Cam Ortiz — `cam_ortiz`
- **STREET** — A lean courier in their thirties, dark hair shaved at the sides and sweat-damp at the front, wind-reddened cheeks. They wear a close-fitting maroon ripstop cycling shell with one shoulder mended in non-matching thread; a black merino long-sleeve base layer underneath; three-quarter cycling tights over calf socks; stiff flat-soled cycling shoes. A messenger bag worn over one shoulder with its second stabilising strap fastened across the chest. A cycling cap with the peak turned up.
- **NIGHT** — A courier in their thirties, dark hair flattened in a ring from the cap. They wear a black merino base layer and shorts with one sock on, the maroon shell pulled back over the top as though they came in and never fully undressed.
- **TOWEL** — A lean person in their thirties wrapped in a maroon bath towel at the waist. Wet dark hair pushed up. Pronounced cyclist's tan lines: sharp cuts at mid-bicep, mid-thigh and sock height, the skin pale between them. Bare feet.

## 4C · Noel Price — `noel_price`
- **STREET** — A calm, contained man in his forties, dark hair neatly grown out. He wears an indigo cotton chore coat, soft with washing, its pockets flat and empty; a grey crew-neck jumper; straight dark trousers cuffed once; plain leather shoes kept clean. A folded pair of blue-purple nitrile gloves in the breast pocket, not worn.
- **NIGHT** — A man in his forties, dark hair still neat. He wears a grey crew-neck jumper and soft trousers, no coat; slippers with the backs intact and unflattened.
- **TOWEL** — A man in his forties wrapped in an indigo bath towel at the waist, its folded edge aligned. Wet dark hair combed flat even now. Bare hands, which look strange and exposed. Bare feet.

## 4D · Transient Guests — `transient_guests`
*(a pair — generate as two separate figures, A and B, in the same three states)*
- **STREET** — Two travellers of indeterminate age standing side by side, tired, dressed in creased layers that agree neither with each other nor with the season. One wears a packable nylon jacket still marked with fold creases; the other an overcoat with an airline baggage tag still looped to the buttonhole. Mismatched luggage at their feet: one hard wheeled case, one soft holdall.
- **NIGHT** — Two travellers in mismatched hotel-logic sleepwear: one in a plain T-shirt and unfamiliar shorts, the other still in yesterday's shirt. Bare feet.
- **TOWEL** — Two people wrapped in mismatched bath towels, one clearly institutional. Wet hair. Nothing personal on either of them at all: no ring, no chain, no watch, no mark.

## 5A · Nadia Quell — `nadia_quell`
- **STREET** — An authoritative woman in her fifties, dark hair pulled back severely, a strong brow and an oxblood lip. She wears a sharply cut oxblood wool coat, buttoned, over a black high-neck top; wide charcoal trousers with a hard pressed crease; flat architectural shoes. A slim folding rule protrudes from the coat pocket.
- **NIGHT** — A woman in her fifties, dark hair released from its pull, lip colour gone. She wears the black high-neck top and the wide charcoal trousers with the crease collapsed, no coat; bare feet.
- **TOWEL** — A woman in her fifties wrapped in an oxblood bath towel tucked under the arms to the knee. Wet dark hair pushed straight back. Bare face, the strong brow still the most defined thing about her. Bare feet.

## 5B · Cal Dwyer — `cal_dwyer`
- **STREET** — A gentle man in his seventies, soft uncombed white hair, a beige hearing aid plainly visible behind one ear. He wears a thick mustard wool cardigan with sagging, object-filled pockets and elbows worn thin, over a checked flannel shirt buttoned to the collar; brown trousers held by a belt on a worn hole; slip-on shoes. A flat cap.
- **NIGHT** — A man in his seventies, white hair pushed up on one side. He wears the same mustard cardigan over striped pyjamas — he has not taken it off; slippers flattened past usefulness. The beige hearing aid is still in.
- **TOWEL** — A man in his seventies wrapped in a pale, faded mustard-yellow bath towel at the waist. Wet white hair. **No hearing aid** — the ear is bare, and it is the only image of him without it. Bare feet.

## 5C · Iris Bell — `iris_bell`
- **STREET** — A painter in her sixties, hair wrapped in a printed headscarf, dried paint on her hands and one cheekbone. She wears cotton duck coveralls ruined by decades of layered paint, ultramarine dominating; a long cardigan over the top; canvas shoes stiff with dried paint. She has stopped noticing she is wearing them outdoors.
- **NIGHT** — A woman in her sixties, headscarf off, hair a flattened mass. She wears the paint-ruined coveralls pulled off the shoulders and tied at the waist by their own sleeves, over a plain vest; bare feet with paint on them.
- **TOWEL** — A woman in her sixties wrapped in a blue bath towel tucked under the arms to the knee. Wet hair loose and far longer than the headscarf suggested. Bare face. Paint still visible on her hands and under her fingernails after washing. Bare feet.

## 6A · Sacha Reed — `sacha_reed`
- **STREET** — An androgynous person in their thirties, hair shaved close at the back and longer on top, bare face, sharp eyes. They wear a slate-green cotton canvas jacket with many pockets, all of them used; a grey T-shirt; dark utility trousers; low canvas boots. Two camera straps crossed over the chest with adapters and cable clipped to the webbing, but **no camera body**.
- **NIGHT** — A person in their thirties, hair pushed up on one side. They wear a grey T-shirt and loose shorts with socks, and one camera strap still round the neck out of habit.
- **TOWEL** — A person in their thirties wrapped in a slate bath towel at the waist. Wet hair pushed back. No straps. A faint pale tan line across the side of the neck where a strap normally sits. Bare feet.

## 6B · Jonah Price — `jonah_price`
- **STREET** — A dishevelled man in his forties, unbrushed brown hair, a week unshaven, ink on two fingers. He wears a navy overcoat pulled on **over pyjama trousers**, with a flannel shirt beneath; unlaced shoes. A small annotated notebook protrudes from the coat pocket. He is dressed for a shop run and it is obvious what he is not wearing.
- **NIGHT** — A man in his forties, hair unbrushed, unshaven. He wears a heavy navy cotton robe corded twice over a flannel shirt; bare shins; slippers trodden flat.
- **TOWEL** — A man in his forties wrapped in a navy bath towel at the waist. Wet brown hair pushed straight back off the face, which makes him look startlingly awake. Ink still on two fingers. Bare feet.

## 6C · Mae Kessler — `mae_kessler`
- **STREET** — A poised woman in her seventies, silver hair set and pinned, powder and a soft dark lip. She wears a bottle-green wool melton coat to mid-calf, its lining replaced twice so a mismatched lining shows at the cuff; a high-collared blouse fastened with a brooch; a long grey skirt; polished heeled boots. **White cotton gloves**, worn.
- **NIGHT** — A woman in her seventies, silver hair released from its pins but still holding the shape of the set. She wears the high-collared blouse unbuttoned at the throat with the brooch removed, under a long cardigan; stockinged feet, no shoes. No gloves.
- **TOWEL** — A woman in her seventies wrapped in a green bath towel tucked under the arms to the knee. Wet silver hair with the set gone completely. Bare face. **Bare hands, noticeably older than the face she maintains.** Bare feet.

---

## Order of generation

Per `ORISON_WARDROBE_BIBLE.md` §VI: **Cal Dwyer first**, all three
states, fully through the pipeline before anything else is generated.
He is the continuity test — his signature persists in two states and is
deliberately absent in the third.

Then verify the retarget survives a long coat (**Mae**) and a robe
(**Jonah**) before batching. Loose hanging garments are where the shared
22-joint skeleton is most likely to fail, and discovering that on model
54 is the expensive way to discover it.

Then by floor: F01, F02, F03, then F04–F06.
