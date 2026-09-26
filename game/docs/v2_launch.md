# Play V2 and visit the Dream zoo

The normal title screen uses V2. **Begin the Night**, **New Campaign**, and
**Continue** share the same session selector. Dream returns rebuild V2 at the
4B bedside. Continue after a completed wake also resumes at that bedside.
Existing campaign files retain their calendar, cases, orders and inventory;
the selected building is never written into the save.

From PowerShell in **C:/PleaseRemainOnTheLine**, with the Godot lane free:

```powershell
pwsh -File tools/lane.ps1 run -Windowed -Runner long -TimeoutSeconds 1500 -LogPath tmp/v2-play.log
```

This opens the normal title. The approved long runner allows a 25-minute
session. WASD moves, the mouse looks, E interacts, Shift runs, L switches the
lamp, and Escape opens Building Services. At the entrance, use the lobby's
right-side opening into the stair core, then the caretaker-room doorway to
reach the watchman's detector and night register. Clock in and take the report.

The waking lamp has a broad work-light beam and a sixteen-metre range. Aim at
the control and let the carried set settle after a fast turn. Its light still
comes from the modeled lens; walls and machinery cast shadows.

For Mina's opening shift, follow the report to 2A, inspect the faulty listening
head, obtain its capsule at HARDWARE PAINT, and return to repair the same head.
Speak with Mina after the repair. Her conversation enables the nearby lobby
time clock for the second visit. Follow the updated objective through the
caption desk, calibration and further conversation; repair alone does not
resolve her case. The final calibration can earn the dream request. Normal
campaign onset waits for a safe moment, and the dream returns you to 4B with
the completed work intact. A field note pauses while Mina is speaking so it
cannot obscure her dialogue choices.

The passenger lift serves B1 and F01–F06. Press E at a landing call button,
wait for the doors, enter, and press E on the desired floor button. Landing
doors stay shut while the car is away. The stairs remain available. Follow the
west side of the shaft to the apartment halls and basement laundry; the watch
door is beside the lift's front approach.

In B1, use the east side of the primary stair to reach the boiler corridor.
The electrical room opens south from that corridor; press E at the fuse panel
to enter its existing maintenance activity. The workshop is opposite. Its east
door connects to the service stair, which now continues down from F01. The coal
annex opens from the boiler room. Its rear bunker now has a gravity chute to
the closed street coal-hole cover; delivery is static architecture. Clear the
open boiler-door tip before turning into the apparatus aisle. Resident storage is through the north door
beside the primary stair, with eighteen labeled bays. Completed fuse repairs
and the five new room-light settings survive Continue and building returns.

The boiler stands on the basement floor facing the west control aisle. Aim at
the upper firing door or lower ash door to open or close that door. The water
glass opens its existing proving activity; Escape cancels it. Walk around the
south end of the plant to reach the weighted draft damper at the rear. Its
setting feeds the existing radiator and hot-water simulation. These controls
do not issue another campaign job or add automatic coal delivery.

The remaining occupied apartments (1A, 1D, 2C, 3D, 4C and 4D) now have room
shells, doors, furniture, working hot/cold taps and switched lights. The staff
restroom opens from the ground-floor service hall. The sealed 2D and 3C entries
remain locked. These installations do not add new resident cases.
All eighteen occupied homes have working radiator supply valves. Ordinary
valve settings, room lights and the existing saved household controls survive
Continue; the 2B repair keeps its own existing state owner.

The primary stair now continues above F06 to the roof. At its top landing,
turn toward the west bulkhead door and press E to step onto the deck. The
second bulkhead, to the east, connects to the service stair. Both doors open
and close normally; the perimeter has solid parapets. The raised timber water
tank stands southwest of the public bulkhead. Walk to its exposed valve and
press E to service the overflowing ballcock; Escape cancels and restores an
unfinished attempt. This reuses the existing tank activity. Its completed repair
survives Continue and building returns. It is not a campaign job or a source of
water for apartment taps. Four automatic roof ventilators serve 23 passive bathroom
registers through four modeled risers and overhead branches. The registers
clear the ceiling lights. Stack A serves the northwest bathrooms, B the
southwest, C the north-central homes, and D the eastern bathrooms and staff
restroom. Their guarded inspection points explain the service refusal; they
are not another repair job. A guarded lift drive stands above the passenger
shaft inside the public roof bulkhead. Four suspension ropes, two deflectors,
car and counterweight guides, and a framed counterweight now complete its
visible travel assembly. The sheaves and counterweight follow the existing
car. Guarded openings carry the ropes through the roof and machinery plinth;
the roof access path stays outside the moving apparatus. This does not add
another repair job or a second lift controller.

The service lamp is now bright enough to serve as the primary local light in
unlit rooms, the basement and on the roof. Press L to switch it. It retains its
physical aim and thermal warm-up. Its native throw is 12 metres; the shared
voxel field supplies instantaneous optical response rather than building-wide
indirect illumination. Dream and close-up inspection use lower, scene-specific
output. The ecology camera's lamp takes over the field while inspecting and
returns ownership to the carried lamp when you leave.

Mina walks her existing home, shop, laundry and mail routes. She waits for
doors to finish opening and closes doors she opened after people clear their
swing. Doors already left open remain open. Her bathroom destination uses the
sink's clear stance rather than standing inside the toilet collision.

## Debug controls and zoo

To expose **Debug Building** on the title, set the following before the same
launch command:

```powershell
$env:ORISON_TITLE_DEBUG = "1"
```

Choose **Debug Building**, press **F1**, expand **GO — teleports**, and choose
**Dream zoo** to walk among the specimens or **Dream ecology** for the
inspection camera. The debug panel is also available above Building Services
while paused. F1 opens the controls and releases the pointer; backtick releases
or recaptures it during play. Clicking while deliberately released keeps it free.

**Leave camera** exits inspection. **Building return** restores the position
and view from before the zoo visit. Press **F1** again after a teleport to close
the controls and walk; use **Escape** if Building Services remains open.
The existing hero tentacle, live organelles,
sixteen Blender critters and fifteen reserved bays are shared with V1.

To launch directly into the walkable zoo:

```powershell
pwsh -File tools/lane.ps1 run -Scene res://scenes/debug/ZooVisit.tscn -Windowed -Runner long -TimeoutSeconds 1500 -LogPath tmp/zoo-play.log
```

## Explicit V1 rollback

Set **ORISON_BUILDING_ROOT** to **v1** before launching. Remove the override
to return to the committed V2 default. The choice lasts for that process and
does not convert the campaign.

```powershell
$env:ORISON_BUILDING_ROOT = "v1"
# Run either launch command above.
Remove-Item Env:ORISON_BUILDING_ROOT
```

V2 remains an unfinished building. The playable first Mina maintenance/case
sequence is the supported campaign slice. V1-only apartment corruption and
resident debug shortcuts are not exposed as working V2 controls. The separate
voxel-light seams recorded under TASKS H23 remain open.
The hero enters through its membrane over several seconds. The inspector shows
its live state, including arrival and the intervals between appearances.
