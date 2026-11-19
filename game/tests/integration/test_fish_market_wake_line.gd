# ABOUTME: Integration test pinning the fish market wake line of T129.
# ABOUTME: Proves the market cheer floats from the boss's WakeLine node.
extends GdUnitTestSuite

const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

var _city: CityRun
var _boss: FishThrowers


func before_test() -> void:
	# A live Steamtle run: the market boss rides the arena with the same wake
	# line wiring as the band stage of Pourtland, so the cheer plays in play.
	_city = STEAMTLE_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_boss = _city.boss() as FishThrowers


func test_the_market_wake_line_plays_above_the_market() -> void:
	# The pin of T129: the presenter attach of the fish market had no direct
	# assertion, only the spoke connect of the fight suite. One tall cup of the
	# market dark roast into the apron of the head fishmonger floats the cheer
	# line above the market, while the HUD toast keeps the wake announcement,
	# mirroring the band case.
	assert_object(_boss).is_not_null()
	var presenter := _boss.get_node(^"WakeLine") as WakeLinePresenter
	var market_cure := _brew("golden_coast_arabica", "dark", "filter", "tall_size", 85.0)
	assert_bool(presenter.is_speaking()).is_false()
	assert_bool(_boss.head().try_wake(market_cure)).is_true()
	assert_bool(presenter.is_speaking()).is_true()
	assert_str(presenter.spoken_line()).is_equal(_boss.balance.cheer_line)
	assert_str(_city.hud.toast_message()).is_equal(FishThrowers.WAKE_TOAST)


func _brew(
	bean_id: String, roast_id: String, method_id: String, extra_id: String, score: float
) -> BrewedCup:
	# The cup factory of the brewing library, shared by every city suite.
	return BrewedCup.new(
		LIBRARY.find_bean(bean_id),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		extra_id,
		score
	)
