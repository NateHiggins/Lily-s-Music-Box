# Care, tips and the rent envelope

The owner direction is a building where every usable object can also be tested
and attended to. Small preventative acts should head off actual requests and
quietly improve the client's affection. Tips, rather than a salary or abstract
quest rewards, are the primary economy. Desired spending includes karaoke,
beer, cigarettes, a camera and film, pool wagers, arcade rounds and meals.
Rent is a gentle savings goal. This direction is broader than the first rollout.

## Available in V2 now

E remains the ordinary operation control. On a controller, R3 opens inspection
and Back/View opens the pocket ledger. Use D-pad left/right to select
a button, A to operate it and B to close. Timed tests focus the enabled Close
button, so cancellation stays accessible. The carried paper shows R3 after
controller input and I after keyboard input. Aim at a fitted sink, shower,
medicine cabinet, kitchen cabinet, toilet or wall switch within 2.1 metres and press I to inspect.
The ray must actually hit the fixture or one of its controls. The carried paper
shows `[I] Inspect / care` while a supported fixture is within reach. I with
no fixture in reach does nothing; P remains the pocket-ledger shortcut. Inspection locks
movement while the world and the mechanism keep running. Escape returns the
pointer to its previous ownership. Calls, seated activities, paused play and
the ecology camera do not accept this shortcut.

V2's touch controls include **CARE** for the fixture under the centre ray and
**POCKET** for the ledger. Tap the inspection's buttons to operate or test the
mechanism and **Close** to leave. Accepted inspection releases held movement
touches and keeps the pointer visible. CARE with nothing in reach does nothing;
POCKET works without a fixture. The carried cue uses `[TAP]`, and the ledger
names the touch buttons. F1, pause, calls, seated activities, explicit backtick
mouse release and another active camera retain ownership. On desktop, enable
the existing **Touch controls (phone HUD)** option in F1 to try these controls.
Opening care or F1 clears touch movement and the RUN latch. Disabling touch,
resizing the viewport, losing window/application focus, or retiring the controls
also releases the actions they pressed and resets their finger tracking. Actions
not owned by touch are left alone; resume with a fresh touch after returning.

Water inspection exposes independent hot and cold valves, the stopper, actual
mixed warmth, basin level and drain condition. Open the shower curtain first.
The four-second test fills briefly, closes both valves, opens the drain and
observes the falling water level. Manual valve and service controls pause during
the test; Close / Escape remains available and restores the entry settings.
An empty sample reports an incomplete test. A stationary collected pool reports
blocked drainage and allows clearing; it never claims that drainage passed. Clearing the strainer requires testing first,
both valves closed and the drain open. Leaving inspection restores the valve
and stopper settings from entry. Temperature is the existing simulation's
relative cold/warm/hot reading, not a newly calibrated thermometer.

Exercise a cabinet to close and reopen its actual moving leaf. The test waits
for both ends of travel before allowing care and leaves the mechanism open.
An unfinished movement times out without passing; cancelling restores the entry
open/closed state. Oil quiets the
medicine cabinet's existing squeak. Brushing and waxing restores the sliding
cabinet's normal travel time. These actions do not replace the cabinet's
ordinary open/close control or moving collision.

Cistern inspection runs the existing flush handle and waits for its return and
the refill to finish. The mechanism records the completed handle stroke, so a
missed inspection frame cannot lose the brief movement. An overdue inlet strainer extends the actual refill wait;
the completed test reports the slow refill. Cleaning the strainer restores the
normal wait and postpones the next request. Service is refused while refilling.
Starting inspection during an existing flush does not count as a test. Cancelling
inspection leaves the physical flush running and grants no test result; a stalled
refill times out without passing. The tank uses the existing full/refilling state,
not a new calibrated water-volume or supply-pressure simulation.

Switch inspection checks both toggle detents against the actual room fixtures,
then restores their entry power states. Cancellation and a stalled toggle also
restore the circuit through SwitchSystem; incomplete tests grant no service
result. A missing circuit cannot pass. Overdue faceplates move slightly under
the hand; securing their fasteners removes that movement and postpones the next
request. This is mounting care, not a simulated wiring repair. Residential
switches use their household's existing client; shared-building switches can be
attended to but do not invent a paying resident. All 133 V2 plates participate.

Initial service dates are staggered over days one through eight. Service
postpones a fixture's next request by fourteen campaign days. A neglected drain
slows physically; an overdue cabinet track takes longer to move. Client-owned
fixtures create ordinary simple WorkOrders when due. P opens the pocket ledger
with the outstanding service requests, oldest reports first. Each entry shows
how long the client has waited in campaign days and hours. Active orders stay
listed; orders closed by the work-order owner disappear. Printed pocket copies
include the same ordering and waiting times, frozen at the time of printing. Care before a request earns no cash.
The client's hidden goodwill can improve once per campaign day across all their
objects. Repeating care on the same fixture that day earns nothing more.

An outstanding request pays once when it is tested and completed. Payment
requires the work-order owner to still mark it issued or active. A stale fixture
reference to a closed or missing request cannot award cash; physical care can
still complete and postpone the next request, with an unpaid service slip. Authored
maintenance jobs pay when their existing lifecycle closes. Tips combine the
client's hidden goodwill, existing case trust, completion quality and campaign
time since the request. Care does not resolve a resident's emotional case.

Completed care sends a physical service slip to the powered carried set, naming
the fixture, action and any tip. Denied or repeated care does not print another
completion. P's **Print pocket and request page** button prints the current
balance, rent and displayed request page without changing them. These use the set's existing recent-report archive, not a second save ledger;
reprint for an updated snapshot. With the set off, printing is refused
and the inspection says so. Service and its payment still complete normally.

P shows the pocket balance and rent. Starting cash is $1.00. Rent is a $5.00
instalment every thirty campaign days; one advance instalment can be paid.
Paying rent immediately updates the pocket and prints a receipt on the powered
set. A set that is off does not prevent payment; the ledger explicitly says no
slip was printed. Insufficient cash, an already-paid advance instalment and
unavailable saving have distinct responses, and refused payments print nothing.
Unpaid instalments accumulate without interest, fees, eviction, forced cash
deductions or blocked play. These are provisional game-balance values, not
claims about historical rents. An older save starts this schedule when the
economy first binds; past closed jobs do not award retroactive tips.

## Still to build

This rollout covers household water fixtures, toilet cisterns, cabinets and wall switches, not every
interactable. Other object families need meaningful physical tests and care
actions that respect their existing maintenance owners. Leisure purchases,
consumable effects, owned camera/film, actual pool stakes and paid arcade/karaoke
sessions are not implemented here. The pocket is not a remote shopping menu.
Those transactions must happen at their physical venues and persist through the
same money owner. Broader discoverability and testing on physical mobile devices
still need work; touch coverage here uses simulated screen events in a windowed
desktop run.

## Ownership and verification

CaretakerEconomy owns integer cents, paid-tip identities, goodwill and rent;
RealityState alone writes them to disk. Existing WorkOrders owns request
lifecycle and case trust stays with its current owner. The added save domain is
validated before adoption. Care uses stable existing fixture identities, never
saved world positions. A completed authored job and its tip share a snapshot.
Completed care and a generated request's tip share its closing snapshot.

CaretakerCareTest is a windowed production test of the real interaction ray,
flow/drainage, prevention, requests, physical cabinet care, pointer ownership,
disk reload, repeat-payment protection and rent. CaretakerEconomyTest exercises
the authored job lifecycle and atomic save closure separately.
CisternCareTest adds the actual toilet interaction ray, slow/healthy refill
timing, handle return, cancellation, timeout, prevention, tips, legacy saves and
disk reload, with windowed inspection captures.
SwitchCareTest checks circuit isolation, detents, cancellation, stalled travel,
mounting movement, prevention, single payment, legacy saves and disk reload.
LightSwitchModelTest and OrisonV2UpperLightingTest retain the existing mesh,
physical approach, room-power and saved-circuit checks.
