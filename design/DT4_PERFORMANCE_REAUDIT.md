# DT-4 — RE-DERIVING THE PERFORMANCE-FEAR LIMITS ON FORWARD+

> *"audit for any limitations we imposed based on performance fears or
> compatibility mode like shadow and light count and recalculate with new
> performance data, maximize for quality of final image"* — owner

Forward+ became canonical on 2026-08-22. Every quality limit in this project
was argued from numbers measured on the Compatibility renderer. This is the
re-derivation — and it turned into a re-derivation of the *instrument* first.

## 0. THE PROBE WAS LYING

`Perf.tscn` measured frame time as `1000.0 / Performance.TIME_FPS`.
`TIME_FPS` is an **integer**. At the rates this build runs that quantises
brutally: 21 fps and 22 fps are 47.6 ms and 45.5 ms with nothing expressible
between them. When the counter returned 2, the table printed a confident
`500.00 ms` — for a station that actually runs at **6.7 ms**.

That one number sent me chasing a phantom: an "accumulation" bug in which the
roof supposedly cost twice as much at the end of the walk as it did measured
alone. An A/A control (`PERF_AA=1`, which re-measures the first station again
as the last) showed the lobby did not degrade at all — 20.40 ms then
21.54 ms — and the anomaly evaporated entirely once the instrument was fixed.

The probe now samples real frame deltas, sorts them, reports the **median**
with a **p05–p95 spread**, and cross-checks against **wall-clock elapsed over
the sample window divided by the frames in it** — ground truth that no monitor
can distort. The verdict column is decided by the wall-clock figure. The
spread column exists because it is the most important one on the table: it is
how you know whether to believe the row.

**Consequence: every perf table recorded in this project before 2026-08-22
came from the broken monitor and should be treated as indicative, not exact.**
That includes the tables in `FINAL_MAP_REDESIGN_BRIEF.md` and the historical
"55 ms at every resolution" figure. Their *conclusions* mostly survive
re-measurement — see below — but their numbers do not.

## 1. Is the frame still submission-bound? — YES, with one exception

Wall-clock ms, production profile (64 lights / 16 shadows), canonical night:

| station | objs | 720p | 1440p | 4× the pixels costs |
| --- | ---: | ---: | ---: | ---: |
| lobby | 18,628 | 20.82 | 21.32 | +2% |
| atrium eye (7 storeys) | 25,996 | 28.81 | 30.95 | +7% |
| corridor F04 | 15,703 | 16.81 | 17.26 | +3% |
| **street elevation** | 17,419 | 24.45 | **30.04** | **+23%** |
| roof | 2,343 | 6.72 | 6.50 | −3% |

Four times the pixels costs **2–7%** at every interior station. The frame is
bound by **draw-call submission**, exactly as it was on Compatibility, and the
standing rule survives the renderer change: **GPU-side quality is free** —
MSAA 8×, 16× anisotropic, and the subsurface/transmittance/clearcoat the hero
anatomy needs all land in time the CPU is spending anyway.

The **street elevation is the exception**, and it is new information: +23% for
4× the pixels is a real fill cost. It is the one view that is mostly sky,
glass and a whole lit street elevation rather than close interior geometry.
Quality dials are *not* free there. Nothing has been changed on account of it;
it is recorded so the next person does not spend that headroom twice.

Note how much tighter the numbers are now: p05–p95 sits inside 2–4 ms at
every station, against the ±15 ms swings the old counter produced. The
two-run rule stays, but a single run is now worth something.

## 2. Where the frame actually stands

Four of eleven stations are over 16.6 ms; the worst is the atrium eye at
~31 ms. Forward+ made the frame materially cheaper but did not make it fit.
There is **no headroom to spend on more geometry**, and the honest reading of
"maximize for quality" remains: spend on the GPU, where it is nearly free, and
nowhere else until the ~40,000-object submission problem (#28) is dealt with.
The roof — 2,343 objects, 6.7 ms — is the whole problem in miniature: this
frame costs what it costs because of how many things it submits, and nothing
else.

## 3. The limits, one at a time

| limit | verdict |
| --- | --- |
| `max_lights_per_object` 16 → 128 | Already lifted. The 16 was Compatibility's own default and the sole reason a light budget existed at all. |
| Light budget 16 → 64 | Already lifted and measured. Extra lights are free at every station but the light court. |
| Shadow budget **16** | **Kept, and it is not a performance limit.** The positional atlas is a fixed 8192 that subdivides per caster, so raising this shrinks every shadow in the frame in exchange for shadows nobody looks at. A quality judgement, unaffected by the renderer. |
| Passage lights shadowless (shaft, lunette, drum, 2× well) | **Kept.** The *justification* was stale — it argued from `gl_compatibility` base-pass ALU — but the decision is right on its own terms: all four light glazing from inside it or above it, where a shadow would either do nothing or black out the very panel the light exists to make bright. Comment corrected; behaviour unchanged. |
| MSAA 8×, aniso 16× | Re-confirmed free at every station except the street elevation. |

**No limit in this project is currently being held down by performance fear.**
The ones that remain are quality judgements, and the binding constraint is
draw-call submission, which none of these dials touches.

## 4. What this unlocks

Honestly: nothing, because nothing here was the brake. The brake is #28. The
one genuinely valuable outcome is the instrument fix, which makes every future
measurement in this project worth trusting — including the ones that will
decide whether #28 has been solved.
