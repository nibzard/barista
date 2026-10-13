# ABOUTME: Recipe is a fixed brew combination: bean + roast + method + extra.
# ABOUTME: The V1 recipes copy section 15 of GAME_DESIGN.md into .tres files.
class_name Recipe
extends Resource

enum Match {
	ANY,
	EXACT,
	QUALITY_MIN,
}

@export var recipe_id: String
@export var display_name: String
@export var method_match: Match
@export var method_id: String
@export var extra_id: String
@export var bean_match: Match
@export var bean_id: String
@export var min_bean_quality: BeanType.Quality
@export var roast_match: Match
@export var roast: RoastProfile.Kind
@export var required_appliance: String


func matches(
	bean: BeanType, roast_profile: RoastProfile, method: BrewingMethod, used_extra_id: String
) -> bool:
	if method_match == Match.EXACT and method.method_id != method_id:
		return false
	if used_extra_id != extra_id:
		return false
	if not _bean_matches(bean):
		return false
	if roast_match == Match.EXACT and roast_profile.kind != roast:
		return false
	return true


func _bean_matches(bean: BeanType) -> bool:
	if bean_match == Match.ANY:
		return true
	if bean_match == Match.EXACT:
		return bean.bean_id == bean_id
	return bean.quality >= min_bean_quality
