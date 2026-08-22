# DT-4 — RE-DERIVING THE PERFORMANCE-FEAR LIMITS ON FORWARD+

> *"audit for any limitations we imposed based on performance fears or
> compatibility mode like shadow and light count and recalculate with new
> performance data, maximize for quality of final image"* — owner

Forward+ became canonical on 2026-08-22. Every quality limit in this project
was argued from numbers measured on the Compatibility renderer. This is the
re-derivation. **Measured, not argued.**

## Method

`res://tests/Perf.tscn`, windowed (headless reports zeroes for every
rendering counter, which reads as a pass). Production profile, pinned
64 lights / 16 shadows. Full five-station walk at two resolutions, plus
isolated single-station runs via `PERF_STATION`.

## 1. Is the frame still submission-bound? — YES

This is the assumption everything else rests on: if the frame does not care
how many pixels it fills, GPU-side quality is free.

| station | 720p run A | 720p run B | 1440p |
| --- | ---: | ---: | ---: |
| lobby | 32.2 | 17.7 | 22.0 |
| atrium eye (7 storeys) | 27.4 | 27.3 | 31.3 |
| corridor F04 | 34.9 | 28.2 | 24.3 |
| street elevation | 18.8 | 20.2 | 23.6 |
| roof | *500* | 31.3 | 29.1 |

Four times the pixels costs **nothing outside the run-to-run spread** — at
two stations 1440p is faster than 720p, which only happens when resolution is
not what is being measured. The finding survives the renderer change: the
frame is bound by **draw-call submission**, not by fill.

**So the standing rule holds.** MSAA 8×, 16× anisotropic, SSAO/SSIL, the
subsurface and clearcoat the hero anatomy needs — all land in time the CPU is
spending anyway. Anything that costs **draw calls** is the opposite: still
the whole problem, and Forward+ did not change it.

Note the spread. Run A and run B of the *same* build differ by 14.5 ms at the
lobby. Any conclusion drawn from a single run of this probe is worthless;
`design/FINAL_MAP_REDESIGN_BRIEF.md` already says so and it is still true.

## 2. Nothing is within budget

Every interior station sits at 18–31 ms against a 16.6 ms target — 6 of 11
stations over, at **both** resolutions. Forward+ made the frame cheaper; it
did not make it fit. There is **no headroom to spend on more geometry**, and
the honest reading of "maximize for quality" is: spend on the GPU, where it
is free, and nowhere else until the ~40,000-object submission problem (#28)
is addressed.

## 3. The limits, one at a time

| limit | verdict |
| --- | --- |
| `max_lights_per_object` 16 → 128 | Already lifted. The 16 was Compatibility's own default and the sole reason a light budget existed. |
| Light budget 16 → 64 | Already lifted and measured. Extra lights are free at every station but the light court. |
| Shadow budget **16** | **Kept, and it is not a performance limit.** The positional atlas is a fixed 8192 that subdivides per caster; raising this makes every shadow in the frame smaller in exchange for shadows nobody looks at. `LightRig.SHADOW_N` is 32 for the same reason. A quality judgement, unaffected by the renderer. |
| Passage lights shadowless (shaft, lunette, drum, 2× well) | **Kept.** The *justification comment* was stale — it argued from `gl_compatibility` base-pass ALU — but the decision is right on its own terms: all four light glazing from inside or from above, where a shadow would either do nothing or black out the thing being lit. Comment corrected; behaviour unchanged. |
| MSAA 8×, aniso 16× | Re-confirmed free. |

Net: **no limit in the project is currently being held down by performance
fear.** The ones that remain are quality judgements, and the binding
constraint is draw calls, which no dial here touches.

## 4. Open anomaly — the roof

| how measured | ms |
| --- | ---: |
| roof alone (`PERF_STATION=roof`) | **14.50** |
| roof alone, shadows off | 14.19 |
| roof alone, occlusion culling off | 16.93 |
| roof as the 5th station of the walk | 27–31, once **500** |

The roof draws 2,219 objects. The lobby draws 18,636 and is *faster*. Whatever
costs 31 ms up there is not submission, and measured in isolation it does not
cost it at all — so something **accumulates across the walk**, roughly
doubling the roof's cost, and once by a factor of thirty-four.

Not diagnosed. Shadows are not it (0.3 ms) and occlusion culling is helping,
not hurting. Candidates not yet tested: the repeated passage sweeps that log
at every station, `passage_light_saved` growth, reflection-probe re-capture,
and the surface governor's parallax budget oscillating (it was seen moving
0.5 ↔ 1.0 during these runs). Wants the two-run rule and a dedicated bisect.
