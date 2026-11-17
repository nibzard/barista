# ABOUTME: Unit tests for the section 21 address loop rulebook.
# ABOUTME: Pins the layer choice, the volume and filter rules, the hug swell,
# ABOUTME: the antagonist ramp, and the seeded pole offsets that never sync.
extends GdUnitTestSuite

const ADDRESS_BALANCE := preload("res://resources/balance/address_audio.tres")

var _rules: AddressAudio


func before_test() -> void:
	_rules = AddressAudio.new(ADDRESS_BALANCE)


func test_morgen_voice_track_is_a_quiet_speech_placeholder() -> void:
	# The opening video speaks through one cached wave, section 22: a plain
	# non-looping track that runs the video length under the subtitles.
	var stream := PlaceholderTones.morgen_voice_track(2.0)
	assert_object(stream).is_not_null()
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)
	# The wave rides one RIFF header of 44 bytes before the PCM data.
	assert_int(stream.data.size()).is_equal(44 + int(2.0 * PlaceholderTones.SAMPLE_RATE) * 2)
	assert_object(PlaceholderTones.morgen_voice_track(2.0)).is_same(stream)


func test_the_tres_pins_the_spec_numbers() -> void:
	assert_float(ADDRESS_BALANCE.loop_seconds).is_equal(5.0)
	assert_float(ADDRESS_BALANCE.tolerance_minutes).is_equal(30.0)
	assert_float(ADDRESS_BALANCE.silence_seconds).is_equal(1.0)


func test_near_layer_inside_the_pole_zone() -> void:
	assert_int(_rules.layer_for_distance(0.0)).is_equal(AddressAudio.Layer.NEAR)
	assert_int(_rules.layer_for_distance(ADDRESS_BALANCE.near_radius)).is_equal(
		AddressAudio.Layer.NEAR
	)


func test_mid_layer_beyond_the_pole_zone() -> void:
	assert_int(_rules.layer_for_distance(ADDRESS_BALANCE.near_radius + 0.01)).is_equal(
		AddressAudio.Layer.MID
	)
	assert_int(_rules.layer_for_distance(ADDRESS_BALANCE.mid_radius)).is_equal(
		AddressAudio.Layer.MID
	)


func test_far_layer_beyond_the_mid_reach() -> void:
	assert_int(_rules.layer_for_distance(ADDRESS_BALANCE.mid_radius + 0.01)).is_equal(
		AddressAudio.Layer.FAR
	)
	assert_int(_rules.layer_for_distance(3000.0)).is_equal(AddressAudio.Layer.FAR)


func test_every_layer_stays_below_full_volume() -> void:
	# The address never plays at full volume, grabbed or not.
	var layers: Array[int] = [
		AddressAudio.Layer.FAR, AddressAudio.Layer.MID, AddressAudio.Layer.NEAR
	]
	for layer: int in layers:
		assert_float(_rules.volume_db(layer)).is_less(0.0)
		assert_float(_rules.volume_db(layer, true)).is_less(0.0)


func test_a_hug_swells_the_address_by_the_balance_step() -> void:
	var plain := _rules.volume_db(AddressAudio.Layer.NEAR)
	var hugged := _rules.volume_db(AddressAudio.Layer.NEAR, true)
	assert_float(hugged).is_equal_approx(plain + ADDRESS_BALANCE.hug_swell_db, 0.001)


func test_every_layer_arrives_filtered() -> void:
	# The address always arrives filtered: the cutoff rises with clarity but
	# never opens fully.
	assert_float(_rules.low_pass_hz(AddressAudio.Layer.FAR)).is_equal(
		ADDRESS_BALANCE.far_low_pass_hz
	)
	assert_float(_rules.low_pass_hz(AddressAudio.Layer.MID)).is_equal(
		ADDRESS_BALANCE.mid_low_pass_hz
	)
	assert_float(_rules.low_pass_hz(AddressAudio.Layer.NEAR)).is_equal(
		ADDRESS_BALANCE.near_low_pass_hz
	)
	assert_float(_rules.low_pass_hz(AddressAudio.Layer.FAR)).is_less(
		_rules.low_pass_hz(AddressAudio.Layer.MID)
	)
	assert_float(_rules.low_pass_hz(AddressAudio.Layer.MID)).is_less(
		_rules.low_pass_hz(AddressAudio.Layer.NEAR)
	)
	assert_float(_rules.low_pass_hz(AddressAudio.Layer.NEAR)).is_less(20000.0)


func test_the_antagonist_rises_as_the_enemy_closes() -> void:
	assert_float(_rules.antagonist_volume_db(0.0)).is_equal_approx(
		ADDRESS_BALANCE.antagonist_close_volume_db, 0.001
	)
	assert_float(_rules.antagonist_volume_db(ADDRESS_BALANCE.antagonist_radius)).is_equal_approx(
		ADDRESS_BALANCE.antagonist_far_volume_db, 0.001
	)
	var halfway := ADDRESS_BALANCE.antagonist_radius * 0.5
	assert_float(_rules.antagonist_volume_db(halfway)).is_equal_approx(
		lerpf(
			ADDRESS_BALANCE.antagonist_close_volume_db,
			ADDRESS_BALANCE.antagonist_far_volume_db,
			0.5
		),
		0.001
	)
	assert_float(_rules.antagonist_volume_db(99999.0)).is_equal_approx(
		ADDRESS_BALANCE.antagonist_far_volume_db, 0.001
	)


func test_the_antagonist_is_close_only_inside_its_radius() -> void:
	assert_bool(_rules.is_enemy_close(ADDRESS_BALANCE.antagonist_radius)).is_true()
	assert_bool(_rules.is_enemy_close(ADDRESS_BALANCE.antagonist_radius + 0.01)).is_false()


func test_loop_offsets_are_stable_per_seed() -> void:
	var first := _rules.loop_offsets(3, 42)
	var second := _rules.loop_offsets(3, 42)
	assert_int(first.size()).is_equal(second.size())
	for i: int in first.size():
		assert_float(first[i]).is_equal(second[i])
	var other := _rules.loop_offsets(3, 43)
	assert_float(other[0]).is_not_equal(first[0])


func test_loop_offsets_cover_every_pole() -> void:
	var offsets := _rules.loop_offsets(3, 7)
	assert_int(offsets.size()).is_equal(3)
	for offset: float in offsets:
		assert_float(offset).is_greater_equal(0.0)
		assert_float(offset).is_less(ADDRESS_BALANCE.loop_seconds)


func test_loop_offsets_never_sync() -> void:
	# Any two offsets stay at least the sync guard apart on the loop circle,
	# across seeds and pole counts.
	var seeds: Array[int] = [7, 42, 1234, 999983]
	for pole_count: int in range(2, 7):
		for seed_value: int in seeds:
			var offsets := _rules.loop_offsets(pole_count, seed_value)
			for a: int in offsets.size():
				for b: int in range(a + 1, offsets.size()):
					var direct := absf(offsets[a] - offsets[b])
					var circular := minf(direct, ADDRESS_BALANCE.loop_seconds - direct)
					assert_float(circular).is_greater_equal(
						ADDRESS_BALANCE.sync_guard_seconds - 0.0001
					)


func test_loop_offsets_survive_a_guard_that_cannot_fit() -> void:
	# A tiny loop with a wide guard leaves no free point: the sampler still
	# returns one offset per pole, all inside the loop.
	var tiny := AddressAudioBalance.new()
	tiny.loop_seconds = 1.0
	tiny.sync_guard_seconds = 0.6
	var tiny_rules := AddressAudio.new(tiny)
	var offsets := tiny_rules.loop_offsets(3, 5)
	assert_int(offsets.size()).is_equal(3)
	for offset: float in offsets:
		assert_float(offset).is_greater_equal(0.0)
		assert_float(offset).is_less(1.0)
	var repeat := tiny_rules.loop_offsets(3, 5)
	for i: int in offsets.size():
		assert_float(repeat[i]).is_equal(offsets[i])


func test_city_seed_is_stable_and_city_distinct() -> void:
	assert_int(AddressAudio.city_seed("san_coffesco")).is_equal(
		AddressAudio.city_seed("san_coffesco")
	)
	assert_int(AddressAudio.city_seed("san_coffesco")).is_not_equal(
		AddressAudio.city_seed("steamtle")
	)


func test_silence_between_cut_and_birdsong() -> void:
	assert_float(_rules.silence_seconds()).is_equal(1.0)
