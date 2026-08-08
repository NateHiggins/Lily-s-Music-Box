class_name BarPA
extends RefCounted
## The Harukiya's mediocre PA, as an audio bus.
##
## The brief's rule: community recordings arrive from wildly different
## microphones, so vocals are stored relatively DRY and coloured at
## playback by the fictional rig they are supposedly coming out of.
## Everyone's voice then sounds like it is in the same room, because it
## is — the physical bar becomes part of the instrument, and a phone mic
## and a good condenser end up closer together than they started.
##
## Chain, in the brief's order: high-pass · karaoke mic EQ · mild
## compression · subtle saturation · modest slapback · cheap digital
## reverb. Nothing here is flattering, and that is the point.

const BUS := "BarPA"
const MIC_BUS := "MicRecord"


static func ensure_bus() -> int:
	var index := AudioServer.get_bus_index(BUS)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_volume_db(index, -3.0)

	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 135.0        # nothing below the chest, like a cheap PA
	hp.resonance = 0.12
	AudioServer.add_bus_effect(index, hp)

	# The karaoke voice: presence pushed hard, top end simply absent.
	var eq := AudioEffectEQ10.new()
	eq.set_band_gain_db(0, -8.0)     # 31 Hz
	eq.set_band_gain_db(1, -6.0)     # 62
	eq.set_band_gain_db(2, -2.0)     # 125
	eq.set_band_gain_db(3, 0.0)      # 250
	eq.set_band_gain_db(4, 1.5)      # 500
	eq.set_band_gain_db(5, 3.5)      # 1k
	eq.set_band_gain_db(6, 4.5)      # 2k  - the presence bump
	eq.set_band_gain_db(7, 2.0)      # 4k
	eq.set_band_gain_db(8, -5.0)     # 8k
	eq.set_band_gain_db(9, -12.0)    # 16k - there is no air in this room
	AudioServer.add_bus_effect(index, eq)

	var comp := AudioEffectCompressor.new()
	comp.threshold = -18.0
	comp.ratio = 3.2
	comp.attack_us = 12000.0
	comp.release_ms = 180.0
	comp.gain = 3.0
	AudioServer.add_bus_effect(index, comp)

	# Saturation, not distortion: the amp is tired, not broken.
	var sat := AudioEffectDistortion.new()
	sat.mode = AudioEffectDistortion.MODE_OVERDRIVE
	sat.drive = 0.14
	sat.pre_gain = -2.0
	sat.post_gain = -1.0
	AudioServer.add_bus_effect(index, sat)

	# Slapback: one short repeat, the free reverb of every cheap desk.
	var delay := AudioEffectDelay.new()
	delay.dry = 1.0
	delay.tap1_active = true
	delay.tap1_delay_ms = 96.0
	delay.tap1_level_db = -17.0
	delay.tap1_pan = 0.15
	delay.tap2_active = false
	delay.feedback_active = true
	delay.feedback_delay_ms = 190.0
	delay.feedback_level_db = -26.0
	AudioServer.add_bus_effect(index, delay)

	var verb := AudioEffectReverb.new()
	verb.room_size = 0.34       # a basement, not a hall
	verb.damping = 0.72
	verb.spread = 0.60
	verb.wet = 0.19
	verb.dry = 0.90
	AudioServer.add_bus_effect(index, verb)
	return index


## The capture bus. Kept OUT of the PA chain on purpose: what gets
## stored is dry, and the colour is applied on the way back out. Muted
## so the singer is not fed back into the room while recording.
static func ensure_mic_bus() -> AudioEffectRecord:
	var index := AudioServer.get_bus_index(MIC_BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, MIC_BUS)
	AudioServer.set_bus_mute(index, true)
	for e in AudioServer.get_bus_effect_count(index):
		var existing := AudioServer.get_bus_effect(index, e)
		if existing is AudioEffectRecord:
			return existing
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(index, rec)
	return rec
