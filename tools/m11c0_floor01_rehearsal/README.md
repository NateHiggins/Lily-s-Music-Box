# M11C0 disposable Godot harness templates

The splitter copies the contents of `templates/` into its external disposable
Godot project. These files are validation instruments only; they are not a
production floor loader or a cutover implementation.

The generated split receipt is selected with `M11C0_CONFIG` and the authored
partition manifest with `M11C0_MANIFEST`. Default discovery also accepts
`res://split_receipt.json` and `res://partition_manifest.json`. A split receipt
must identify the copied source using `original_scene_path`,
`source_scene_path`, or `source.gltf_path`, and enumerate cells using:

```json
{
  "source": {"gltf_path": "res://original/floor_01.gltf"},
  "cells": [
    {
      "id": "CELL_ORISON_F01_INTERIOR",
      "slug": "orison_f01_interior",
      "gltf_path": "res://cells/orison_f01_interior.gltf",
      "bin_path": "res://cells/orison_f01_interior.bin"
    }
  ]
}
```

Optional `collision_probes` records require `seam_id`, finite `from` and `to`
triples, and `expect` equal to `hit` or `clear`. A named shared boundary without
those facts is reported as `UNPROVEN`; the harness never invents an expected
collision result.

Optional `capture_views` records require `id`, `seam_id`, `eye`, `target`, and
optionally `fov_degrees`. Manifest-plane fallback views are captured but marked
`UNPROVEN` for framing.

Run the imported disposable project twice:

```text
M11C0_MODE=runtime M11C0_CONFIG=res://split_receipt.json godot --headless --path <scratch-project>
M11C0_MODE=capture M11C0_CONFIG=res://split_receipt.json godot --path <scratch-project>
```

`M11C0_RUNTIME_RECEIPT`, `M11C0_CAPTURE_RECEIPT`, and `M11C0_CAPTURE_DIR`
override output locations. Capture refuses any renderer other than Forward+.
The harness adds only a camera—never geometry, lighting, a world environment,
labels, or arrows.
