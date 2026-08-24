# §12 STEPS 8 AND 9 — FINE CILIA, AND THE TASK COMPLETING

Ecology architecture §12. Captured by
`game/tests/dream_step12_cilia_shot.gd`.

The canonical sequence is twelve steps. Steps 1-7 and 10-12 were
built; 8 and 9 were not, because there was no cilia GEOMETRY on a
palp anywhere -- `palp_matter.w` carried the individual's cilia
fraction and drove a four-millimetre tremor in GDScript.

The rule these frames have to satisfy is the governing sentence of
§12: **never spawn a branch by scaling a cylinder from zero.** It
applies to a hair as much as to a branch. So the cilia are full
length at every moment, seated in the shaft's own surface, and
deployment turns them through an angle.

`00` is the A/A control: four IDENTICAL branches -- one host
morphology, one branch morphology, one seed, one lamp -- side by
side in one frame, differing only in how far through the sequence
each one is. `01` makes the same case inside a SINGLE organ,
which is stronger still: mid-deployment the wave has reached the
proximal half of the band and not the distal half, so one frame
holds the same hairs erect and lying flat with nothing else
differing at all. `02` and `03` are the pair at macro distance
from one stand.

- 0a_establishing.png — the row in the room, so the macro frames below can be located.
- 00_control_row_four_states.png — four IDENTICAL branches, one frame. Left to right: investigating (cilia folded along the shaft), deploying (the wave part way down the band), deployed, and the completion beat. Same morphology, same seed, same lamp.
- 01_wave_on_one_organ.png — mid-deployment on ONE organ: the wave runs down the band, so the proximal hairs are erect while the distal ones are still lying along the shaft. Same hairs, same length, different angle -- which is the whole claim, inside a single frame.
- 02_macro_folded.png — folded. The cilia are ON the organ, at full length, lying along the shaft as fine longitudinal relief.
- 03_macro_deployed.png — deployed, at the same distance and offset as 02. The same hairs, stood off the surface. Nothing was created and nothing grew.
- 04_macro_completing.png — §12 step 9, at the same stand again: the band closes forward together onto the finished target, and the tissue under it floods the way the crease floods at step 2.
- 10_investigating.png — step 7 -- the branch is out and working a target of its own. Its cilia are on it, folded along the shaft, and have not been asked for yet.
- 11_deploy_early.png — step 8 beginning. Deployment runs DOWN the band from the proximal end, so the near hairs are up while the far ones are still lying down.
- 12_deploy_late.png — step 8, the wave most of the way along the band.
- 13_deployed.png — step 8 complete -- the whole band erect. Same hairs, same length as frame 10.
- 14_completing.png — step 9, the completion beat: the branch plants, the band closes forward together, and the tissue under it floods the way the crease floods at step 2. It has a real duration, it is not an edge.
- 15_retracting.png — step 10 -- the fine anatomy going back in. The branch is still out and still full size.
- 16_folding.png — step 11 -- and only NOW does the branch begin to fold. The cilia are already in.
- 17_simple_again.png — step 12 -- the parent back to simpler topology, carrying no evidence of any of it.

    PRICE (measured, same process, same camera, 46 appendages):
    cilia folded (cilia_out 0)         calls 133  median 0.82 ms  wall 0.93 ms
    cilia deployed on EVERY palp       calls 133  median 0.82 ms  wall 0.93 ms
    deployed + completion beat         calls 133  median 0.82 ms  wall 0.93 ms
    CONTROL: pre-change mesh, no cilia calls 133  median 0.81 ms  wall 0.91 ms
    cilia folded again (drift check)   calls 133  median 0.82 ms  wall 0.93 ms
