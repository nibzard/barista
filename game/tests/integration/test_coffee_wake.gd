# ABOUTME: Integration test that a thrown coffee cup wakes a sleepwalker on contact.
# ABOUTME: Uses real physics overlap in a bare scene, no mouse input needed.
extends GdUnitTestSuite

const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const SLEEPWALKER_SCENE := preload("res://scenes/enemies/sleepwalker.tscn")

const MAX_FRAMES_TO_WAIT := 120


func test_cup_wakes_sleepwalker() -> void:
	var sleepwalker: Sleepwalker = SLEEPWALKER_SCENE.instantiate()
	sleepwalker.position = Vector2(400, 200)
	sleepwalker.walk_speed = 0.0
	add_child(auto_free(sleepwalker))

	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(100, 200)
	cup.direction = Vector2.RIGHT
	add_child(auto_free(cup))

	var frames := 0
	while sleepwalker.state != Sleepwalker.State.AWAKE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(sleepwalker.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
