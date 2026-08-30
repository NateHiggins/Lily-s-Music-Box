# C1C-V / DREAM-COLOR-C1D voxel data-path stop gate

C1C technical compatibility: PASS. C1C visual acceptance: FAIL. This distinction is preserved.

This packet contains exactly one 1600×900 Forward+ diagnostic image with three matched panels: actual L1C physical illumination only, actual DreamExposureField occupancy as a debug heatmap, and the combined optical result with debug disabled.

The authorities are separate. LampOpticalInstrument owns electrical/thermal behavior and physical presentation. DreamExposureField owns the 0.5 m persistent/reversible voxel history. The review harness passes the real SpotLight3D origin, direction, range, cone and normalized physical output into add_lamp() at 15 Hz, uploads its RG8 texture, and the cell raymarch samples it in world space. The ecology does not receive commands from either review adapter.

This is a data-path proof, not renewed C1D art acceptance. Do not continue art iteration, supersede S2J, or unblock L1D until the voxel chain passes review.
