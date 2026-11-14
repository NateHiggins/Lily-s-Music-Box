# V2 boiler-to-tap source integration

V2 mounted a boiler and water fixtures without composing `BoilerTend`, leaving
the taps at their initial temperature and the plant without its slow tending
clock. The runtime now creates one existing `BoilerTend` after domestic
fittings mount, resolves the real `B1_BOILER_01`, and discovers live TapProps
under the adapter's blockout root. This currently binds the 3B kitchen sink,
bath sink and shower, plus the 4B lavatory. Future fixtures mounted through
the same loader are included at composition without a second ID list.

The shared controller immediately publishes the existing hot-water curve and
listens to the boiler's state signal. Its existing one-second accumulator
advances fuel, fire, ash, pressure and water. Hot/cold valves continue to own
mixing through TapProp. The controller retires with the V2 world. No shared
boiler, tap, heat-balance or tending implementation was changed.

Source checks confirm one controller creation, composition after fittings,
unique authored water anchors, no second plant-tick call in the V2 root, and
unchanged shared owners. Independent GDScript syntax checks pass.

`OrisonV2HotWaterTest` is prepared to instantiate V2 twice, check exact live
fixture membership, initial temperature, fractional and full plant ticks,
signal-driven temperature, cold mixing, and WeakRef retirement. It has not
been run. It uses controlled ticks and valve setters; it does not claim a
played maintenance route.

**No Godot was launched, per owner instruction. Runtime validation remains
pending.** Enabling the clock introduces normal plant decay into V2, so the
existing boiler/service and earned Dream/wake tests must also be run when
engine use resumes. No saved plant or valve state was added: reconstruction
still uses the existing boiler initialization. HeatBalance is deliberately
unbound until V2 radiator topology is integrated. This is hot-water delivery
source work, not complete plumbing, persistence or release acceptance.
