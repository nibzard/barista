# ABOUTME: CupTier turns a minigame score into a brewed-cup quality tier.
# ABOUTME: The thresholds come from BrewingBalance, so they stay tuning data.
class_name CupTier
extends RefCounted

enum Tier {
	WEAK,
	GOOD,
	PERFECT,
}


static func from_score(score: float, balance: BrewingBalance) -> Tier:
	if score >= balance.perfect_tier_min_score:
		return Tier.PERFECT
	if score >= balance.good_tier_min_score:
		return Tier.GOOD
	return Tier.WEAK
