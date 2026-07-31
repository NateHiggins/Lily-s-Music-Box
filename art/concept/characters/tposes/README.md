# Orison Cast — Reconstruction Sources

Nineteen front-view character sources generated for image-to-3D mesh
reconstruction: the seventeen individually named residents plus the two people
represented by the Transient Guests role.

All selected images share the same reconstruction contract:

- one person per image on a seamless white background;
- strict front-facing T-pose with straight arms and separated fingers;
- complete silhouette with clearance around fingertips, hair, and footwear;
- orthographic-like long-lens framing with minimal perspective distortion;
- neutral three-point lighting, soft fill, subtle rim, and a small foot shadow;
- realistic skin, hair, clothing construction, surface wear, and facial detail;
- empty hands and no environmental props.

`cast_tpose_contact_sheet.jpg` is a visual QA index only. Feed the original PNG
for each character to the reconstruction system.

The Transient Guests were separated into `transient_guest_a_tpose.png` and
`transient_guest_b_tpose.png` so their meshes can be generated independently.
Mina's initial render was rejected because its fingertips touched the image
edges; `mina_vale_tpose.png` is the corrected, wider-framed version.
