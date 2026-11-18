# LILITH image production

Use the private style, cast, stance, background and pick files as the sources
for generation. The panel script supplies the cast, place, shape and build mode.
The style file owns the medium and recurring visual rules. The cast file owns
identity, wardrobe and model settings. The stance file owns the drawable pose.
Keep private trigger words, likenesses, model paths and prompt text out of the
public repository and shared review notes.

## Plan the smallest render

- Compose with isolated character figures and an empty background plate by
  default. Render a shared scene when contact makes composition impractical.
  Use object stock for props and the panel aspect ratio for a shared scene,
  strip or cover. Letter the finished panel in a separate editable pass.
- Assemble style, medium, identity, wardrobe, pose and framing from their
  owning fields. Include the medium once. Keep character-specific expression
  cues separate from the shared style. Keep the private approved strengths,
  checkpoint and inference settings fixed in a comparison.
- Proofread each stance against its panel. Replace scene nouns, action-slug
  repetitions, other speakers and abstract tone with visible gestures, gaze,
  posture and held props. For doorway poses, put the frame on the background
  plate and describe the weight shift and arm position on the figure.
- Change only the identified variable in fixed-seed trials. Test doorway
  rewrites and negative-prompt routing as separate arms. Compare wardrobe
  changes on their selected seeds, retaining the garment and using an off-white
  value with visible hatched shadow. Keep the selected source and save variants
  separately. Re-render changed poses without approved picks only.
- Run at render priority on the shared GPU lane. Group jobs by LoRA. Resume
  only when the existing image matches the intended settings and provenance.
  Mark pre-training stock separately so it can be replaced after training.

## Review the source and the cut

- Inspect full-size figure stock for stray writing, unwanted architecture,
  broken hands and paper showing through pale skin or clothing. Try the short
  wordless constraint on stock and judge it against fixed-seed controls.
  Inspect the next daily strip as a separate check.
- Inspect the cutout over a contrasting ground, especially pale cloth, face
  edges, corners and small props. An OCR flag can focus review. A human checks
  gibberish and stylized marks, and rejects visible writing before selection or
  training intake. Bind decisions to the exact source image and any cutout.
- Keep a private per-image record of the prompt, negative prompt, seed, model,
  checkpoint, strength and output hash. Track crop, pick and rejection
  separately. A file that shares a seed or filename with an approved image
  needs its own review if the pixels changed.
- Admit only selected on-model stock to the refinement set. Exclude images with
  lettering, architecture artifacts, matte holes, soft upscales, multiple
  figures or unsuitable pose modes. Keep the old checkpoint and record the
  training medium in captions. Compare held-out poses on fixed inputs and wait
  for the owner's ruling before switching model versions.

Test overlap masks or isolated inpainting on one shared-scene likeness problem
before expanding their use. Treat duplicate-image detection, face checks,
regional LoRA, versioned model selection and seed diversification as experiments
until their effect is measured on approved examples.
