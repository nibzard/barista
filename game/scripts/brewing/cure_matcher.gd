# ABOUTME: CureMatcher holds the rules for which brewed cup wakes which sleeper.
# ABOUTME: Tiers and recipes decide the match; the roast sets the wake power.
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
	if wake_power(cup) < cure.wake_resistance:
		# Section 15: the roast sets the wake power. A good cup below the
		# strength of the sleeper cannot wake it, even with the right recipe.
		return false
	var recipe := cup.matched_recipe(library)
	return recipe != null and recipe.recipe_id == cure.cure_recipe_id


static func wake_power(cup: BrewedCup) -> float:
	# Section 15: the roast sets the wake power of the cup. Light roast keeps
	# the most caffeine, so it carries the full factor. A cup without a roast
	# carries none.
	if cup == null or cup.roast == null:
		return 0.0
	return cup.roast.wake_power_factor


static func roast_ids_with_enough_power(
	cure: SleepwalkerCure, library: BrewingLibrary
) -> Array[String]:
	# The roasts that can wake this sleeper: every roast whose wake power
	# meets the strength of the cure.
	var ids: Array[String] = []
	if library == null:
		return ids
	for roast: RoastProfile in library.roasts:
		if roast.wake_power_factor >= cure.wake_resistance:
			ids.append(roast.roast_id)
	return ids


static func wake_radius(cup: BrewedCup, balance: BrewingBalance) -> float:
	# A perfect cup splashes, and the roast scales how far the coffee
	# reaches: the light roast carries the full radius.
	if cup.tier(balance) == CupTier.Tier.PERFECT:
		return balance.perfect_wake_radius * wake_power(cup)
	return 0.0
