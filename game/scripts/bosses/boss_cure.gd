# ABOUTME: BossCure is the shared cure rule of the boss fights, section 15.
# ABOUTME: The tiers lead: a perfect cup wakes any boss, a weak cup wakes none.
class_name BossCure
extends RefCounted


static func accepted(cup: BrewedCup, cure: Recipe, brew_balance: BrewingBalance) -> bool:
	# The section 15 tiers lead every boss cure: a perfect cup wakes every
	# type, a weak cup wakes none. Between the tiers, only the cure recipe
	# itself reaches the boss.
	if cup == null or cure == null:
		return false
	var cup_quality := cup.tier(brew_balance)
	if cup_quality == CupTier.Tier.PERFECT:
		return true
	if cup_quality == CupTier.Tier.WEAK:
		return false
	return cure.matches(cup.bean, cup.roast, cup.method, cup.extra_id)
