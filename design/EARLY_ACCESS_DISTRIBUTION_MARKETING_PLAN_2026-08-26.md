# Early Access distribution and marketing plan — 2026-08-26

> **Implementation update — 2026-08-26:** the settings-surface blocker recorded
> in §§9, 12, 17 and 21 was true at this plan's source commit and has since been
> partially closed. Pushed production now provides persistent Master,
> Gameplay, Voice/Telephone, World/Weather, Music and UI volume controls plus
> opt-in captions for the bounded semantic gameplay-cue catalog. Store copy may
> accurately describe custom volume controls and that narrow cue-caption
> feature after release-candidate verification. It must not claim full closed
> captions, subtitle sizing, dynamic-range presets, remapping or pause-menu
> access until those exist and are tested.

**Status:** operating plan answering **K0-GTM** (`TASKS.md:42`) and the "First
planning gate" of `design/EARLY_ACCESS_GO_TO_MARKET_PROJECT.md`. It converts
that charter's workstreams into dated dependencies, owners, assets, thresholds
and runbooks.

**Scope authority is not this document.** `design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md`
(ADMIN-EA1, commit `627eae5`) owns the promise and the content ceiling, and is
treated here as fixed. **Nothing in this plan expands the build to make
marketing easier.** Where a marketing want would require content, it is written
down as a want and refused.

**Base:** `1d78dc1cce9bc9720f18199f15bed72207dd2066` "Route the Vantry fault
through semantic audio policy".

> **Base-SHA discrepancy, recorded rather than silently resolved.** The
> assignment named `1d78dc167bdb448362971d436185284feb0c64e8`. **No such object
> exists in this repository.** Exactly one commit matches the 7-character
> prefix `1d78dc1` — the current `origin/main` tip above — so the intent is
> unambiguous and that is the commit used. The supplied suffix appears to be a
> transcription error. If a different commit was meant, this document must be
> re-based and re-checked.

**No Godot process was launched. No engine test or capture tool was run. No
production code, data, scene, asset, render, `TASKS.md`, milestone or existing
document was edited. No account was created, no form submitted, no person
contacted, no money spent, no name reserved and no agreement accepted.**

**Evidence convention.** Every platform rule below is marked:
**[SOURCED]** verified against an official page listed in §20, with access date;
**[INFERENCE]** my reasoning from sourced facts, labelled as mine;
**[UNKNOWN]** not established — carried as a question, never as a schedule.

---

## 1. Positioning

### One-line hook

> **Fix the building. Earn the truth. Survive the dark when your body takes
> you.**

### 50-word pitch

> The Orison, 1928. You are the night superintendent of a New York apartment
> house that breaks in ordinary ways and answers in ways that are not ordinary.
> Find the fault by ear. Repair it with your hands. Learn what the tenant is
> really protecting — before your narcolepsy drags you into the dark.

*(49 words.)*

### Store short description

Steam's short description is the blurb under the header capsule.

> Night superintendent, New York, 1928. Trace a fault through a living
> apartment house by sound and lamplight, repair it with your hands, and earn
> the truth from the tenant it belongs to. Then your narcolepsy takes you, and
> the house is not the house any more.

### Three differentiators

1. **The fault is found by ear, not by a waypoint.** The building has an
   acoustic graph and a semantic audio policy; the objective literally reads
   "Find it by ear," and the route is proved against a 45-second
   time-to-target ceiling with no marker of any kind.
   *Evidence: `art/renders/first_minute_k2g/`, `ChirpReachableLiveTest`.*
2. **The house is simulated, not staged.** Residents keep schedules, doors and
   mailboxes; weather, light and sound run whether or not you are watching. The
   same shift is not the same twice.
3. **The horror arrives through a real medical condition, treated seriously.**
   Narcolepsy creates the vulnerable interval — it is not the monster, and the
   game does not say it is.

### "This is not" — boundaries we publish

Stating these prevents the refunds that Early Access earns by omission.

- **Not a campaign.** One case, one shift, roughly 30 minutes, replayable.
- **Not combat.** There is no weapon and no fight; the dark passage is a
  scramble, not an encounter.
- **Not a survival/crafting/base-builder.**
- **Not an open city.** One building, one street, one shop on the route.
- **Not a jump-scare horror.** The fear is pursuit and dark, not a startle reel.
- **Not finished.** The store page will carry the Early Access questionnaire
  answers verbatim and honestly. **[SOURCED — Valve requires the questionnaire
  and forbids specific promises about future content.]**

---

## 2. Audience hypotheses and how we test them

**No market-size claim is made anywhere in this document.** Audience sizing,
pricing comparables and competitor analysis are explicitly out of scope for
this task. What follows are **hypotheses with a test attached**.

| # | Hypothesis | How we would learn we are wrong | Instrument |
| --- | --- | --- | --- |
| A1 | Players who like *immersive-sim-adjacent, job-simulator-shaped* first-person games will finish the shift | FP-3 players describe it as "walking sim" or "too slow" | fresh-player tests (ADMIN-EA1 §9) |
| A2 | The **sound-led hunt** is the thing people repeat back to others | nobody mentions the chirp unprompted in a post-play interview | post-play interview, one open question first |
| A3 | Period-accuracy readers (1920s New York, telephony, building trades) are a real second audience | devlog posts about the house telephone/Vantry apparatus get no engagement relative to gameplay posts | devlog A/B over 6 posts |
| A4 | The narcolepsy framing attracts rather than repels | negative sentiment in comments on the first public devlog naming it | manual read, R6 trigger |
| A5 | Streamers can carry it — the discovery moment is watchable | a creator build produces no clippable moment in 20 minutes | creator kit round 1 |

**Proof plan, in order:** devlog engagement (A3) → demo completion (A1) →
unprompted-mention interviews (A2) → creator round (A5). A4 is monitored
continuously and has a stop condition, not a metric.

---

## 3. Platform decision matrix

| Platform | Fee / cut | Lead time | What it needs from the build | Verdict |
| --- | --- | --- | --- | --- |
| **Steam Early Access** | **$100 Steam Direct per app, recoupable after $1,000 adjusted gross revenue** **[SOURCED]** | store page live **≥2 weeks** before release; store review typically **3–5 business days**; submit **≥7 days** before intended launch **[SOURCED]** | Early Access questionnaire; content survey; **valid age rating or it is invisible in Germany** **[SOURCED]**; capsule family; ≥5 screenshots at ≥1920×1080 | **PRIMARY. Launch here.** |
| **itch.io** | **Open revenue sharing — the seller chooses the platform share, default 10%**; payment processing (e.g. Stripe $0.30 + 2.9%) is passed through **[SOURCED]** | effectively none; free to upload **[SOURCED]** | a build and a page | **SECONDARY, same day.** Near-zero cost, and it is where a demo can live without consuming the one Next Fest slot. |
| **Epic Games Store** | **100% of the first $1M net revenue per product per year, 88/12 thereafter** **[SOURCED, via official EGS announcement pages]** | **[UNKNOWN]** — self-publishing onboarding detail not verifiable from official docs in this pass (403/empty responses) | **[UNKNOWN]** | **LATER CANDIDATE.** Re-audit before H3. Do not plan around it. |
| **GOG** | **[UNKNOWN]** | human-curated; GOG asks for submission **at final stage or after release elsewhere**, and reserves the right not to respond **[SOURCED]** | **DRM-free release candidate for every supported OS**, 1920×1080+ assets, trailer with GOG logo, age ratings **[SOURCED]** | **LATER, AND CONDITIONAL.** The DRM-free RC is a real engineering ask. Not before H4. |
| **Consoles** | — | — | certification, controller-only play, platform TRC/TCR compliance | **OUT OF SCOPE.** Mobile is already deprioritised by owner ruling (`TASKS.md:3187`); consoles are further out. |

### Recommendation

**Steam Early Access as the primary channel, itch.io as a same-day secondary,
and nothing else until after launch.**

Reasoning **[INFERENCE]**: Steam is the only channel whose requirements the
project can meet on the ADMIN-EA1 critical path, and the only one where the
demo, the festival, the wishlist notification and the Early Access disclosure
are one coherent system. itch.io costs essentially nothing to run alongside and
gives a second home for the demo. Epic and GOG each carry an unquantified
engineering ask (**[UNKNOWN]** onboarding, DRM-free RC) that would compete with
the accessibility surface and the route performance work, which are already
launch blockers.

### One platform fact that changes marketing strategy

**[SOURCED]** Valve states plainly that **wishlists are *not* a factor in
algorithmic visibility on Steam.** Their stated value is the launch/Early-Access/
20%-discount email to the people who wishlisted. Valve names *purchases and
player engagement* as the strong signal, and says store-page traffic and
conversion rate do not matter.

**Consequence for this plan:** wishlists are treated as a **notification list**,
not a score. No campaign target in §14 is "raise the wishlist number." This
directly contradicts a widespread industry practice, which is exactly why it is
sourced rather than assumed.

---

## 4. Steamworks readiness checklist

Ordered by what blocks what. All **[SOURCED]** unless marked.

**Account and legal — earliest possible, blocked on nothing**
- [ ] Steamworks partner account; Steam Subscriber Agreement; Steam Distribution Agreement
- [ ] **$100 Steam Direct fee** per app (recoupable after $1,000 AGR)
- [ ] Tax identity and bank/payout details; VAT/GST handling as applicable
- [ ] **[UNKNOWN]** exact identity-verification and banking document list — Valve's fee page does not enumerate them; resolve inside the partner portal
- [ ] Decide the entity that signs. **Owner decision. External accounting/legal review.**

**App setup**
- [ ] Base app created; **separate demo app created via "Add Demo"** (a demo gets its own AppID)
- [ ] Depots, builds, and **branches**: default branch is what customers get and **must be set live manually**; additional branches may be **password-protected**, and the password is required even to see the branch name
- [ ] Content survey completed truthfully
- [ ] **Age rating: Germany is mandatory.** Valve's own questionnaire or a direct USK rating; **IARC-generated USK ratings from third-party stores must not be submitted.** Missing rating ⇒ the game is not displayed to German customers
- [ ] Accessibility Feature Wizard, under store page → Basic Info

**Store page**
- [ ] Coming Soon page live **≥2 weeks** before release
- [ ] Store presence submitted for review **before** the build can be submitted
- [ ] Early Access questionnaire: why EA, expected duration, how the full version differs, current state, pricing plan, community involvement
- [ ] Capsule family and ≥5 screenshots (§6)
- [ ] Short description, long description, system requirements, tags, languages

**Pricing rules to design around**
- [ ] EA price **must not exceed** the price on any other platform
- [ ] **No permanent discounts** while in Early Access
- [ ] After a price increase, **30 days** before discounting or changing again
- [ ] Raising price within **30 days** of leaving EA forfeits the launch discount

**Optional, free, worth doing**
- [ ] **Steam Deck compatibility review** — automatic or on request, results typically within a week; categories Verified / Playable / Unsupported; tested on controller support, legibility, performance and system support. No fee stated.
      **[INFERENCE]** This is the cheapest external accessibility signal available to us, and it partially validates the controller work that is already a launch blocker.

---

## 5. Build-channel design

Mapped onto Steam's actual mechanics rather than invented names.

| Channel | Steam mechanism | Audience | Gate to enter |
| --- | --- | --- | --- |
| **internal** | password-protected branch `internal` | owner, Codex, Claude | any green build |
| **closed external** | password-protected branch `friends` | ≤10 named testers under NDA-lite | FP-1 passed (ADMIN-EA1 §9) |
| **public demo** | **separate demo AppID**, own build | everyone | H2 gates; no debug affordance on route |
| **release candidate** | password-protected branch `rc` | testers + press key holders | ADMIN-EA1 §8 RC gates |
| **Early Access** | **default branch** | customers | H3 gates |
| **rollback / hotfix** | set a **previous build live on the default branch** | customers | see §15 |

**Rules, binding.**
1. **The default branch is never set live automatically** — Valve requires the
   manual action, and we do not automate around it. **[SOURCED]**
2. Every password-protected branch password is treated as public the moment it
   is shared with anyone outside the three-person core. **[INFERENCE]**
3. A build reaches `rc` only after the *same commit* has passed the ADMIN-EA1
   §9 go/no-go table. No hand-built one-off binaries.
4. **The demo build is cut from a release-candidate commit, never from `main`.**

---

## 6. Store-page asset manifest

Dimensions and formats are **[SOURCED]** from Valve's store asset
documentation. "Earliest date" is expressed as a **dependency**, never a
calendar date, because product dates do not exist yet.

| Asset | Spec | Owner | Depends on | Earliest |
| --- | --- | --- | --- | --- |
| **Header capsule** | **920 × 430 JPG**; logo legible; no text beyond title | owner (art) | logo lockup | now |
| **Small capsule** | **462 × 174 PNG**; logo should nearly fill it and stay readable at 120×45 | owner (art) | logo lockup | now |
| **Main capsule** | **1232 × 706 JPG**; logo legible; no marketing quotes | owner (art) | logo lockup | now |
| **Vertical capsule** | **748 × 896 JPG**; title text only | owner (art) | logo lockup | now |
| **Page background** *(optional)* | **1438 × 810 JPG**; auto-derived from last screenshot if omitted | Claude | screenshots | after screenshots |
| **Screenshots ×5+** | **≥1920 × 1080, 16:9**; must **show gameplay exclusively** — no concept art, no marketing copy | Claude (capture), owner (select) | **H2 route polish + no-debug-affordance gate** | **H2** |
| **Trailer** | §7 | Claude (capture) → owner (cut) | same as screenshots | **H2** |
| **Short description** | §1 | Claude | — | now |
| **Long description + EA questionnaire** | §1 boundaries verbatim | Claude → owner sign-off | — | now |
| **System requirements** | — | Codex | **a measurement that does not exist** | see §18 R-SYS |
| **Tags / languages** | — | owner | — | now |

**Capture constraint that gates every image.** ADMIN-EA1 records that 2A
currently renders world-space case labels (`MINA`, `Mina Vale · 2A [ACTIVE]`,
`SOFA`, `DESK`, `CAPTION CALIBRATOR`) and seven interactive `DebugLightHandle`
nodes. **Valve requires screenshots to show gameplay exclusively; a debug
nameplate in a store screenshot is both a rule problem and a credibility
problem.** No screenshot or trailer frame ships until that is ruled on.

---

## 7. Trailer plan

**Only proved release-route beats.** Every shot below is either already
captured under the capture-evidence protocol or is explicitly `GATED` on a
named product gate. Nothing is shot early and cut in.

| # | Beat | Length | Material | State |
| --- | --- | ---: | --- | --- |
| 1 | **Hook** | 0:00–0:08 | the curb at night; the house; one lit window going dark | weather/celestial/exterior have focused proof |
| 2 | **Ordinary superintendent work** | 0:08–0:25 | clock-in at the watchman's detector; the register spindle answers 0.77 m away; the first paper | proved — K2-B/K2-C sheets, suites green |
| 3 | **Sound-led Vantry hunt** | 0:25–0:50 | the landing plate naming the doors; into 2A; **the chirp; the head found; the grille drops** | proved — K2-F/K2-G, `production_04`, claim 0.0955 @ 1984× floor |
| 4 | **Mina truth** | 0:50–1:05 | the conversation, one line of evidence | `GATED` on K2 |
| 5 | **Narcolepsy transition** | 1:05–1:15 | onset; the room going wrong | `GATED` on K2 |
| 6 | **One Dream pocket / pursuer / truth** | 1:15–1:35 | the dark; the lamp decision | `GATED` on M5 presentation |
| 7 | **Wake / replay promise** | 1:35–1:50 | 4B, the residue, the house still standing | `GATED` on K3 |

**Total 1:50.** A 0:45 cut for social uses beats 1, 3, 6 only.

**Hard rules.**
- **Player camera only** — body, eye, carried lamp and streaming origin
  together. The project has already had an eleven-station performance table
  invalidated by a detached camera; a trailer is not allowed to make that
  mistake where nobody can check it.
- **No debug affordance in any frame** (§6).
- **No text promise of unbuilt content.** Valve: *"Do not make specific promises
  about future events."* **[SOURCED]**
- **The dream is 20 seconds of a 110-second trailer.** That ratio is the
  ADMIN-EA1 content ceiling expressed as edit time, and it is deliberate: the
  dream is punctuation, and a trailer that inverts the ratio sells a game we
  are not shipping.

---

## 8. Public demo and festival strategy

### The demo

- **Content:** ADMIN-EA1 §7 demo cut — beats 1–6, ending on the fault found.
  8–12 minutes. It ends on a discovery, not a cliffhanger.
- **Mechanism:** separate demo AppID **[SOURCED]**. Own store page **[INFERENCE:
  yes]** — a demo page carries its own reviews and its own screenshots, which
  is worth the extra review cycle for a game whose appeal is a specific
  sensation.
- **Availability:** demos may launch before the full game and can be listed
  Coming Soon **[SOURCED]**.

### Steam Next Fest — the one irreversible scheduling decision

**[SOURCED]** A title may participate in **exactly one** Next Fest, ever. It
must not have released, must release after the festival, must have a published
store page and a publicly playable demo when the festival begins.

**Verified 2026 editions and the October deadlines:**

| Edition | Festival window | Registration deadline | Demo + assets for review |
| --- | --- | --- | --- |
| February 2026 | Feb 23 → Mar 2, 10:00 PT | — *(past)* | — |
| June 2026 | Jun 15 → Jun 22, 10:00 PT | — *(past)* | — |
| **October 2026** | **Oct 19 → Oct 26, 10:00 PT** | **Aug 31 2026, 23:59 PT** | **Sep 21** for Press Preview, **Oct 5** final |

> **Immediate, dated, and time-critical: the October 2026 registration deadline
> is 31 August 2026 — five days after this document's date.**
>
> **[INFERENCE, and I recommend it as a refusal:] do not register for October
> 2026.** The demo requires H2, which requires route performance, M6 polish and
> the no-debug-affordance ruling — none of which is done, and one Next Fest slot
> is unrepeatable. Spending it on a demo we would be building in six weeks under
> deadline is the single most expensive mistake available to this project right
> now. **Target February 2027 or later, once H2 is actually closed.**
>
> **This is an owner decision, and it expires on 31 August 2026.**

**Dates beyond October 2026 are [UNKNOWN].** Valve publishes each edition's
page separately. **Monitoring process instead of guessed dates:** check
`partner.steamgames.com/doc/marketing/upcoming_events` monthly; when a new
edition page appears, record festival window, registration deadline and asset
deadline into this table; the registration deadline minus 8 weeks becomes the
"decide" date.

### Other festivals

**[UNKNOWN]** — no non-Steam festival deadline was verified in this pass, and
none is guessed. Same monitoring rule: a festival enters the calendar only when
its official page states a deadline, with the access date recorded.

---

## 9. Press kit, creator kit, accessibility information

### Press kit (static, no login, no form)
- fact sheet: title, developer, platform, price **[UNKNOWN — see §13]**, EA
  status, release window as *"when the gates in ADMIN-EA1 §9 are green"*
- the §1 hook, 50-word pitch and **the "this is not" list** — the boundaries go
  in the press kit, not just the store page
- logo pack; 10 stills at ≥1920×1080; 3 clips; 1 short loop of the grille drop
- **a signed statement on the narcolepsy depiction**, reviewed before any
  outreach — see §18 R6
- named response owner and a real reply time

### Creator kit
- key request route with **no NDA for post-demo coverage**
- **an explicit "you may monetise" line**
- three sanctioned off-route discoverables (arcade, phonautograph, fortune
  machine) so coverage finds something the trailer did not spend
- content note: darkness, pursuit, sleep-disorder depiction, period social
  content

### Accessibility information
- Steam's Accessibility Feature Wizard declaration, filled **only** for features
  that actually exist and can be switched on
- **Declaration is blocked by an ADMIN-EA1 finding:** the mechanisms exist
  (gradual-only onset, caption opt-out, reduced typewriter) but **no settings
  surface exists in the tree**, so today the honest declaration is nearly empty.
- Steam's declarable categories, for the settings panel to aim at **[SOURCED]**:
  *Gameplay* — adjustable difficulty, save anytime; *Audio* — custom volume
  controls, narrated menus, stereo/surround; *Visual* — adjustable text size,
  subtitle options, colour alternatives, contrast controls, camera comfort,
  playable without vision; *Input* — keyboard-only, mouse-only, touch-only,
  playable without QTEs, **playable at your own pace**.
- **[INFERENCE]** *Playable at your own pace* is the category the dark scramble
  most needs an answer for, and gradual-only onset is most of that answer.
- **Valve does not appear to verify these declarations** **[SOURCED — no
  verification process is stated]**. That makes accuracy an ethics question
  rather than a compliance one. **We declare nothing we have not switched on
  ourselves in a shipping build.**

---

## 10. Outreach tracker schema and ethical cadence

```
contact_id · outlet/channel · person (public professional identity only)
public_contact_route (the address they publish for pitches)
segment: press | creator | curator | festival
beat: announce | demo | EA launch | update
consent_state: never_contacted | opted_in | replied | declined | do_not_contact
first_contact_date · last_contact_date · contact_count
outcome: none | covered | declined | no_reply
notes (facts only; no inferred personal data)
```

**Cadence rules, binding.**
1. **Two contacts maximum per beat, and never more than three in total** before
   `consent_state` becomes `do_not_contact`.
2. **A non-reply is not a no; it is also not permission.** Second contact only
   at the next *beat*, never as a nudge.
3. **`declined` and `do_not_contact` are permanent** and survive every future
   campaign.
4. **No scraped lists.** Only publicly published pitch routes.
5. **No undisclosed paid promotion.** Any paid placement is labelled by us
   before it is labelled by anyone else.
6. Keys are issued per person, revocable, and never resold-tracked in a way we
   would not disclose.

---

## 11. Community, support, moderation, incident response

| Surface | Decision |
| --- | --- |
| Steam forums | **on** — it is where buyers already are |
| Discord | **[INFERENCE] not at launch.** A 24/7 live channel is a staffing commitment a three-person project cannot honour, and an unattended one reads worse than none |
| Bug intake | one route: a pinned Steam thread + an email alias |
| Response SLA | **first response within 3 working days**, published |

**Moderation baseline:** a short published code of conduct; no tolerance for
harassment; moderation actions logged; the owner is the appeal route.

**Incident response ladder.** Owner is incident lead in all cases.

| Severity | Example | Response |
| --- | --- | --- |
| **S1** | build does not launch; saves corrupt | roll back default branch (§15) within hours; pin a notice naming what happened |
| **S2** | route-blocking bug; a beat unreachable | hotfix branch → `rc` → default; notice within 24 h |
| **S3** | progression annoyance, visual defect | next scheduled update; acknowledge in the thread |
| **S4** | feature request | logged; **never promised** — Valve's own EA rule forbids specific future promises **[SOURCED]** |
| **SX** | **narcolepsy depiction harm** | **stop outreach. Owner + external review before any further statement.** See §18 R6 |

---

## 12. Telemetry and feedback — questions before collection

**This plan does not implement collection, and recommends shipping Early Access
with none.**

**[INFERENCE]** For a single-player ~30-minute experience with a three-person
team, the questions worth answering are answerable by *watching seven people
play* far more cheaply and more accurately than by instrumenting a funnel. The
fresh-player tests in ADMIN-EA1 §9 already generate the data. Telemetry adds a
privacy surface, a consent obligation and a policy document, for information we
can get by asking.

**If the owner nevertheless wants telemetry, these must be answered first:**

| # | Question | Owner |
| --- | --- | --- |
| Q1 | What decision would the data change? If none, do not collect. | owner |
| Q2 | Opt-in or opt-out, and is opt-in the first thing the player sees? | owner |
| Q3 | Is any identifier stored, even a random install id? | Codex |
| Q4 | Where does it physically go, under whose account, retained how long? | owner + external legal |
| Q5 | GDPR/UK-GDPR/CCPA posture and lawful basis | **external legal review** |
| Q6 | Is a privacy policy published *before* the first byte is collected? | owner |
| Q7 | Does Valve require disclosure of this collection on the store page? | **[UNKNOWN]** — verify in Steamworks before implementing |

**Feedback that needs no telemetry and ships at launch:** the pinned bug thread,
the email alias, Steam reviews, and a one-question in-build prompt **only if**
Q1–Q6 are answered.

---

## 13. Pricing and funding assumptions

**Pricing is not decided here, and no comparable, benchmark or market figure is
offered — that research is explicitly outside this task.** What follows is the
*structure* of the decision and the constraints that are already binding.

**Binding constraints [SOURCED]:**
- EA price must not exceed the price on any other platform
- no permanent discounts during EA
- 30-day cooldown after a price increase
- price rise within 30 days of leaving EA forfeits the launch discount
- Steam Direct: **$100 per app, recoupable at $1,000 AGR**
- itch.io: seller sets the platform share (default 10%) + passed-through
  processor fees (e.g. Stripe $0.30 + 2.9%)

| Assumption | Value | Status |
| --- | --- | --- |
| EA launch price | — | **[UNKNOWN] — owner decision, informed by the later GTM research task** |
| Price on leaving EA | ≥ EA price | **[UNKNOWN]** — but the *direction* is fixed by Valve's discount rule |
| Platform revenue share (Steam) | — | **[UNKNOWN]** — not verified in this pass; do not assume |
| Refund exposure | — | **[UNKNOWN]** — a ~30-minute experience interacts with refund windows in a way that **needs verifying before pricing**, and I flag it as the single most consequential pricing input |
| Runway | — | **[UNKNOWN] — owner** |
| VAT/GST/withholding | — | **external accounting review** |

**[INFERENCE], stated as a design consequence rather than a price:** a
30-minute Early Access build sits awkwardly against any refund window measured
in playtime. Two honest responses exist — price it accordingly, or make the
first content update a committed part of the launch — and **both are owner
decisions that should be made before the store page goes up, not after.**

---

## 14. Funnel and thresholds — proposed experiments, not facts

**Framing correction first.** Because Valve states wishlists are **not** a
visibility factor **[SOURCED]**, the funnel below treats wishlists as a
*notification list*. **No threshold here is an industry benchmark; every one is
a number we propose in advance so that we cannot rationalise afterwards.**

| # | Experiment | Measure | Proposed threshold | If missed |
| --- | --- | --- | --- | --- |
| E1 | Does the page convert attention into a launch notification? | wishlists per 100 store visits | **≥3** | rewrite short description + capsule before any outreach |
| E2 | Does the demo hold? | % of demo starts reaching the fault found | **≥60 %** | the route, not the marketing, is wrong — back to FP-2 |
| E3 | Is the hook the hook? | % of demo players who mention sound unprompted | **≥50 %** of interviewed | re-cut the trailer around whatever they do mention |
| E4 | Does the demo sell? | demo → EA purchase | **[UNKNOWN]** — no honest prior; **measure first, threshold second** | — |
| E5 | Does it retain past the first shift? | % of buyers who start a second shift | **≥40 %** | replayability claim in §1 is false; remove it from the store page |
| E6 | Is the EA disclosure working? | refunds citing "shorter than expected" | **≤5 %** of refunds | the "this is not" list is not prominent enough |

**Go/no-go on the campaign, not the build:** if **E1 and E2 both miss**, the
launch is held and the *positioning* is reworked — not the scope. ADMIN-EA1's
ceiling does not move because marketing underperformed.

---

## 15. Runbooks

### Launch week

| When | Action | Owner |
| --- | --- | --- |
| L−14 d | Coming Soon page live **(Valve minimum)** | owner |
| L−10 d | store presence submitted for review (**3–5 business days**) | Claude |
| L−7 d | build submitted for review (store presence must be approved first) | Codex |
| L−5 d | press/creator keys out; embargo = launch moment | Claude |
| L−2 d | RC on `rc` branch frozen; **no commits to the release build** | Codex |
| L−1 d | rollback rehearsal (below) performed and timed | Codex |
| **L** | **manually set the build live on the default branch** — Valve requires the manual action | owner |
| L+2 h | first forum sweep; pin known-issues thread | Claude |
| L+24 h | first triage; S1/S2 assessed | owner |
| L+7 d | first patch **or** a public note saying why not | owner |

### Rollback

**Precondition: rehearsed once before launch, timed, and the time written here.**

1. Owner declares S1.
2. Set the **previous known-good build live on the default branch** (manual).
3. Pin a notice: what broke, who is affected, what to do, when we will update.
4. **Save-compatibility check before any roll-forward** (below).
5. Post-mortem in the same thread within 72 h.

### Hotfix

1. Fix on a branch → `rc` → **one** named tester confirms the specific defect →
   default branch.
2. A hotfix never carries an unrelated change. If it does, it is an update.

### Save compatibility

The save is versioned (`SAVE_VERSION := 4`, `user://reality_maintenance_save.json`)
with a migration hook — recorded in ADMIN-EA1 §10.

**Rules.**
1. **A save written by a newer build must never be silently loaded by an older
   one.** Rollback plus an unguarded newer save is data loss, and rollback is
   exactly when it happens.
2. Any change to save shape increments `SAVE_VERSION` and ships a migration in
   the same commit.
3. **A rollback across a `SAVE_VERSION` boundary is not a rollback** — it is a
   forward hotfix, and must be treated as S1 with a player notice.
4. Before every update: load a save from the *previous public build* and
   complete one shift. **[UNKNOWN]** — this check does not exist as a test today
   and should become one; it is not on the ADMIN-EA1 critical path and I am not
   adding it there unilaterally.

---

## 16. Twelve-week pre-release operating calendar

**No product dates.** Weeks are relative and **gated**: a week that depends on a
build gate does not start until that gate closes. W1 begins whenever the owner
starts this plan.

| Week | Not blocked on the build | Blocked on a gate |
| --- | --- | --- |
| W1 | Steamworks account, Direct fee, tax/bank paperwork | — |
| W2 | logo lockup; capsule family drafts | — |
| W3 | short/long description; EA questionnaire draft; "this is not" list | — |
| W4 | **narcolepsy statement drafted and sent for external review** | — |
| W5 | Coming Soon page assembled (unpublished); content survey; **German age rating** | — |
| W6 | press/creator kit skeleton; outreach tracker stood up | — |
| W7 | devlog 1–2 (apparatus/period — tests hypothesis A3) | — |
| W8 | accessibility declaration drafted **as a target** | ← needs the settings surface to be true |
| W9 | — | **H2 gate**: screenshots + trailer capture |
| W10 | trailer cut; store page review submitted | ← needs W9 |
| W11 | demo build to `friends`; demo page review | ← needs H2 |
| W12 | keys out; launch rehearsal; rollback rehearsal | ← needs RC |

**Five of the twelve weeks depend on nothing.** That is the honest answer to the
charter's question *"what can begin before content lock"*: **W1–W7 can start
today**, and none of it requires a single new line of game code.

---

## 17. Responsibility matrix

| Area | Owner decides | Codex implements | Claude administers/researches | External |
| --- | --- | --- | --- | --- |
| Promise / ceiling | ✔ (fixed by ADMIN-EA1) | — | drafts copy against it | — |
| Entity, pricing, funding | ✔ | — | structures the decision | **accounting/tax** |
| Steam account & agreements | ✔ (signs) | — | prepares checklist | **legal** |
| Store assets | ✔ (approves) | — | ✔ produces | — |
| Capture (screens/trailer) | ✔ (selects) | harness | ✔ captures | — |
| Build channels & releases | ✔ (sets live) | ✔ | documents | — |
| Age ratings / content survey | ✔ (answers) | — | ✔ prepares | — |
| Accessibility settings surface | ✔ (assigns) | ✔ | ✔ declares | — |
| Telemetry (if any) | ✔ | ✔ | ✔ questions | **privacy legal** |
| Press/creator outreach | ✔ (approves list) | — | ✔ runs | — |
| Community/moderation | ✔ (appeals) | — | ✔ day-to-day | — |
| **Narcolepsy depiction** | ✔ | — | drafts | **subject-matter/sensitivity review** |
| Incident response | ✔ (lead) | ✔ (fix) | ✔ (comms) | — |

---

## 18. Risks and stop conditions

| # | Risk | Likelihood | Impact | Mitigation | Stop condition / trigger |
| --- | --- | --- | --- | --- | --- |
| **R-PROMISE** | **Promise inflation** — the store page grows features the build does not have | **High** | **High** — this is how Early Access earns its reputation | §1 "this is not" list is published, not internal; every store claim traces to a passing test or a landed sheet | any store/press sentence that cannot name its evidence |
| **R-DREAM** | **Dream-scope creep back into the release** | **High** | High | the trailer allots the dream 20 s of 110; ADMIN-EA1 §6 ruling stands | any dream-breadth commit before H2, or any trailer cut where the dream exceeds 25 % |
| **R-NEXTFEST** | The one-time Next Fest slot is spent early | **Live now** | High, irreversible | §8 recommends refusing October 2026 | **31 Aug 2026** — decision expires |
| **R-SYS** | System requirements published without measurement | Medium | Medium | do not publish until measured on ≥2 machines | any draft store page with a spec block |
| **R-ACCESS** | Accessibility declared but not switchable | Medium | **High — ethical** | declare nothing not switched on in a shipping build | wizard filled before the settings panel exists |
| **R-DEBUG** | Debug nameplates reach a screenshot | Medium | High | §6 capture gate; Valve requires gameplay-only screenshots | any capture showing a `Label3D` name |
| **R6 (from ADMIN-EA1)** | **Narcolepsy depiction lands badly** | Low | **Very high** | reviewed statement before any outreach; SX incident ladder | any external reading that the condition is the villain |
| **R-GERMANY** | Missing/incorrect age rating | Low | Medium | Valve questionnaire; **never submit an IARC-generated USK rating** | store page submitted with survey incomplete |
| **R-REFUND** | ~30-minute EA build vs refund windows | **[UNKNOWN]** | Potentially high | verify before pricing (§13) | pricing decided before the check |
| **R-CHANNEL** | Epic/GOG onboarding consumes launch capacity | Medium | Medium | both are post-launch candidates | any Epic/GOG work before H3 |

---

## 19. Proposed `TASKS.md` patch — text only, not applied

```diff
 ## K — Core loop / the complete shift

-- **K0-GTM — PRIORITY PROJECT: BUILD DISTRIBUTION AND MARKETING ALONGSIDE THE
-  RELEASE.** [...full brief...]
+- **K0-GTM — PLAN PUBLISHED 2026-08-26, EXECUTION OPEN.** Operating plan at
+  `design/EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md`: platform
+  matrix (Steam EA primary, itch.io secondary, Epic/GOG later), Steamworks
+  checklist, build-channel design, asset manifest with official dimensions,
+  trailer spine, demo/festival strategy, outreach and community rules,
+  telemetry questions, funding-assumption table, funnel experiments,
+  runbooks, twelve-week calendar and responsibility matrix. Weeks W1–W7 are
+  blocked on nothing and can start immediately.

+- **K0-NEXTFEST — DECISION EXPIRES 31 AUGUST 2026.** A title may join Steam
+  Next Fest exactly once, ever. October 2026 registration closes 31 Aug 2026
+  23:59 PT; the festival runs 19–26 Oct 2026 and requires a publicly playable
+  demo at its start. The plan RECOMMENDS DECLINING October 2026 and targeting
+  a later edition, because the demo depends on the H2 gate. Owner decision.

+- **K0-STOREFRONT — START NOW, BLOCKED ON NOTHING.** Steamworks account,
+  $100 Steam Direct fee (recoupable at $1,000 AGR), Steam Subscriber and
+  Distribution agreements, tax identity and payout details, content survey,
+  and the German age rating (mandatory — a game without a valid rating is not
+  displayed to German customers; never submit an IARC-generated USK rating).
+  Owner signs; external accounting/legal reviews.

+- **K0-NARCOLEPSY — GATE ON ALL OUTREACH.** Draft and externally review a
+  short statement on the narcolepsy depiction before any press, creator or
+  festival contact. The condition creates the vulnerable interval; it is not
+  the antagonist, and the game must not be readable as saying it is.
+  Blocks the press kit, not the build.

+- **K0-SAVEGUARD — ROLLBACK SAFETY.** A save written by a newer build must
+  never be silently loaded by an older one; rollback is exactly when that
+  happens. Add a version guard and a "load the previous public build's save
+  and complete one shift" check before each update. Not on the ADMIN-EA1
+  critical path; do not let it displace one.
```

---

## 20. Source appendix

All fetched **2026-08-26**. "Supports" names the claim in this document.

| # | Page | Authority | URL | Supports |
| --- | --- | --- | --- | --- |
| S1 | Early Access — Steamworks Documentation | Valve | https://partner.steamgames.com/doc/store/earlyaccess | EA questionnaire; "playable and substantial"; no specific future promises; pricing rules incl. 30-day cooldown and the leaving-EA discount rule; Steam availability requirement; annual page update |
| S2 | Store Graphical Assets — Steamworks | Valve | https://partner.steamgames.com/doc/store/assets/standard | header 920×430 JPG; small 462×174 PNG; main 1232×706 JPG; vertical 748×896 JPG; background 1438×810 JPG; ≥5 screenshots ≥1920×1080 16:9, gameplay only |
| S3 | Steam Direct Fee — Steamworks | Valve | https://partner.steamgames.com/doc/gettingstarted/appfee | $100 per app; recoupable at $1,000 AGR; agreements; VAT/GST note; **no enumeration of identity/bank documents** (basis for that `[UNKNOWN]`) |
| S4 | Branches (Betas) — Steamworks | Valve | https://partner.steamgames.com/doc/store/application/branches | default branch is what customers get and **must be set live manually**; password-protected branches hide even the branch name; use for QA/beta/staged release |
| S5 | Releasing Your Game — Steamworks | Valve | https://partner.steamgames.com/doc/store/releasing | Coming Soon ≥2 weeks; store review 3–5 business days; submit ≥7 days ahead; store presence approved before build review; manual "Release App" |
| S6 | Demos — Steamworks | Valve | https://partner.steamgames.com/doc/store/application/demos | demo has its own AppID via "Add Demo"; optional separate store page (needs review, ≥5 demo-specific screenshots); may release before the game; Coming Soon supported |
| S7 | Steam Next Fest — Steamworks | Valve | https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest | three editions a year; **one Next Fest per title, ever**; publicly playable demo required at start; no exclusivity/length requirement; submit 3–5 business days ahead |
| S8 | Steam Next Fest: October 2026 | Valve | https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/2026october | **Oct 19–26 2026, 10:00 PT**; registration **31 Aug 2026 23:59 PT**; **Sep 21** Press Preview / **Oct 5** final asset deadline; Press Preview from Oct 8; full eligibility list |
| S9 | Age Ratings Mandatory in Germany — Steamworks | Valve | https://partner.steamgames.com/doc/gettingstarted/contentsurvey/germany | USK or Valve self-rating; **IARC-generated USK ratings must not be submitted**; unrated games not displayed to German customers; existing owners retain access |
| S10 | Accessibility Features — Steamworks | Valve | https://partner.steamgames.com/doc/accessibility_features | the four declarable categories and their features; wizard under store page → Basic Info; **no stated verification process** |
| S11 | Visibility on Steam — Steamworks | Valve | https://partner.steamgames.com/doc/marketing/visibility | **wishlists are not an algorithmic visibility factor**; their value is the launch/EA/20%-discount email; purchases and engagement are the signal; store traffic and conversion are not |
| S12 | Steam Deck FAQ — Steamworks | Valve | https://partner.steamgames.com/doc/steamdeck/faq | review automatic or submitted, results ~1 week; Verified/Playable/Unsupported; tests controller support, legibility, performance, system support; no fee stated |
| S13 | Accepting Payments / Open Revenue Sharing | itch.io | https://itch.io/docs/creators/payments · https://itch.io/updates/introducing-open-revenue-sharing | seller sets platform share, default 10%; processor fees passed through (Stripe $0.30 + 2.9%); direct vs collected payout models; free to upload |
| S14 | Epic Games Store revenue share announcement | Epic Games | https://store.epicgames.com/en-US/news/epic-games-store-updates-revenue-share-keep-100-of-the-first-1m-per-product-per-year | 100% of first $1M net revenue per product per year, then 88/12. **Onboarding/technical requirements could not be verified — official dev pages returned 403/empty; recorded as `[UNKNOWN]`** |
| S15 | Essentials Checklist / Releasing your game on GOG | GOG | https://docs.gog.com/basic-game-assets/ · https://support.gog.com/hc/en-us/articles/11382878039197 | submit at final stage or post-release elsewhere; DRM-free RC for every supported OS; ≥1920×1080 assets; trailer with GOG logo; age ratings; human curation, may not respond |

**Documents cited from this repository:**
`design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md` (ADMIN-EA1, commit `627eae5` —
**not yet on `main`**); `design/EARLY_ACCESS_GO_TO_MARKET_PROJECT.md`;
`TASKS.md:42`, `:3187`.

---

## 21. ADMIN-EA1 contradictions: resolved or preserved

| ADMIN-EA1 item | Disposition here |
| --- | --- |
| **K0-EA vs GTM deliverable duplication** | **RESOLVED.** K0-EA owns promise and ceiling; K0-GTM owns route to market. The §19 patch rewrites K0-GTM to point at this document, so neither re-specifies the other. |
| **No distribution artifact exists** | **RESOLVED.** §3–§6, §15, §16 are that artifact. §16 shows five of twelve weeks blocked on nothing. |
| **No measured system requirements** | **PRESERVED, with a gate.** Still `[UNKNOWN]`. R-SYS forbids publishing a spec block before measurement on ≥2 machines. Codex owns the measurement. |
| **No accessibility/settings owner** | **PRESERVED and escalated.** Still unowned. Now additionally blocks a *store-page* declaration (§9), and §17 forces the owner to assign it. **[INFERENCE]** it is now the highest-leverage unowned item in either document, because it gates a public claim as well as the build. |
| **Narcolepsy depiction review** | **RESOLVED into process.** W4 drafts it, external review, gates all outreach; SX incident ladder; proposed as `K0-NARCOLEPSY`. |
| **Dream breadth excluded from the promise** | **PRESERVED and enforced.** Encoded as an edit-time ratio (20 s of 110) and a stop condition (R-DREAM) rather than an intention. |
| **Peter / case-two identity is an owner decision** | **PRESERVED and deliberately not marketed.** No roadmap, store page, trailer or press sentence names a second case, a second resident or a case count. Valve's own rule against specific future promises makes this both a scope discipline and a platform compliance point. |

---

## What this document does not do

- **No market sizing, comparables, competitor analysis or price recommendation.**
  Those were excluded from this task and remain open.
- **No dates for the product.** Every calendar entry is relative or
  gate-conditional. The only absolute dates are Valve's, and they are sourced.
- **No external action was taken.** No account, form, contact, payment,
  reservation or agreement.
- **No expansion of the build.** Where marketing wanted content — a longer demo,
  a second case, more dream — the answer written down is no.
