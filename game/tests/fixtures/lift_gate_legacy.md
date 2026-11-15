# Legacy gate cost control

Diagnostic fixtures only; no production scene loads these files.

Source: f12a900218790602b9da94c1686c9f84fe42e8b7.
The GLB is byte-identical to that commit (SHA256 f6031e9e2ae7af371ef42c715fe82901ae70957a09f815c3fbda59e31be75ad3).
The driver matches the original source (SHA256 7c1188e8737beaca4efe1df067a90a2663db772eea37bb952f0c2f8d34a92cac) except its Model preload points to the diagnostic GLB.

Both old and new GLBs use the real editor importer, with identical params;
separate remap paths and UIDs are required. The cost probe refuses parameter
mismatch and records the actual imported mesh formats and shadow resources.
It measures old/new/old at closed and open poses in one installed world,
restores owner pose, visibility, camera, mirror camera, cap and VSync, and
keeps all raw samples. No gameplay, NPC, reversal or artistic acceptance
comes from the timing control.
