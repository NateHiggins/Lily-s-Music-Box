# Household care, quiet goodwill and a tip-funded pocket

Evidence class: **INERT**

REPORT - V2-CARE-ECONOMY - 2026-09-26

Branch / base / origin/main at start / merge-base: main /
e89226e25d06d5390da9b644e8ed1e2113e65f95 (all three references).
Implementation HEAD is the commit introducing this report.

## Owner direction and implemented boundary

The owner requested testable, maintainable interactive objects, small acts that
prevent actual requests and quietly improve relationships, tips weighted by
affection, promptness and completeness, spending on everyday leisure and a
low-pressure rent goal. This supersedes earlier assumptions that everyday
objects should only offer their primary use. The implementation here is the
first household slice, not delivery of the whole spending or object catalogue.

Fitted water fixtures and cabinets have a physical-ray inspection surface.
Water uses the existing valves, mixed temperature and basin simulation; a slow
drain changes actual water accumulation. Cabinet care affects the existing hinge
sound or sliding travel. Due dates create simple WorkOrders; earlier care moves
the due date. A per-client daily cap keeps goodwill from being farmed by cycling
many fixtures. Money uses integer cents and paid-tip identities. Authored job
closure includes its tip in the existing save snapshot. Care does not grant
case resolution or overwrite case trust. Rent accumulates without penalties.

## Validation and evidence limits

The first windowed care run passed 27 checks. A rendered pocket capture exposed
a blank first frame, fixed by immediate refresh; the next run passed 28 checks.
The shower now requires an open curtain for its visible test and drain service.
Further checks exercise authored job closure, real disk reload, existing hot
water and legacy save compatibility. Logs, captures and adjacent suite-run
receipts live under tmp/v2-care. The final candidate verifier repeats double
import and selected runtime suites against the clean baseline board captured
at this report's base. Wrapper receipts do not promote completeness requirements.

The unchanged hot-water suite reported 40 failures in both the candidate and a
controlled run with committed gameplay sources restored temporarily. Its fixture
roster omitted the nineteen completion-interior taps, leaving those valves off
before checking their hot supply. The test now combines both authored fitting
schedules, retaining its existing physical-control and temperature assertions.
The baseline failure receipt remains under tmp/v2-care/baseline-hotwater.log.

The source changes include shared TapProp drainage, medicine-cabinet squeak
suppression and input bindings because V2 reuses those production systems.
Default clear-drain and unoiled-cabinet behavior remains available to V1.
The prior basin simulation drained a closed stopper when supply was off; the
water-balance calculation now respects the stopper independently of supply.
Protected spatial files, selector default, V1 rollback and historical evidence
remain unchanged. This inert report promotes no ledger requirements.

## Open scope and checkout

The full interactive-object catalogue and paid leisure/consumable transactions
remain to be integrated. Relative temperature is not a calibrated thermometer.
Inspection currently uses keyboard and pointer controls. The current values
are provisional balance choices. Existing H23 debt remains separate.
Owner render notes and five images are preserved outside the commit. No new
worktree or reference-image bytes are introduced. No owner decision is needed.
