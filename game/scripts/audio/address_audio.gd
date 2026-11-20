# ABOUTME: AddressAudio is the pure rulebook of the section 21 address loop.
# ABOUTME: Layer choice, volumes, filters, and pole offsets live here, not in nodes.
class_name AddressAudio
extends RefCounted

enum Layer { FAR, MID, NEAR }

# The address never plays at full volume: every mix stays at least this far
# below the 0 dB unity of a plain player.
const FULL_VOLUME_GUARD_DB := 0.5
# The offset sampler retries a blocked point this many times before it places
# the point in the widest free stretch of the loop.
const MAX_OFFSET_ATTEMPTS := 64

var balance: AddressAudioBalance


func _init(loop_balance: AddressAudioBalance = null) -> void:
	balance = loop_balance


func layer_for_distance(distance: float) -> Layer:
	# The three distance layers of section 21: the pole zone marks near, the
	# mid reach holds recognizable words, and everything beyond is the rumble.
	if distance <= balance.near_radius:
		return Layer.NEAR
	if distance <= balance.mid_radius:
		return Layer.MID
	return Layer.FAR


func volume_db(layer: Layer, grabbed := false) -> float:
	# The address always arrives below full volume, grabbed or not: the hug
	# swell adds, but the rule caps the mix under 0 dB.
	var volume := _base_volume_db(layer)
	if grabbed:
		volume += balance.hug_swell_db
	return minf(volume, -FULL_VOLUME_GUARD_DB)


func low_pass_hz(layer: Layer) -> float:
	# The address always arrives filtered, through walls or over a PA hum:
	# the cutoff rises with clarity but never opens fully.
	match layer:
		Layer.NEAR:
			return balance.near_low_pass_hz
		Layer.MID:
			return balance.mid_low_pass_hz
		_:
			return balance.far_low_pass_hz


func cutoffs_hz() -> Array[float]:
	# The three cutoffs in Layer order, so a caller can index them like the
	# enum: FAR first, NEAR last.
	return [balance.far_low_pass_hz, balance.mid_low_pass_hz, balance.near_low_pass_hz]


func is_enemy_close(enemy_distance: float) -> bool:
	return enemy_distance <= balance.antagonist_radius


func antagonist_volume_db(enemy_distance: float) -> float:
	# The antagonist track rises on a straight ramp as the nearest sleeping
	# enemy closes: quiet across the street, loud at arm's length.
	var reach := maxf(balance.antagonist_radius, 1.0)
	var closeness := clampf(enemy_distance, 0.0, reach) / reach
	return lerpf(balance.antagonist_close_volume_db, balance.antagonist_far_volume_db, closeness)


func silence_seconds() -> float:
	# The tower owns the cut clock; the audio follows: the cut stops the
	# address mid-word, this much silence passes, then the birdsong plays.
	return balance.silence_seconds


func loop_offsets(pole_count: int, seed_value: int) -> Array[float]:
	# Every pole plays the same 5-second loop from its own start point. The
	# seeded generator keeps the spread stable per city, and the sync guard
	# holds any two poles apart on the loop circle, so the loops never sync.
	var offsets: Array[float] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in range(pole_count):
		var candidate := 0.0
		var attempts := 0
		while attempts < MAX_OFFSET_ATTEMPTS:
			candidate = rng.randf_range(0.0, balance.loop_seconds)
			if _clears_sync_guard(candidate, offsets):
				break
			attempts += 1
		if not _clears_sync_guard(candidate, offsets):
			# The guard cannot fit another free point, a tiny loop or a wide
			# guard: the widest free stretch holds the newcomer farthest from
			# the pack.
			candidate = _widest_gap_midpoint(offsets)
		offsets.append(candidate)
	return offsets


static func city_seed(city_id: String) -> int:
	# Every city hashes its own id into a stable seed, so each city keeps its
	# own pole spread across runs and saves.
	return city_id.hash()


func _base_volume_db(layer: Layer) -> float:
	match layer:
		Layer.NEAR:
			return balance.near_volume_db
		Layer.MID:
			return balance.mid_volume_db
		_:
			return balance.far_volume_db


func _clears_sync_guard(candidate: float, placed: Array[float]) -> bool:
	for offset: float in placed:
		if _loop_distance(candidate, offset) < balance.sync_guard_seconds:
			return false
	return true


func _loop_distance(a: float, b: float) -> float:
	# The loop is a circle: two points close across the wrap would sync just
	# as surely as two points side by side.
	var direct := absf(a - b)
	return minf(direct, balance.loop_seconds - direct)


func _widest_gap_midpoint(placed: Array[float]) -> float:
	if placed.is_empty():
		return 0.0
	var sorted_offsets: Array[float] = []
	sorted_offsets.assign(placed)
	sorted_offsets.sort()
	var best_start := sorted_offsets[-1]
	var best_gap := balance.loop_seconds - sorted_offsets[-1] + sorted_offsets[0]
	for i: int in range(sorted_offsets.size() - 1):
		var gap := sorted_offsets[i + 1] - sorted_offsets[i]
		if gap > best_gap:
			best_gap = gap
			best_start = sorted_offsets[i]
	return fmod(best_start + best_gap * 0.5, balance.loop_seconds)
