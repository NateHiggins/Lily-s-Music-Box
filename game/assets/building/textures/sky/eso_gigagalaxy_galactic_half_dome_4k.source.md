# ESO GigaGalaxy celestial map source

- Production file: `eso_gigagalaxy_galactic_half_dome_4k.jpg` (4096x2048)
- Original: `eso0932a.jpg` (6000x3000)
- Publisher: European Southern Observatory
- Credit: ESO/S. Brunier
- Source page: https://www.eso.org/public/images/eso0932a/
- Direct source: https://cdn.eso.org/images/large/eso0932a.jpg
- Retrieved and Lanczos-resized: 2026-08-26

ESO describes this as a 360-degree panorama covering the entire northern and
southern celestial sphere, presented with the Galactic plane horizontal. It
was assembled over several months; ESO notes that a few Solar System objects,
including bright planets, therefore remain in the source photography. The
Orison treats it as measured deep-sky luminance, while its evaluated Sun and
Moon remain authoritative.

Production does not attach this map to the building. The sky shader converts
each local horizon direction into the observer's J2000 equatorial basis and
then through the standard IAU equatorial-to-Galactic rotation before sampling
the map. This makes its Galactic plane share sidereal motion with the catalog
stars in the same shader submission.
