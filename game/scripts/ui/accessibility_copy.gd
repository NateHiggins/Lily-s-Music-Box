class_name AccessibilityCopy
extends RefCounted
## Shared plain-language copy for one setting rendered on multiple surfaces.
## Safety/accessibility semantics must not drift because two menus own widgets.

const SOUND_CAPTIONS_LABEL := "CAPTION GAMEPLAY AND DREAM SOUND CUES"
const SOUND_CAPTIONS_HELP := \
		"Names semantic cues and their direction without revealing distance or hidden ownership."
const SLEEP_WARNING_LABEL := "ALWAYS USE GRADUAL SLEEP WARNING"
const SLEEP_WARNING_HELP := \
		"Shows the gradual warning before every sleep onset."
