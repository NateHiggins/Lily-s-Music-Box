# DREAM SALIVA — THE RESIDUE, BUILT

> *"an iridescent holographic reflective saliva goo on everything it touches
> that crystalizes like superchilled frost in a otherworldly metalic neon
> rainbow with dimensional breaking properties that persist and decay like its
> being eroded by an eon of time in a couple seconds"*

`DreamResidue` + `dream_residue.gdshader`. A pool of 24 patches in **one mesh
and one draw**; a contact writes a patch and the shader plays a geological
history across it in a few seconds. Fed today by the hero's `touched` signal;
the margin's palps and the critters can feed the same pool, and §28 says they
should not all leave the same amount — intensity is a parameter, and the hero
gets the richest.

## The life, photographed

The frames are one patch at 0.45 s intervals, shot by
`SWEEP_MODE=modelled SWEEP_RESIDUE=1`, which waits for a real contact and then
holds one camera on it. A single frame proves nothing about this effect: the
decay *is* the effect.

| frame | what it shows |
| --- | --- |
| `R0_t0.0` | the front still running: a bright warped leading edge |
| `R1_t0.5`, `R2_t0.9` | crystallised — neon bands in faceted cells |
| `R3_t1.4` | the structural colour beginning to go |
| `R4_t1.8` | **the ghost**: colour gone, substance pitted and broken |
| `R5_t2.3` | almost nothing left |

The thing worth checking in `R4` is that the patch has not faded. Its colour
died first, then it pitted; what remains is a stain with holes in it. That is
the hardest sentence in the direction — *decay like it is being eroded by an
eon of time* — and a uniform alpha ramp is exactly what it must not be, so the
stages are authored on separate clocks rather than lerped.

## `00_rejected_moire.png`

The first iridescence used `1.0 / facing` directly for the thin-film term.
That reaches fifty at grazing angles, so the hue cycled **fifty times across
one patch** and it read as a CD surface rather than as structural colour on
something wet. The angle still drives the hue — move, and it changes, which is
the whole point of iridescence rather than a painted rainbow — but it now
sweeps a couple of bands, with the spatial variation coming from noise so
there are several colours in one patch at once.

Also fixed after photographing: a fully grown patch was a **perfect circle**,
because once the front had run past the disc the boundary became the mesh's
own rim. The outer edge now carries the same warp the front does.

## Not done

- **Dimensional-breaking properties.** The direction asks for the surface to
  stop being reliably three-dimensional where the goo is thick. `dream_w`
  feeds the hue, which is a long way short of that. This is the demand that is
  least served so far.
- Only the hero feeds it. Margin palps have no contact yet.
- It does not accumulate: two contacts in the same place make two patches
  rather than a thicker one.
