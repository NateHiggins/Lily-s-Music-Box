# T7d Harukiya STREET ownership proof

Each station was captured in its own fresh Godot process at 2560x1440,
canonical night, seed `19280731`. `PERF_STREET_HARUKIYA_GEOMETRY_ON=1`
holds the ruled Harukiya prism open for two paused controls; the final invokes
the production index and removes exactly 264 enclosed draws. Separate processes
are required because this A/A/B treatment is destructive for the life of the
scene; `WeatherSkyShot` now refuses a multi-station destructive pair.

The street face, bar entrance/signage, Orison entry, neon, window cards and
exterior light pools remain. The treatment is behind the Harukiya fabric; the
remaining pixel delta is low-amplitude live rain plus illumination/shadow work
that disappeared with impossible behind-wall casters.

| station | A/B mean abs | B/final mean abs | A/B >8 | B/final >8 |
|---|---:|---:|---:|---:|
| north pavement | 0.040870/255 | 0.126565/255 | 0.0457% | 0.3612% |
| south pavement | 0.040559/255 | 0.133096/255 | 0.0218% | 0.3401% |
| east road mouth | 0.316745/255 | 0.474039/255 | 2.0116% | 2.3604% |

The east view sees the largest rain floor; the absolute treatment delta there
is still under half a code value per channel.
