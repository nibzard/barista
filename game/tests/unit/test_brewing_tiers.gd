# ABOUTME: Unit tests for cup-tier calculation from the minigame score.
# ABOUTME: Pins the section 15 thresholds: 80 for good, 95 for perfect.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/brewing/brewing_balance.tres")


func test_scores_below_80_are_weak() -> void:
	assert_int(CupTier.from_score(0.0, BALANCE)).is_equal(CupTier.Tier.WEAK)
	assert_int(CupTier.from_score(42.0, BALANCE)).is_equal(CupTier.Tier.WEAK)
	assert_int(CupTier.from_score(79.9, BALANCE)).is_equal(CupTier.Tier.WEAK)


func test_scores_from_80_are_good() -> void:
	assert_int(CupTier.from_score(80.0, BALANCE)).is_equal(CupTier.Tier.GOOD)
	assert_int(CupTier.from_score(88.0, BALANCE)).is_equal(CupTier.Tier.GOOD)
	assert_int(CupTier.from_score(94.9, BALANCE)).is_equal(CupTier.Tier.GOOD)


func test_scores_from_95_are_perfect() -> void:
	assert_int(CupTier.from_score(95.0, BALANCE)).is_equal(CupTier.Tier.PERFECT)
	assert_int(CupTier.from_score(100.0, BALANCE)).is_equal(CupTier.Tier.PERFECT)


func test_brewed_cup_reports_its_tier() -> void:
	var weak := _brew(72.0)
	assert_int(weak.tier(BALANCE)).is_equal(CupTier.Tier.WEAK)
	var good := _brew(81.0)
	assert_int(good.tier(BALANCE)).is_equal(CupTier.Tier.GOOD)
	var perfect := _brew(96.0)
	assert_int(perfect.tier(BALANCE)).is_equal(CupTier.Tier.PERFECT)


func _brew(score: float) -> BrewedCup:
	var bean := LIBRARY.find_bean("house")
	var roast := LIBRARY.find_roast("medium")
	var method := LIBRARY.find_method("filter")
	return BrewedCup.new(bean, roast, method, "", score)
