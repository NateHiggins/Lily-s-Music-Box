# Apartment bathroom lavatory

Evidence class: **INERT**

V2 fitted-service intake uses **bath_lavatory_fitted.blend**, published with
**scripts/export_bath_lavatory_fitted.py**. One export contains all six native
service-depth groups; the existing V2 sink subclass removes five before mounting
and retains exactly the profile selected in domestic/completion fitting data.
These are the19 surveyed sink IDs, not additional sinks. Local UV materials keep
the registered maps/scales; the original source, builder and GLB below remain
the explicit V1 rollback. Loaded/contact/interaction acceptance is separate from
the source export checks.

The editable source is `bath_lavatory.blend`. Rebuild with:

```powershell
blender -b -P art/blender/scripts/build_bath_lavatory.py
```

The builder exports `game/assets/props/bath_lavatory.glb`. Dimensions are metres.
It makes the entire fixture: a continuous hollow rolled-rim bowl and raised
back, a slender pedestal, a curved bridge faucet, independent cross handles,
a drain throat, rubber plug, ball chain, waste trap, supply risers, stop valves
and wall escutcheons. The back and pedestal retain the compact apartment-house
lavatory silhouette; this is not a new kitchen fixture.

Named pivots HotValve, ColdValve, Stopper and StopperChain are the integration
contract. TapProp reparents the moving groups, binds existing catalogue
porcelain_fixture, nickel_plated and rubber_aged finishes, and batches the chain
links into a MultiMesh. Blender contains neutral preview materials; the game
uses the catalogue textures. No reference photographs or texture lettering are
embedded. Hot/cold flow, plant temperature, drainage, service inspection,
possession timing, collision and save authority remain in their existing systems.

BathLavatoryTest checks the live V2 roster, imported pivots, physical valve rays,
handle rotation, plug seating/lifting, chain attachment and water retention and
drainage. Its windowed captures show the installed 4B fixture and the exposed
plumbing with a neutral inspection light. These captures are visual QA, not
spatial acceptance receipts. The plug's movement and chain slack are visual;
the existing abstract water-level simulation still governs drainage.
