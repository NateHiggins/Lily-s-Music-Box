# Orison Night Lighting Profile

The reference image is treated as a hierarchy rather than an exposure
target: cool blue-black ambient establishes silhouettes, small warm pools
reveal faces and furniture, and most of the room remains below key level.

Every authored fixture receives a stable personality derived from its unique
marker ID:

- a small hue and saturation offset (age, glass, bulb batch)
- 78–113% output variation, narrowed to 88–110% on navigation fixtures
- an independent phase and flicker speed
- one of five behaviors: steady replacement, filament breathing, old-mains
  flutter, paired-frequency beating, or rare starter/contact dropout

Flicker is normally 0.4–2.5%, perceptible as life rather than an effect.
Rare-dropout fixtures can dip harder, but the event is deliberately sparse.
Navigation sources have a 0.72 energy floor so stairs and the next doorway
remain legible.

World ambient was reduced and cooled; bloom was reduced so glowing envelopes
do not flatten nearby shadows. Existing fixture spacing was retained after
the audit found 190 sources and 83 navigation lights. Adding more emitters
would compete with the Compatibility renderer's per-object light limit and
work against the reference's islands-of-light composition.
