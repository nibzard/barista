# ABOUTME: BrewedCup is one finished cup: a bean, roast, method, extra, and score.
# ABOUTME: Pure value object; tier and recipe matching ask the balance and library.
class_name BrewedCup
extends RefCounted

var bean: BeanType
var roast: RoastProfile
var method: BrewingMethod
var extra_id: String
var score: float


func _init(
	p_bean: BeanType,
	p_roast: RoastProfile,
	p_method: BrewingMethod,
	p_extra_id: String,
	p_score: float
) -> void:
	bean = p_bean
	roast = p_roast
	method = p_method
	extra_id = p_extra_id
	score = p_score


func tier(balance: BrewingBalance) -> CupTier.Tier:
	return CupTier.from_score(score, balance)


func matched_recipe(library: BrewingLibrary) -> Recipe:
	return library.find_matching_recipe(bean, roast, method, extra_id)
