# Vantry gateway K0 evidence

Canonical-night K0 proof, captured 2026-08-14 with one Godot process at a
time. `dry/` and `weather/` contain the same seven camera transforms from
`VantryGatewayShot.tscn`.

`id_east/` records the failed east-oblique source attribution before the
outward hoarding face was fixed. In `id_0.png`, samples across the large dark
rectangle resolve to nominal palette value `168,168,24`; `legend.tsv` maps
that value to the 137-instance exterior-detail box buffer. The ray for pixel
`700,400` in `instance_hits.tsv` resolves the nearest member to instance 128,
world AABB `(20.420,0.000,23.894) + (0.360,2.400,4.422)`: the
`EastSouthWorks` containment board. This is the source behind the correction
in `exterior_detail_pass.gd`.

The two negative controls are reproducible without storing another fourteen
beauty frames:

```text
GATEWAY_OFF=1       # hides the six gateway buffers; the mass remains
PASSAGE_SHELL_OFF=1 # hides the five shell buffers; the mass remains
```

Neither control is active in ordinary captures or production.
