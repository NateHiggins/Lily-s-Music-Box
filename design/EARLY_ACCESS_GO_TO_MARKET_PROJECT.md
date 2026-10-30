# Prologue teaser distribution and historical release charter

Evidence class: **INERT**. Active distribution plan and historical provenance;
no accounts, billing, uploaded build or entitlement flow is verified here.

## Active milestone — owner direction, October30,2026

The polished V2 prologue is the teaser. Prepare distribution alongside its
visual/audio/interaction acceptance, without waiting for the complete city or
all of V2. This narrowly reopens the requested Patreon/itch.io/Discord/Butler
infrastructure; it does not revive the retired fundraising, marketing, outreach
or fundability programme below. No calendar deadline or platform qualification
is invented. Canonical Codex owns repository tooling and evidence; the owner
supplies/controls the creator accounts, payout/tax verification and final
appearance/offer decisions. Existing active account details are not yet known.

Requested offer:3USD Supporter (Discord/lore polls/devlog);10USD Early Access
(build access/behind-the-scenes);25USD Superfan (playtests/design input/prompt
logs/credits). Preserve authorial control over NPC/clue canon. Sanitize any
published prompt logs for secrets and private material. These are requested
tiers, not claims that paid offers are live or that their benefits are delivered.

Implementation sequence:

1. Inventory existing Patreon campaign, itch creator/project and Discord server;
   keep project setup Draft until ready to test Restricted access. Confirm exact
   tiers, currency, beneficiary accounts and role permissions. Tax/payout
   verification requires the owner's real account evidence, not a repo checkbox.
2. Add deterministic build identification to title/pause presentation and export
   tooling. Separate source commit, human-readable build ID and SHA256 of final
   artifacts; commit-plus-timestamp alone is not a cryptographic artifact hash.
   Avoid self-hashing the binary containing its own digest. Retain release
   manifests externally and show a compact readable identifier in-game.
3. Pin the approved engine/export tooling and Butler version. Stage a clean
   exported artifact, verify its manifest, then upload through a protected CI
   publishing job with a secret-scoped credential. Never embed tokens in the
   game, repo, logs or public download URLs. Keep first experimental upload
   separate from making a paid offer live. Preserve the shared Godot lane.
4. Configure native Patreon/itch tier eligibility and Discord mappings. Exercise
   unauthenticated,3USD,10USD,25USD,declined,lapsed,cancelled-but-still-paid and
   annual/gifted cases. Verify private channels and bot-role hierarchy. Measure
   the requested five-minute role-assignment target; it is not an established
   provider SLA. Reconcile cancellation and downgrade timing with paid entitlement.
5. Test owner-controlled patron join→claim→download→launch→Discord, then a second
   build/update, rollback and save compatibility. Preserve upload receipts,
   artifact hashes, displayed build IDs and actual entitlement results. Billing,
   account linking and publication remain unverified until these actions occur.

Official-source corrections checked October30:

- [itch Patreon integration](https://itch.io/docs/creators/patreon) currently uses
  Edit→Distribute→Patreon Access and a displayed **/patreon-access** claim URL.
  Prefer explicit Early Access/Superfan tier eligibility over minimum amounts,
  which have currency limitations. The docs describe one issued key per patron
  and manual revocation; automatic cancellation-based key expiry is not proven.
  Strict active-member download access therefore remains a design/QA blocker,
  not a promise supplied by OAuth alone. Existing downloaded binaries are a
  separate matter; no online DRM is proposed.
- [Subscription billing](https://support.patreon.com/hc/en-us/articles/8779192853261-Subscription-Billing-FAQ)
  differs from legacy first-of-month charge-upfront billing. Annual plans have
  [eligibility requirements](https://support.patreon.com/hc/en-us/articles/360041721372-Annual-memberships-creator-overview),
  including account/payment history; a new campaign may not offer them immediately.
  Keep the requested10–15percent annual discount conditional on availability.
- [Discord setup](https://support.patreon.com/hc/en-us/articles/213552323-Setting-up-Discord-for-your-members)
  requires suitable managed roles and bot placement. Do not treat role removal
  as removal from the server or assume an unmeasured five-minute guarantee.
- [Butler pushes](https://itch.io/docs/butler/pushing.html) use a consistent
  **windows-64**, **mac-universal**, **linux-64** channel map and **--userversion**.
  Differential app updates and browser downloads are different delivery paths;
  browser users do not receive automatic patch application. Current repository
  export presets are Windows and retained Android only. The first required upload
  is Windows; macOS/Linux builds and tests remain unimplemented deliverables,
  not shipping platforms established by naming channels.

Acceptance remains the owner's six requested checks: verified account/tiers;
tested entitlement allow/deny; real experimental Butler Windows upload;
measured Discord grant/removal; visibly correct title/pause identification;
and end-to-end patron QA. Also retain the access-revocation/annual-eligibility
limitations above. The prologue still needs artistic acceptance and its open
audio/readability/save/performance work; this plan does not declare it ready.

## Retired October27 charter — provenance only

**Status: retired from active scope by the owner, 2026-10-27.** Funding,
fundability and marketing work are not current project goals. The owner wants
to focus on making the best game. No campaigns, outreach, pricing/funding models
or marketing deliverables are authorized by this old charter. Technical delivery,
save reliability, accessibility and game quality remain ordinary development
requirements; no such requirement is waived by retiring this project.

Historical status: priority project charter. The release-build milestone decides what is
ready to sell; this project decides how players discover, obtain, understand
and support it.

## Objective

Build a measurable route from an unknown game to a sustainable Early Access
audience. Distribution and marketing are production systems with owners,
dependencies, budgets, evidence and deadlines—not a trailer made after the
game is finished.

## Workstreams

1. **Positioning and audience.** Define the one-sentence promise, distinctive
   proof, comparable audiences, player objections, content warnings and the
   honest Early Access expectation.
2. **Distribution.** Select storefronts and release platforms; document account,
   tax, rating, legal, accessibility, localization, build-upload, entitlement,
   crash-reporting, patching, rollback and support requirements. Establish a
   reproducible release-channel pipeline with internal, playtest, press and
   public branches.
3. **Store conversion.** Produce and test the capsule family, screenshots,
   trailer, short description, long description, tags, feature list, system
   requirements, FAQ, roadmap and creator/press kit. Every visual must come
   from a representative shipping build.
4. **Audience development.** Plan devlogs, short-form clips, community spaces,
   mailing list, festivals, demos, playtests and update cadence around specific
   hooks rather than generic progress reports.
5. **Press and creators.** Build a segmented contact list and outreach calendar;
   prepare concise pitches, preview keys/builds, embargo instructions, fact
   sheet, logos, footage, screenshots and a response owner. Track consent and
   never automate spam.
6. **Launch operations.** Define announcement, demo, wishlist, review-key,
   launch-week and first-update beats; staff moderation, support, incident
   response, patch approval and player communication.
7. **Measurement and funding.** Establish privacy-respecting funnel metrics,
   campaign attribution, wishlist/demo/playtest targets, conversion assumptions,
   pricing scenarios, cash runway, platform fees, tax/refund sensitivity and
   explicit thresholds for spending, delaying, narrowing scope or seeking a
   publisher/investor/grant.
8. **Post-launch trust.** Publish an achievable roadmap; report changes plainly;
   maintain release notes, known issues, save compatibility and a feedback loop
   that distinguishes loud requests from representative player evidence.

## Required artifacts

- channel/platform decision matrix and compliance checklist;
- dated campaign and release calendar with named owners;
- audience, positioning and message brief;
- store-page asset manifest and acceptance rubric;
- press/creator kit and outreach tracker;
- build-channel, launch-day and rollback runbooks;
- budget, runway and funnel model with assumptions exposed;
- privacy/telemetry policy and community moderation plan;
- weekly dashboard and go/no-go review tied to the Early Access build gates.

## Guardrails

- Do not promise unbuilt features, dates the production evidence cannot support,
  or historical/technical claims that have not been checked.
- Do not let marketing capture use debug-only states or imply content depth the
  Early Access build does not contain.
- Do not buy reach before the store page, demo and onboarding can convert it.
- Preserve player privacy and platform rules; no scraped mailing lists, spam or
  undisclosed paid promotion.
- Treat wishlists, followers and views as leading indicators—not proof that the
  game retains or satisfies players.

## First planning gate

Once K0-EA declares the target player journey and scope ceiling, produce the
platform matrix, positioning brief, store asset manifest, twelve-week campaign
calendar, release-operations checklist and funding model. The first review must
identify what can begin before content lock and what is blocked by the build.
