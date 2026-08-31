# Cat-sized tardigrade: primary-source anatomy and optical translation

This pass scales a eutardigrade-inspired animal to a 0.55–0.72 m body length. That is intentionally fantastic—roughly three orders of magnitude above living tardigrades—but its visible anatomy remains derived from microscopy rather than from the familiar toy-like “water bear” caricature.

## Anatomical evidence

- **Whole-body optical sections.** Label-free holotomography resolves the cuticle, head, four trunk segments, four leg pairs, brain, paired stylets, buccal tube, muscular pharynx, oesophagus, midgut, hindgut, salivary glands, storage cells, musculature, claws, and claw glands at different focal depths. It also reports that claws have a distinctly higher refractive index than soft tissue and that the pharynx is thicker and more refractive than the buccal tube. Source: Kim et al., *A Non-Invasive, Label-Free Method for Examining Tardigrade Anatomy Using Holotomography* (2025), https://pmc.ncbi.nlm.nih.gov/articles/PMC11946113/
- **Mouth and foregut.** Eutardigrade mouths can carry radial peribuccal lamellae/papulae and oral tooth rows; paired stylets connect through a buccal tube to a pharyngeal bulb. Source: Smith et al., *Cambrian lobopodians shed light on the origin of the tardigrade body plan* (2023), https://pmc.ncbi.nlm.nih.gov/articles/PMC10334802/
- **Sensory and nervous anatomy.** Confocal neural markers show anterior and posterolateral sensory fields, a nerve ring supplying the peribuccal lamellae, a central brain neuropil, leg nerves, and neurite bundles serving the stylet musculature and pharynx. Source: Mayer et al., *Neural Markers Reveal a One-Segmented Head in Tardigrades* (2013), https://pmc.ncbi.nlm.nih.gov/articles/PMC3596308/
- **Muscle architecture and tun contraction.** Three-dimensional phalloidin reconstructions show repeated longitudinal, transverse, and oblique muscle attachment systems, with additional muscles around the pharyngeal bulb and stylets. Dehydration draws the head and limbs inward into the tun instead of simply shrinking a rigid shell. Source: Halberg et al., *Desiccation Tolerance in the Tardigrade Richtersius coronifer Relies on Muscle Mediated Structural Reorganization* (2013), https://pmc.ncbi.nlm.nih.gov/articles/PMC3877342/
- **Cuticle microstructure.** Milnesium cuticle can contain reticular polygonal ridges and pseudopores rather than literal surface granules. Armoured heterotardigrade plates can contain pillars and internal hollows. Sources: Morek et al., *Rough backs* (2022), https://pmc.ncbi.nlm.nih.gov/articles/PMC9197921/ and Liu et al., *Molting in early Cambrian armored lobopodians* (2024), https://pmc.ncbi.nlm.nih.gov/articles/PMC11226638/
- **Claws.** Milnesium legs terminate in complex double claws: slender primary branches and basal secondary branches bearing multiple hooks. Source: Suzuki, *Beautiful Claws of a Tiny Water Bear* (2022), https://pubmed.ncbi.nlm.nih.gov/35380187/
- **Locomotion.** Tardigrades coordinate eight legs with speed-dependent patterns; ipsilateral swing events generally propagate posterior-to-anterior, while the reduced fourth pair has distinct kinematics. Sources: Nirody et al., *Tardigrades exhibit robust interlimb coordination across walking speeds and terrains* (2021), https://pubmed.ncbi.nlm.nih.gov/34446560/ and Anderson et al., *Comparative analysis of tardigrade locomotion* (2024), https://pubmed.ncbi.nlm.nih.gov/39292666/
- **Optical identity.** In unstained live animals, claws, stylets, midgut contents, and birefringent gut granules autofluoresce; deeper anatomy loses clarity as light traverses more tissue. Source: McGreevy et al., *Protocol for fluorescent live-cell staining of tardigrades* (2024), https://pmc.ncbi.nlm.nih.gov/articles/PMC11369512/

## Implementation mapping

| Visible feature | Research derivation | Runtime expression |
|---|---|---|
| Four inflated trunk annuli | Four trunk segments in optical sections | Unequal segment saddles and transverse contractile bands; never a smooth plush cylinder |
| Eight lobopod legs | Soft unjointed distal limbs | Thick hydrostatic legs with posterior-to-anterior gait phase; reduced fourth pair |
| Double hooked claws | Milnesium claw configuration | High-index paired primary/secondary hooks with restrained autofluorescent boundary response |
| Lamellate mouth cone | Peribuccal lamellae/papulae | Six asymmetric radial mouth folds around a dark terminal aperture |
| Paired stylets and pharyngeal bulb | Bucco-pharyngeal apparatus | Two dense refractive stylet tracks leading into a pulsing pear-shaped suction bulb |
| Midgut and storage cells | Holotomography and live fluorescence | Deep, heterogeneous axial organ with suspended storage-cell caustics and depth loss |
| Segmental muscle system | Phalloidin reconstructions | Repeated longitudinal/oblique birefringent cable fields anchored across annuli |
| Cuticle ridges, pseudopores, pillars | SEM/TEM cuticle studies | Object/world-space reticulum, recessed pseudopores, and thickness-dependent transmission—not scales painted with a UV texture |
| Tun capacity | Muscle-mediated structural reorganization | Contractile state can pull head and legs inward while bands thicken; no rigid-shell scaling trick |

## Species optical contrast

- **Seam grazer:** thin wet membrane, ventral comb and peristaltic seam-trace capillaries; current G travels as a comb-shaped interference front, durable R remains in branching seam residue.
- **Crystal listener:** dark still shell around an internally rotating ordered resonator; G becomes narrow polarized caustics, R remains as angular lattice memory.
- **Fold crab:** layered load-bearing plates, socket cups, muscular ventrum and sutures; G travels along joint load paths, R lodges in plate seams and the transfer rosette.
- **Cat-sized tardigrade:** thick folded cuticle, pseudopore/pillar reticulum, lobopods, double claws, stylets, pharyngeal bulb and deep gut; G reveals near-side muscle and pharyngeal pumping, while R remains in cuticular folds, claw ridges and prior gut illumination.

All four expressions sample the existing shared `DreamExposureField` RG8 texture in world space. They do not own a field, create per-animal textures/materials, or make ecology decisions.
