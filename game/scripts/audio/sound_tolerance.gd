# ABOUTME: SoundTolerance is the section 21 tolerance rule as pure data.
# ABOUTME: Past 30 minutes of one sound, it filters deeper or it goes silent.
class_name SoundTolerance
extends RefCounted

enum Remedy { NONE, FILTER, STOP }

var balance: AddressAudioBalance

var _essential: Dictionary = {}
var _exposure_minutes: Dictionary = {}


func _init(tolerance_balance: AddressAudioBalance = null) -> void:
	balance = tolerance_balance


func register(sound_id: String, essential := true) -> void:
	# An essential sound belongs to the world itself, like the address loop:
	# it cannot stop while the broadcast lives, so past the limit it filters
	# deeper. Every other sound goes silent instead.
	if _essential.has(sound_id):
		return
	_essential[sound_id] = essential
	_exposure_minutes[sound_id] = 0.0


func expose(sound_id: String, minutes: float) -> void:
	# Playing time adds up across the whole session, per sound. Only a
	# registered sound accumulates.
	if not _exposure_minutes.has(sound_id):
		return
	_exposure_minutes[sound_id] = maxf(0.0, _exposure_minutes[sound_id] + minutes)


func exposure_minutes(sound_id: String) -> float:
	return _exposure_minutes.get(sound_id, 0.0)


func is_tolerable(sound_id: String) -> bool:
	# The rule reads "stays tolerable after 30 minutes": the limit itself
	# still tolerates, everything past it grates.
	return exposure_minutes(sound_id) <= balance.tolerance_minutes


func remedy(sound_id: String) -> Remedy:
	if is_tolerable(sound_id):
		return Remedy.NONE
	var essential := _essential.get(sound_id, false) as bool
	return Remedy.FILTER if essential else Remedy.STOP


func remedy_filter_hz() -> float:
	# The deeper filter the FILTER remedy applies to the offending sound.
	return balance.tolerance_filter_hz
