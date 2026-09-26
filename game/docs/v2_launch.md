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

The primary stair now continues above F06 to the roof. At its top landing,
turn toward the west bulkhead door and press E to step onto the deck. The
second bulkhead, to the east, connects to the service stair. Both doors open
and close normally; the perimeter has solid parapets. The raised timber water
tank stands southwest of the public bulkhead. Walk to its exposed valve and
press E to service the overflowing ballcock; Escape cancels and restores an
unfinished attempt. This reuses the existing tank activity. Its repair is local
to the current building instance, not a saved campaign job or a source of water
for apartment taps. Lift machinery, roof ventilation and adequate night
lighting remain unfinished.

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
The zoo is still dark, especially around the hero and organelle wall.
