# ABOUTME: Integration tests for the SleepyDex smartphone app in the city run.
# ABOUTME: Covers the live first_met path, the app rows, and the keychain.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")

const MAX_FRAMES_TO_WAIT := 120

# The six common V1 rows in catalog order, with the cup that wakes each type.
const EXPECTED_ROWS: Array[String] = [
	"The Neighbor|Wakes from: any cup.",
	"The Tourist|Wakes from: Frappuccino",
	"The Tech Bro|Wakes from: Bulletproof",
	"The Gamer|Wakes from: Triple Shot",
	"The Tinfoil Man|Wakes from: Turkish Coffee",
	"The Karen|Wakes from: Super Tall American",
]

var _city: CityRun


func before_test() -> void:
	_city = CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_the_city_hands_its_dex_to_the_phone_on_the_hud() -> void:
	assert_object(_city.sleepy_dex()).is_not_null()
	assert_object(_city.hud.dex_app).is_not_null()
	assert_object(_city.hud.dex_app.dex).is_equal(_city.sleepy_dex())
	assert_object(_city.hud.dex_app.library).is_equal(_city.player.brewing_library)
	assert_bool(_city.hud.dex_button.visible).is_true()


func test_the_app_lists_every_common_type_with_picture_and_cure() -> void:
	_city.hud.open_dex()
	var app := _city.hud.dex_app
	assert_bool(app.is_open()).is_true()
	assert_int(app.row_count()).is_equal(EXPECTED_ROWS.size())
	for i: int in range(EXPECTED_ROWS.size()):
		var expected_parts := EXPECTED_ROWS[i].split("|")
		assert_str(app.row_name(i)).is_equal(expected_parts[0])
		assert_str(app.row_cure(i)).is_equal(expected_parts[1])
		assert_str(app.row_status(i)).is_equal("Status: not found")
		# A not-found portrait reads as a dimmed placeholder picture.
		var expected_color := _city.sleepy_dex().listed_entries()[i].portrait_color().darkened(0.55)
		(
			assert_bool(app.row_portrait_color(i) == expected_color)
			. override_failure_message(
				"Row %d portrait should read dimmed: %s" % [i, expected_color]
			)
			. is_true()
		)
	# The rare type stays absent from the phone: no row, no name, no hint.
	for i: int in range(app.row_count()):
		assert_str(app.row_name(i)).is_not_equal("The Moonwalker")


func test_meeting_a_type_in_the_world_opens_its_entry() -> void:
	# The live path, section 9: a sleepwalker senses the player, first_met
	# fires, and the entry opens. Crowd index 4 is the first Tourist.
	var dex := _city.sleepy_dex()
	var tourist := _city.crowd_enemy(4)
	assert_str(tourist.enemy_type.type_id).is_equal("tourist")

	_city.hud.open_dex()
	_city.player.global_position = tourist.global_position
	var frames := 0
	while not dex.is_found("tourist") and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_bool(dex.is_found("tourist")).is_true()
	var app := _city.hud.dex_app
	# The open app rebuilt itself from the entry_opened signal.
	assert_str(app.row_status(1)).is_equal("Status: found")
	(
		assert_bool(app.row_portrait_color(1) == tourist.enemy_type.pajama_color)
		. override_failure_message("The found portrait should read full color.")
		. is_true()
	)
	assert_str(app.counter_text()).is_equal("%d/6 FOUND" % dex.found_count())
	assert_bool(dex.is_found("moonwalker")).is_false()


func test_the_completed_dex_gives_the_mirror_keychain_and_one_line() -> void:
	var dex := _city.sleepy_dex()
	for type_id: String in [
		"neighbor",
		"tourist",
		"tech_bro",
		"gamer",
		"tinfoil_man",
		"karen",
	]:
		assert_bool(dex.meet(type_id)).is_true()
	assert_bool(dex.is_complete()).is_false()

	assert_bool(dex.meet("moonwalker")).is_true()
	assert_bool(dex.is_complete()).is_true()
	# The mirror of the van carries it, and the game says the one line.
	assert_object(_city.van()).is_not_null()
	assert_bool(_city.van().has_keychain_on_mirror()).is_true()
	assert_str(_city.hud.toast_message()).is_equal("IT IS JUST A KEYCHAIN.")

	# No stats, no skill, no secret: the keychain enters no bag and grants
	# nothing. The only other trace is the line on the phone itself.
	assert_int(_city.player.inventory.held_items().size()).is_equal(0)
	_city.hud.open_dex()
	var app := _city.hud.dex_app
	assert_bool(app.is_keychain_visible()).is_true()
	assert_str(app.keychain_text()).is_equal("TROLL DOLL KEYCHAIN\nIt is just a keychain.")
	assert_int(app.row_count()).is_equal(7)
	assert_str(app.counter_text()).is_equal("7/7 FOUND")


func test_the_toggle_key_opens_and_closes_the_app() -> void:
	var app := _city.hud.dex_app
	assert_bool(app.is_open()).is_false()

	_press_toggle()
	var frames := 0
	while not app.is_open() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(app.is_open()).is_true()

	_press_toggle()
	frames = 0
	while app.is_open() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(app.is_open()).is_false()


func _press_toggle() -> void:
	var event := InputEventAction.new()
	event.action = &"toggle_dex"
	event.pressed = true
	Input.parse_input_event(event)
