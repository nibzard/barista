# ABOUTME: Integration tests for The Tinfoil Man: the hat stops thrown coffee.
# ABOUTME: Owns his cure rules and behavior; the shared wake suites stay lean.
extends GdUnitTestSuite

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const TINFOIL_MAN_SCENE := preload("res://scenes/enemies/tinfoil_man.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const MAX_FRAMES_TO_WAIT := 600
# The pair spawns out of sense range (150) but inside throw range (500).
const PLAYER_START_OFFSET := Vector2(200, 0)

var _tinfoil_man: Sleepwalker
var _player: Player
var _met_types: Array[String] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counters
	# reset here, not in the member declarations.
	_met_types.clear()
	_tinfoil_man = TINFOIL_MAN_SCENE.instantiate() as Sleepwalker
	# Freeze the wander so the aim stays honest; the chase stays live.
	var calm := _tinfoil_man.balance.duplicate() as SleepwalkerBalance
	calm.walk_speed = 0.0
	_tinfoil_man.balance = calm
	_tinfoil_man.position = Vector2(400, 200)
	add_child(auto_free(_tinfoil_man))
	_tinfoil_man.first_met.connect(func(type_id: String) -> void: _met_types.append(type_id))

	_player = PLAYER_SCENE.instantiate() as Player
	_player.cup_scene = CUP_SCENE
	_player.position = _tinfoil_man.position + PLAYER_START_OFFSET
	add_child(auto_free(_player))
	await get_tree().physics_frame


func test_standard_cup_does_not_wake_the_tinfoil_man() -> void:
	var standard_cup := _brew("house", "medium", "filter", "", 85.0)
	assert_bool(_tinfoil_man.try_wake(standard_cup)).is_false()
	assert_int(_tinfoil_man.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_the_turkish_recipe_wakes_him_when_served() -> void:
	# The acceptance case for the cure: Turkish coffee wakes him when the
	# serve hands the cup past the hat. A second serve changes nothing.
	var turkish := _brew("house", "medium", "turkish", "", 85.0)
	assert_bool(_tinfoil_man.try_wake(turkish)).is_true()
	assert_int(_tinfoil_man.state).is_equal(Sleepwalker.State.AWAKE)
	assert_bool(_tinfoil_man.try_wake(turkish)).is_false()

	for _frame: int in range(120):
		await get_tree().physics_frame
		assert_vector(_tinfoil_man.velocity).is_equal(Vector2.ZERO)
	assert_int(_tinfoil_man.state).is_equal(Sleepwalker.State.AWAKE)


func test_perfect_cup_served_directly_wakes_the_tinfoil_man() -> void:
	# The hat blocks the throw, not the cure: a served cup runs the normal
	# CureMatcher rule, so the perfect tier wakes him like any type.
	var perfect_plain := _brew("house", "medium", "filter", "", 99.0)
	assert_bool(_tinfoil_man.try_wake(perfect_plain)).is_true()
	assert_int(_tinfoil_man.state).is_equal(Sleepwalker.State.AWAKE)


func test_a_thrown_turkish_cup_hits_the_hat_without_waking() -> void:
	# The acceptance case for the hat: a direct cup hit does not wake him.
	# The payload is his own cure, so only the hat can explain the block.
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(100, 200)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew("house", "medium", "turkish", "", 85.0)
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(_tinfoil_man.state).is_not_equal(Sleepwalker.State.AWAKE)
	# The cup died on his body mid-flight, well before the full 60-frame
	# throw range: the hat stopped the coffee and spent the cup.
	assert_bool(is_instance_valid(cup)).is_false()
	assert_int(frames).is_less(50)


func test_a_thrown_perfect_cup_hits_the_hat_without_waking() -> void:
	# The perfect tier wakes every type on a serve. The hat stops the throw
	# itself, so even a perfect cup bounces off while it flies.
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(100, 200)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew("house", "medium", "filter", "", 99.0)
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(_tinfoil_man.state).is_not_equal(Sleepwalker.State.AWAKE)
	assert_bool(is_instance_valid(cup)).is_false()
	assert_int(frames).is_less(50)


func test_the_player_throw_spends_a_cup_on_the_hat() -> void:
	# The player throws the cafe-standard cup straight at him. The aim cone
	# snaps the landing onto his body, the flight ends on the hat, and the
	# cup leaves the supply without a wake.
	var cups_before := _player.coffee_supply.cups
	var cup := _player.throw_cup(_tinfoil_man.global_position - _player.global_position)
	assert_object(cup).is_not_null()
	assert_vector(cup.landing).is_equal(_tinfoil_man.global_position)
	assert_int(_player.coffee_supply.cups).is_equal(cups_before - 1)

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(cup)).is_false()

	for _tail: int in range(30):
		await get_tree().physics_frame
	assert_int(_tinfoil_man.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_only_the_tinfoil_man_hat_stops_thrown_coffee() -> void:
	# The guard is his alone: every other type takes the thrown hit through
	# the plain cure rules.
	assert_bool(_tinfoil_man.hat_stops_thrown_coffee()).is_true()
	var neighbor := NEIGHBOR_SCENE.instantiate() as Sleepwalker
	add_child(auto_free(neighbor))
	assert_bool(neighbor.hat_stops_thrown_coffee()).is_false()


func test_the_tinfoil_man_chases_and_hugs_like_the_neighbor() -> void:
	# His defense is the hat; his attack stays the plain sleepwalker hug, so
	# the grab and the mash-break work as they do for the Neighbor.
	_player.global_position = _tinfoil_man.global_position + Vector2(0, 120)
	var frames := 0
	while not _player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_player.is_grabbed()).is_true()
	assert_int(_tinfoil_man.state).is_equal(Sleepwalker.State.HUG)

	for _press: int in range(5):
		_player.struggle()
	await get_tree().physics_frame
	assert_bool(_player.is_grabbed()).is_false()
	assert_int(_tinfoil_man.state).is_equal(Sleepwalker.State.CHASE)


func test_tinfoil_man_emits_first_met_for_the_sleepydex() -> void:
	_player.global_position = _tinfoil_man.global_position + Vector2(0, 120)
	var frames := 0
	while _met_types.is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(_met_types.size()).is_equal(1)
	assert_str(_met_types[0]).is_equal("tinfoil_man")
	for _frame: int in range(30):
		await get_tree().physics_frame
	assert_int(_met_types.size()).is_equal(1)


func _brew(
	bean_id: String, roast_id: String, method_id: String, extra_id: String, score: float
) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean(bean_id),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		extra_id,
		score
	)
