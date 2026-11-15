# ABOUTME: Unit tests for the section 21 diegetic music map.
# ABOUTME: The cafe record, the band song, and the Sleepvana hit, plus the
# ABOUTME: rule that only the address dies with the tower.
extends GdUnitTestSuite


func test_enum_order_pins_silent_first() -> void:
	assert_int(DiegeticMusic.Venue.SILENT).is_equal(0)


func test_the_cafe_plays_vinyl_jazz() -> void:
	assert_str(DiegeticMusic.track_name(DiegeticMusic.Venue.CAFE)).is_equal("Vinyl Jazz")


func test_the_band_stage_plays_the_endless_song() -> void:
	assert_str(DiegeticMusic.track_name(DiegeticMusic.Venue.BAND_STAGE)).is_equal(
		"The Endless Song"
	)


func test_sleepvana_plays_its_hit() -> void:
	assert_str(DiegeticMusic.track_name(DiegeticMusic.Venue.SLEEPVANA_CONCERT)).is_equal(
		"Smells Like Bean Spirit"
	)


func test_silence_has_no_track() -> void:
	assert_str(DiegeticMusic.track_name(DiegeticMusic.Venue.SILENT)).is_equal("")


func test_diegetic_music_plays_with_the_tower_off() -> void:
	# The tower cut kills only the address: diegetic music is the world's own.
	assert_bool(DiegeticMusic.plays_with_tower_off(DiegeticMusic.Venue.CAFE)).is_true()
	assert_bool(DiegeticMusic.plays_with_tower_off(DiegeticMusic.Venue.BAND_STAGE)).is_true()
	assert_bool(DiegeticMusic.plays_with_tower_off(DiegeticMusic.Venue.SLEEPVANA_CONCERT)).is_true()
	assert_bool(DiegeticMusic.plays_with_tower_off(DiegeticMusic.Venue.SILENT)).is_false()
