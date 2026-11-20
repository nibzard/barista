# ABOUTME: Unit tests for the placeholder WAV tones of the address loop.
# ABOUTME: The tones must load as plain 16-bit WAV data with the right lengths.
extends GdUnitTestSuite

const ADDRESS_BALANCE := preload("res://resources/balance/address_audio.tres")


func test_the_address_loop_matches_the_balance_length() -> void:
	var stream := PlaceholderTones.address_loop(ADDRESS_BALANCE.loop_seconds)
	assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
	assert_bool(stream.stereo).is_false()
	assert_int(stream.mix_rate).is_equal(22050)
	assert_float(stream.get_length()).is_equal_approx(ADDRESS_BALANCE.loop_seconds, 0.01)


func test_the_address_loop_loops_forever() -> void:
	var stream := PlaceholderTones.address_loop(ADDRESS_BALANCE.loop_seconds)
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(stream.loop_begin).is_equal(0)
	assert_int(stream.loop_end).is_greater(0)


func test_the_birdsong_plays_once() -> void:
	var stream := PlaceholderTones.birdsong()
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)
	assert_float(stream.get_length()).is_equal_approx(3.0, 0.01)


func test_every_venue_gets_its_own_record() -> void:
	var venues: Array[int] = [
		DiegeticMusic.Venue.CAFE,
		DiegeticMusic.Venue.BAND_STAGE,
		DiegeticMusic.Venue.SLEEPVANA_CONCERT,
	]
	var data: Array[PackedByteArray] = []
	for venue: int in venues:
		var stream := PlaceholderTones.diegetic_loop(venue)
		assert_float(stream.get_length()).is_equal_approx(6.0, 0.01)
		data.append(stream.data)
	assert_bool(data[0] != data[1]).is_true()
	assert_bool(data[1] != data[2]).is_true()
	assert_bool(data[0] != data[2]).is_true()


func test_the_antagonist_motif_loops() -> void:
	var stream := PlaceholderTones.antagonist_loop()
	assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_float(stream.get_length()).is_equal_approx(4.0, 0.01)


func test_no_tone_is_silent_data() -> void:
	var streams: Array[AudioStreamWAV] = [
		PlaceholderTones.address_loop(ADDRESS_BALANCE.loop_seconds),
		PlaceholderTones.birdsong(),
		PlaceholderTones.antagonist_loop(),
		PlaceholderTones.diegetic_loop(DiegeticMusic.Venue.CAFE),
	]
	for stream: AudioStreamWAV in streams:
		var bytes := stream.data
		assert_int(bytes.size()).is_greater(0)
		var loudest := 0
		for i: int in range(0, bytes.size(), 2):
			var value := absi(bytes.decode_s16(i))
			loudest = maxi(loudest, value)
		assert_int(loudest).is_greater(1000)
