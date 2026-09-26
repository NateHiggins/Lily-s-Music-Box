# Care, tips and the rent envelope

The owner direction is a building where every usable object can also be tested
and attended to. Small preventative acts should head off actual requests and
quietly improve the client's affection. Tips, rather than a salary or abstract
quest rewards, are the primary economy. Desired spending includes karaoke,
beer, cigarettes, a camera and film, pool wagers, arcade rounds and meals.
Rent is a gentle savings goal. This direction is broader than the first rollout.

## Available in V2 now

E remains the ordinary operation control. Aim at a fitted sink, shower,
medicine cabinet or kitchen cabinet within 2.1 metres and press I to inspect.
The ray must actually hit the fixture or one of its controls. The carried paper
shows `[I] Inspect / care` while a supported fixture is within reach. I with
no fixture in reach does nothing; P remains the pocket-ledger shortcut. Inspection locks
movement while the world and the mechanism keep running. Escape returns the
pointer to its previous ownership. Calls, seated activities, paused play and
the ecology camera do not accept this shortcut.

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

Initial service dates are staggered over days one through eight. Service
postpones a fixture's next request by fourteen campaign days. A neglected drain
slows physically; an overdue cabinet track takes longer to move. Client-owned
fixtures create ordinary simple WorkOrders when due. P opens the pocket ledger
with the outstanding service requests. Care before a request earns no cash.
The client's hidden goodwill can improve once per campaign day across all their
objects. Repeating care on the same fixture that day earns nothing more.

An outstanding request pays once when it is tested and completed. Authored
maintenance jobs pay when their existing lifecycle closes. Tips combine the
client's hidden goodwill, existing case trust, completion quality and campaign
time since the request. Care does not resolve a resident's emotional case.

P shows the pocket balance and rent. Starting cash is $1.00. Rent is a $5.00
instalment every thirty campaign days; one advance instalment can be paid.
Unpaid instalments accumulate without interest, fees, eviction, forced cash
deductions or blocked play. These are provisional game-balance values, not
claims about historical rents. An older save starts this schedule when the
economy first binds; past closed jobs do not award retroactive tips.

## Still to build

This first rollout covers household water fixtures and cabinets, not every
interactable. Other object families need meaningful physical tests and care
actions that respect their existing maintenance owners. Leisure purchases,
consumable effects, owned camera/film, actual pool stakes and paid arcade/karaoke
sessions are not implemented here. The pocket is not a remote shopping menu.
Those transactions must happen at their physical venues and persist through the
same money owner. Discoverability and controller/touch inspection also need work.

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
