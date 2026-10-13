# ABOUTME: Integration tests for the cafe level flow: throwing, hugging, losing, winning.
# ABOUTME: Drives the real cafe scene with physics frames, no input devices needed.
extends GdUnitTestSuite

const CAFE_SCENE := preload("res://scenes/cafe/cafe.tscn")

const MAX_FRAMES_TO_WAIT := 300

var _cafe: Cafe


func before_test() -> void:
	_cafe = CAFE_SCENE.instantiate()
	add_child(auto_free(_cafe))
	await get_tree().physics_frame


func test_player_throws_cup_in_direction() -> void:
	var cup := _cafe.player.throw_cup(Vector2.RIGHT) as CoffeeCup
	assert_object(cup).is_not_null()
	assert_vector(cup.direction).is_equal(Vector2.RIGHT)
	cup.queue_free()


func test_sustained_hug_puts_player_to_sleep() -> void:
	var sleepwalker := _cafe.get_sleepwalker(0)
	_cafe.player.position = sleepwalker.position

	var frames := 0
	while not _cafe.player.sleep_meter.is_asleep() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_bool(_cafe.player.sleep_meter.is_asleep()).is_true()
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_bool(_cafe.is_game_over()).is_true()
	assert_bool(_cafe.is_game_won()).is_false()


func test_waking_all_sleepwalkers_wins() -> void:
	for index: int in _cafe.sleepwalkers.get_child_count():
		_cafe.get_sleepwalker(index).wake_up()

	assert_bool(_cafe.is_game_won()).is_true()
	assert_bool(_cafe.is_game_over()).is_false()
	assert_str(_cafe.status_label.text).is_equal(Cafe.WIN_TEXT)
