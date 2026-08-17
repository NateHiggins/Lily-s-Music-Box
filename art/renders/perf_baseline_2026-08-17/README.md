# The session did not change performance measurably, in either direction

*2026-08-17. Paired runs, one machine, one sitting, nothing else on the CPU.*

The pickup said **"NO BEFORE-BASELINE EXISTS, so I would not call these
pre-existing and neither should you."** The instinct was right and the premise
was wrong twice, so both halves are recorded here — along with a correction to
the first version of this file, which drew conclusions from single samples.

## A committed before-table already existed

`art/renders/atrium_standard/README.md` carries a canonical-pinned-night table
at **1280×720**, at both 16/16 and 64/16, ending in `stations over 16.6 ms:
6/11 → 5/11`. `art/renders/harukiya_rebuild/README.md` carries a second.
Between them they name five of eleven stations, so neither is complete — but
"no baseline" was not true, and the atrium eye's **39.28** in that table is the
same number the pickup reported as new.

## And the reported figures were taken at an unstated resolution

The pickup's numbers (lobby 28.87, atrium eye 39.37, corridor F04 26.20, 4B
18.20) carry no resolution. `perf_probe.gd:6` suggests 2560×1440; the only
committed table is 1280×720. They were never going to be comparable.

## The paired run

HEAD against `dd77df9` — the last commit of the previous session, and the right
baseline because `PINNED_LIGHT_BUDGET` became 64 at `0d40d41`, its ancestor, so
both sides measure the same 64/16 configuration. Nineteen commits apart.
Measured in a detached `git worktree`, never a checkout in the shared main
tree, with the mandatory once-per-worktree `--import` first.

| station | `dd77df9` | HEAD | note |
|---|---:|---:|---|
| lobby | 26.40 | 27.21 | single sample each |
| atrium eye (7 storeys) | 39.16 | 39.57 | single sample each |
| corridor F04 | 25.97 | 26.44 | single sample each |
| apartment 4B | 20.14 | 16.47 | **replicated below — the delta is not real** |
| street elevation | 26.55 | 29.77 | **replicated below — the delta is not real** |
| roof | 22.22 | 17.82 | single sample each |
| harukiya (16 fixtures) | 10.36 | 10.70 | |
| arcade cluster (5 live) | 11.86 | 11.91 | |
| passage throat reveal | 12.50 | 11.51 | |
| passage hall southbound | 10.18 | 10.21 | |
| passage hall northbound | 13.88 | 13.46 | |

## THE CORRECTION — the two movements worth chasing were both noise

The first version of this file reported "6/11 → 5/11, the session improved
performance" and "one real regression: street elevation +3.22 ms". Both came
from one sample per side. Replicated three times per side, neither survives.

**Street elevation** — traffic runs during `Perf`, so object counts swing
10.5k–12.8k between runs at the same station:

| | run 1 | run 2 | run 3 | mean |
|---|---:|---:|---:|---:|
| `dd77df9` | 29.61 | 29.00 | 30.67 | **29.76** |
| HEAD | 32.28 | 29.07 | 30.04 | **30.46** |

Delta **+0.70 ms** inside almost fully overlapping spreads. The original
baseline sample of 26.55 is faster than all three replications, so the "+3.22"
was one lucky baseline against one unlucky HEAD.

**Apartment 4B** — sits on the gate and crosses it run to run on *both* sides:

| | run 1 | run 2 | run 3 | mean | over 16.6 |
|---|---:|---:|---:|---:|---|
| `dd77df9` | 17.98 | 17.22 | 16.32 | **17.17** | 2 of 3 |
| HEAD | 16.73 | 16.73 | 16.32 | **16.59** | 2 of 3 |

Delta **−0.58 ms**. 4B is the station that moved the 6/11 vs 5/11 count, and it
does not sit reliably on either side of the line, so **the station count is not
a stable metric on this machine** and neither run's count should be quoted as a
result.

`harukiya_rebuild/README.md:136` already said this — "apartment 4B at 17.03
(was 15.95) … straddling the gate … that is this machine's noise band". This
lane rediscovered it the expensive way. **Replicate before attributing.**

## What can be said

- **No measurable performance change this session, in either direction.**
- The reported figures are **pre-existing**, which is the question the pickup
  actually asked, and it is now answered with a same-machine paired run.
- The two stations that fail hardest are structural and already ticketed as
  project-wide P1 in `TASKS.md`: **atrium eye** (~39 ms, sees seven storeys at
  once) and **street elevation** (~30 ms). Nothing a session does moves those.
- The arcade V4 work shows up in the census as intended: arcade cluster
  4,667 → 3,008 objects and 6.5M → 3.3M primitives for the same frame time.
- The working-tree Passage streaming fix costs nothing, as predicted from a
  body's origin being its feet while every passage station stands at 1.68 m,
  under the 1.75 m window.
- The B1 ceiling fix costs nothing at the one station where B1 is submitted:
  atrium eye **38.69** after, against 39.57 before.

## What this still does not say

- **`ms` is `1000 / Performance.TIME_FPS`** sampled 90× (`perf_probe.gd:510`),
  not a mean frame time. `worst` is computed and never printed, so this harness
  supports no p99 claim.
- **Nine of the eleven stations remain single-sampled.** Only 4B and street
  elevation were replicated. Do not read the others' deltas as changes; on this
  evidence the noise band is at least ±1.7 ms at a traffic-exposed station.

## Reproducing

```bash
C:/devkit/bin/godot.cmd --path game --resolution 1280x720 res://tests/Perf.tscn
```

One station, repeated — which is what any attribution needs:

```bash
PERF_STATION="street elevation" C:/devkit/bin/godot.cmd --path game --resolution 1280x720 res://tests/Perf.tscn
```

State the resolution and the light/shadow budget in every table. The budget
went 16 → 64 on 2026-08-16 and `perf_probe.gd:14-27` is emphatic that tables
either side of it are not comparable — the trap that made these numbers look
new in the first place.
