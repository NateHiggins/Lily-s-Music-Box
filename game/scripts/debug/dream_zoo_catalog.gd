class_name DreamZooCatalog
extends RefCounted
## Debug display records only. No scene factories, simulation, fields or saves.
## The warehouse consumes id for selection, label for signage and description
## for the selected bay. Each call returns fresh dictionaries for UI isolation.
##
## Designed families: design/DREAM_FAUNA_BRIEF.md, Proposed bestiary and V6.
## Existing inventory: design/DREAM_TEMPORAL_SPECIMEN_LEDGER.md, resolutions
## 1-3b, and the current DreamFaunaDirector's five organelle family labels.
## These records describe availability, not art or runtime acceptance. Hero,
## margin, living architecture and surface tendrils are excluded here; the
## warehouse reports their live availability through its own integration.


static func placeholders() -> Array[Dictionary]:
	return [
		{
			"id": "jewelfruit",
			"label": "Jewelfruit",
			"description": "DESIGNED — NOT IMPLEMENTED\nCanopy mineral fruit: a faceted stone held in a gold bezel. The brief proposes ripening rather than locomotion. This bay contains a labeled placeholder only.",
		},
		{
			"id": "spiralings",
			"label": "Spiralings",
			"description": "DESIGNED — NOT IMPLEMENTED\nWall-crawling forms with a true spiral shell and an open keel through which the wall remains visible. This bay contains a labeled placeholder only.",
		},
		{
			"id": "chandelettes",
			"label": "Chandelettes",
			"description": "DESIGNED — NOT IMPLEMENTED\nSlow lamp-orbiting forms with pendant-shaped abdomens, one stone and backlit membrane wings. This bay contains a labeled placeholder only.",
		},
		{
			"id": "bezel_beetles",
			"label": "Bezel Beetles",
			"description": "DESIGNED — NOT IMPLEMENTED\nRolling mineral forms: a cut gem on prong legs, with stillness camouflage and a proposed impossible gem window. This bay contains a labeled placeholder only.",
		},
		{
			"id": "deep_koi",
			"label": "Deep Koi",
			"description": "DESIGNED — NOT IMPLEMENTED\nSub-surface swimmers proposed as moving relief and absence, with a gold fin breach rather than a separate body mesh. This bay contains a labeled placeholder only.",
		},
		{
			"id": "parliaments",
			"label": "Parliaments",
			"description": "DESIGNED — NOT IMPLEMENTED\nSynchronized vesica-shaped fragments with lapis edges imply a larger form through their shared motion. This bay contains a labeled placeholder only.",
		},
	]


static func deferred_groups() -> Array[Dictionary]:
	return [
		{
			"id": "gilders_buttons",
			"label": "Gilder's Buttons — allocation",
			"description": "PLACEHOLDER — existing work, not running in this bay\nEncrusting growth marks where the Dream body allocates resources. This is one of the five shared density-driven organelle families, not an independently simulated animal.",
		},
		{
			"id": "tessellates",
			"label": "Tessellates — uptake",
			"description": "PLACEHOLDER — existing work, not running in this bay\nTessellated mobile tissue takes up the body's allocation. The existing family belongs to the shared organelle density system; this display creates no individuals from it.",
		},
		{
			"id": "wine_anemones",
			"label": "Wine Anemones — reclamation",
			"description": "PLACEHOLDER — existing work, not running in this bay\nJoint-bound curled growth reclaims matter within the Dream body. The existing family belongs to the shared organelle density system; this display creates no individuals from it.",
		},
		{
			"id": "ribbonettes",
			"label": "Ribbonettes — signalling",
			"description": "PLACEHOLDER — existing work, not running in this bay\nRibbon-shaped tissue provides a signalling display across the Dream body. Its existing motion is not a claim that this bay runs a courtship or reproduction simulation.",
		},
		{
			"id": "the_loupe",
			"label": "The Loupe — inhibition",
			"description": "PLACEHOLDER — existing work, not running in this bay\nThe observing lens is an organelle of inhibition: the body prunes surplus uptake. Its existing harmless presentation does not make this bay a predator encounter.",
		},
		{
			"id": "dream_pursuer",
			"label": "The Tenant — maze encounter",
			"description": "PLACEHOLDER — existing work, not running in this bay\nThe maze's pursuer and embrace belong to their encounter owners. The Tenant is not another zoo species, and this bay starts no pursuit or encounter.",
		},
		{
			"id": "dream_hazards",
			"label": "Dream hazards — encounter systems",
			"description": "PLACEHOLDER — existing work, not running in this bay\nExisting dream hazards and their tells belong to the maze encounter systems. This catalogue does not activate danger, damage or route gates.",
		},
		{
			"id": "dream_surface_tissue",
			"label": "Dream surface tissue — material study",
			"description": "PLACEHOLDER — existing work, not running in this bay\nThe Dream's existing surface treatments are tissue and material work. This reserved study is not a new organism or a claim that its full surface behavior is demonstrated here.",
		},
		{
			"id": "case_incarnation_surfaces",
			"label": "Six case incarnations — surface studies",
			"description": "PLACEHOLDER — existing work, not running in this bay\nSix existing case-specific surface treatments are reserved for a separate material study. They are not six animal species; surface work and temporal sensory behavior have different proof histories.",
		},
	]
