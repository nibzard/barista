# ABOUTME: CureMatcher holds the rules for which brewed cup wakes which sleeper.
# ABOUTME: Weak wakes basic types only, good wakes matching types, perfect wakes all.
class_name CureMatcher
extends RefCounted


static func can_wake(
	cup: BrewedCup, cure: SleepwalkerCure, library: BrewingLibrary, balance: BrewingBalance
) -> bool:
	if cure.is_basic:
		return true
	var cup_quality := cup.tier(balance)
	if cup_quality == CupTier.Tier.PERFECT:
		return true
	if cup_quality == CupTier.Tier.WEAK:
		return false
	var recipe := cup.matched_recipe(library)
	return recipe != null and recipe.recipe_id == cure.cure_recipe_id


static func wake_radius(cup: BrewedCup, balance: BrewingBalance) -> float:
	if cup.tier(balance) == CupTier.Tier.PERFECT:
		return balance.perfect_wake_radius
	return 0.0
