# ABOUTME: Integration tests for the wake-line presenter of T092.
# ABOUTME: Proves a live city run floats the wake line of a woken sleeper.
extends GdUnitTestSuite

const CITY_RUN_SCENE := preload("res://scenes/city/city_run.tscn")
const POURTLAND_DEFINITION := preload("res://resources/city/pourtland.tres")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const KAREN_TYPE := preload("res://resources/enemies/karen.tres")
const KAREN_SCENE := preload("res://scenes/enemies/karen.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

# Section 6: the Karen asks for the manager when she wakes.
const KAREN_LINE := "Manager! I want to see the manager!"
# The hold of a wake line in physics ticks, 4 seconds at 60 ticks per second.
const HOLD_TICKS := 240

var _city: CityRun


func before_test() -> void:
	# A live city run whose street roster holds the Karen. She stays outro-only
	# in the authored cities, section 16, so the test roster swaps her in and
	# the wake of a special type plays through the real crowd wiring.
	var definition := POURTLAND_DEFINITION.duplicate(true) as CityDefinition
	var karen_entry := EnemySpawn.new()
	karen_entry.enemy_type = KAREN_TYPE
	karen_entry.scene = KAREN_SCENE
	var roster: Array[EnemySpawn] = [karen_entry]
	definition.roster = roster
	_city = CITY_RUN_SCENE.instantiate() as CityRun
	_city.definition = definition
	_city.balance = CITY_BALANCE
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_waking_a_special_type_shows_its_wake_line() -> void:
	# The acceptance of T092: waking a special type shows its wake line. The
	# cure lands, the spoke signal fires, and the presenter floats the manager
	# line above her body.
	var karen := _city.crowd_enemy(0)
	var presenter := karen.get_node(^"WakeLine") as WakeLinePresenter
	assert_bool(presenter.is_speaking()).is_false()
	assert_bool(karen.try_wake(_super_tall())).is_true()
	assert_bool(presenter.is_speaking()).is_true()
	assert_str(presenter.spoken_line()).is_equal(KAREN_LINE)


func test_a_refused_cup_shows_no_line() -> void:
	# A wrong cup wakes nobody, so no line plays: the presenter answers the
	# spoke signal, and the signal fires only on a real wake.
	var karen := _city.crowd_enemy(0)
	var standard_cup := _brew("house", "medium", "filter", "", 85.0)
	assert_bool(karen.try_wake(standard_cup)).is_false()
	var presenter := karen.get_node(^"WakeLine") as WakeLinePresenter
	assert_bool(presenter.is_speaking()).is_false()
	assert_str(presenter.spoken_line()).is_equal("")


func test_every_crowd_sleeper_carries_a_presenter() -> void:
	# The wiring of the run: every spawned sleeper answers its spoke signal,
	# and nothing shows before a wake.
	for i: int in range(_city.crowd_count()):
		var enemy := _city.crowd_enemy(i)
		var presenter := enemy.get_node_or_null(^"WakeLine") as WakeLinePresenter
		assert_object(presenter).override_failure_message(str(i)).is_not_null()
		assert_bool(presenter.is_speaking()).is_false()
		assert_str(presenter.spoken_line()).is_equal("")


func test_the_band_wake_line_plays_above_the_stage() -> void:
	# The second finding of T092: SleepJamBand.spoke had no live consumer, and
	# the band toast came from a separate constant. The wake line now floats
	# above the stage while the chalkboard keeps the song-over toast.
	var band := _city.boss() as SleepJamBand
	assert_object(band).is_not_null()
	var presenter := band.get_node(^"WakeLine") as WakeLinePresenter
	var geisha_cup := _brew("geisha_vault", "medium", "filter", "", 85.0)
	assert_bool(band.try_wake(geisha_cup)).is_true()
	assert_bool(presenter.is_speaking()).is_true()
	assert_str(presenter.spoken_line()).is_equal(band.balance.wake_line)
	assert_str(_city.hud.toast_message()).is_equal(SleepJamBand.WAKE_TOAST)


func test_the_line_holds_its_beat_then_fades() -> void:
	# The wake line holds above the woken sleeper for the beat, then it fades.
	# Every other sleeper wakes first, so no hug disturbs the long wait.
	for i: int in range(_city.crowd_count() - 1):
		_city.crowd_enemy(i).wake_up()
	var sleeper := _city.crowd_enemy(_city.crowd_count() - 1)
	assert_bool(sleeper.try_wake(_super_tall())).is_true()
	var presenter := sleeper.get_node(^"WakeLine") as WakeLinePresenter
	for _tick: int in range(HOLD_TICKS - 30):
		await get_tree().physics_frame
	assert_bool(presenter.is_speaking()).is_true()
	for _tick: int in range(60):
		await get_tree().physics_frame
	assert_bool(presenter.is_speaking()).is_false()
	assert_str(presenter.spoken_line()).is_equal(KAREN_LINE)


func test_an_empty_line_never_shows() -> void:
	# Types without a wake line stay silent: an empty speak is a no-op.
	var presenter := WakeLinePresenter.new()
	add_child(auto_free(presenter))
	presenter.speak("")
	assert_bool(presenter.is_speaking()).is_false()
	assert_str(presenter.spoken_line()).is_equal("")


func _super_tall() -> BrewedCup:
	# The cure of the Karen, section 15: the super tall American.
	return _brew("house", "medium", "filter", "tall_size", 85.0)


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
