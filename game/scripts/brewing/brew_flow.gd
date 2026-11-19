# ABOUTME: BrewFlow is the pure pipeline of one brew at the stand: the recipe
# ABOUTME: resolves, the bag pays the bean, the appliance gates, the cup grades.
class_name BrewFlow
extends RefCounted

# A recipe that pins no method brews as the cafe standard method, and a recipe
# that pins no roast takes the balanced medium roast, section 15.
const ANY_METHOD_DEFAULT_ID := "filter"
const ANY_ROAST_DEFAULT_KIND := RoastProfile.Kind.MEDIUM
# The stand keeps its own jar of the common bean, so an empty bag still brews.
const CAFE_STOCK_BEAN_ID := "house"
# The method score sits unset until a minigame or an auto-brew grades it.
const NO_SCORE := -1.0
# No roast choice reached the resolve call, so an open roast takes the default.
const NO_ROAST_CHOICE := -1
# Section 15 at the roast picker: the fact the game states, and the wake line
# that names the roasts strong enough for the sleeper the recipe cures.
const ROAST_FACT_TEXT := "LIGHT ROAST KEEPS MORE CAFFEINE."
const ROAST_WAKE_LABEL_TEXT := "%s - WAKE %d"
const WAKES_LINE_TEXT := "WAKES %s: %s ROAST."
const PERFECT_ONLY_LINE_TEXT := "WAKES %s ONLY FROM A PERFECT CUP."

var bean: BeanType
var roast: RoastProfile
var method: BrewingMethod
var extra_id: String

var _grind_factor := 1.0
var _method_score := NO_SCORE


static func resolve(
	recipe: Recipe,
	chosen_bean: BeanType,
	library: BrewingLibrary,
	chosen_roast_kind: int = NO_ROAST_CHOICE
) -> BrewFlow:
	# One recipe plus one bean makes one brew plan. The recipe pins what it
	# pins; an open roast takes the choice of the player, and the fields with
	# no choice take the cafe defaults.
	var flow := BrewFlow.new()
	flow.bean = chosen_bean
	flow.method = (
		library.find_method(recipe.method_id)
		if recipe.method_match == Recipe.Match.EXACT
		else library.find_method(ANY_METHOD_DEFAULT_ID)
	)
	var roast_kind: RoastProfile.Kind = recipe.roast
	if recipe.roast_match != Recipe.Match.EXACT:
		roast_kind = (
			chosen_roast_kind if chosen_roast_kind != NO_ROAST_CHOICE else ANY_ROAST_DEFAULT_KIND
		)
	flow.roast = library.find_roast_by_kind(roast_kind)
	flow.extra_id = recipe.extra_id
	return flow


static func compose_score(
	method_score: float, grind_factor: float, brew_method: BrewingMethod
) -> float:
	# The cup keeps the method score that the grind earned: a wrong grind
	# lowers the quality of the cup, section 8. The method ceiling caps the
	# top, so a low-ceiling method never grades above its tier.
	return clampf(method_score * grind_factor, 0.0, brew_method.score_ceiling)


static func held_beans(inventory: Inventory, library: BrewingLibrary) -> Array[BeanType]:
	# The beans in the bag, in library order.
	var held: Array[BeanType] = []
	if inventory == null:
		return held
	for bean: BeanType in library.beans:
		if inventory.has_item(bean.bean_id):
			held.append(bean)
	return held


static func bean_options(
	recipe: Recipe, inventory: Inventory, library: BrewingLibrary
) -> Array[BeanType]:
	# The beans this recipe accepts from this bag. An empty bag still brews
	# the cafe stock when the recipe accepts the house bean: the stand keeps
	# its own jar of the common bean. A recipe that needs a finer bean than
	# the bag holds offers nothing.
	var options: Array[BeanType] = []
	for bean: BeanType in held_beans(inventory, library):
		if _bean_allowed(recipe, bean):
			options.append(bean)
	if options.is_empty():
		var stock := library.find_bean(CAFE_STOCK_BEAN_ID)
		if _bean_allowed(recipe, stock):
			options.append(stock)
	return options


static func _bean_allowed(recipe: Recipe, bean: BeanType) -> bool:
	if bean == null:
		return false
	match recipe.bean_match:
		Recipe.Match.ANY:
			return true
		Recipe.Match.EXACT:
			return bean.bean_id == recipe.bean_id
		_:
			return bean.quality >= recipe.min_bean_quality


static func spend_bean(bean: BeanType, inventory: Inventory) -> bool:
	# One brew pays with one unit of the chosen bean out of the bag, section
	# 7: the player collects beans, then brews. The stand keeps its own jar
	# of the common bean, so a brew off that jar costs nothing.
	if bean == null:
		return false
	if inventory != null and inventory.has_item(bean.bean_id):
		return inventory.remove(bean.bean_id, 1)
	return bean.bean_id == CAFE_STOCK_BEAN_ID


static func appliance_owned(recipe: Recipe, inventory: Inventory) -> bool:
	# Section 15: the blender and the Turkish pot are cafe appliances. The
	# player scavenges them, so a recipe that names one brews only over an
	# appliance in the bag. A recipe that names none needs no appliance.
	if recipe == null or recipe.required_appliance.is_empty():
		return true
	return inventory != null and inventory.has_item(recipe.required_appliance)


static func roast_options(recipe: Recipe, library: BrewingLibrary) -> Array[RoastProfile]:
	# The roast choice of the stand, section 8: a recipe that pins no roast
	# lets the player pick any level, and a pinned recipe brews its roast
	# fixed, because a recipe is a fixed combination, section 15.
	if recipe == null or library == null:
		return []
	if recipe.roast_match == Recipe.Match.EXACT:
		return []
	return library.roasts.duplicate()


static func roast_button_label(roast: RoastProfile) -> String:
	# Every roast of the picker names its wake power, section 15: the roast
	# factor as a share of the light roast, so the choice point shows which
	# level wakes the strongest.
	if roast == null:
		return ""
	return (
		ROAST_WAKE_LABEL_TEXT
		% [roast.display_name.to_upper(), roundi(roast.wake_power_factor * 100.0)]
	)


static func wake_hint_text(recipe: Recipe, library: BrewingLibrary) -> String:
	# The teaching line of the roast picker, section 15: the fact that light
	# roast keeps more caffeine, plus one wake line per sleeper this recipe
	# cures. A recipe that pins its roast offers no choice, so it teaches
	# nothing here.
	if roast_options(recipe, library).is_empty():
		return ""
	var lines: Array[String] = [ROAST_FACT_TEXT]
	for cure: SleepwalkerCure in _cures_of(recipe, library):
		lines.append(_wakes_line(cure, library))
	return " ".join(PackedStringArray(lines))


static func _cures_of(recipe: Recipe, library: BrewingLibrary) -> Array[SleepwalkerCure]:
	# The special sleepers this recipe cures. Basic types wake from any cup,
	# so they need no roast lesson.
	var cures: Array[SleepwalkerCure] = []
	if recipe == null or library == null:
		return cures
	for cure: SleepwalkerCure in library.cures:
		if not cure.is_basic and cure.cure_recipe_id == recipe.recipe_id:
			cures.append(cure)
	return cures


static func _wakes_line(cure: SleepwalkerCure, library: BrewingLibrary) -> String:
	# The roasts that can wake this sleeper from a good cup, read from the
	# same matcher rule that gates the wake itself. A sleeper stronger than
	# every roast wakes only from a perfect cup.
	var roast_ids := CureMatcher.roast_ids_with_enough_power(cure, library)
	if roast_ids.is_empty():
		return PERFECT_ONLY_LINE_TEXT % cure.display_name.to_upper()
	var roast_names := " OR ".join(PackedStringArray(roast_ids)).to_upper()
	return WAKES_LINE_TEXT % [cure.display_name.to_upper(), roast_names]


func apply_grind(dial_result: GrindResult) -> void:
	# The pre-step answer: how much cup quality the grind keeps.
	if dial_result != null:
		_grind_factor = dial_result.quality_factor


func apply_method_score(score: float) -> void:
	_method_score = maxf(score, 0.0)


func apply_auto_brew(balance: BrewingBalance) -> void:
	# Auto-brew skips the minigames: the machine grinds right and always
	# scores the auto-brew score, never a perfect cup, section 14.
	_grind_factor = 1.0
	_method_score = balance.auto_brew_score if balance != null else 0.0


func apply_cold_brew(cold_result: ColdBrewResult) -> void:
	# The steep grades itself: no grind, no minigame, the frozen timer score
	# with the method ceiling above it, section 8.
	_grind_factor = 1.0
	_method_score = cold_result.score if cold_result != null else NO_SCORE


func needs_method_minigame() -> bool:
	return method != null and method.minigame_group != BrewingMethod.MinigameGroup.NONE


func is_graded() -> bool:
	return _method_score >= 0.0


func cup() -> BrewedCup:
	# The finished cup, or nothing while a step still runs.
	if not is_graded() or bean == null or roast == null or method == null:
		return null
	return BrewedCup.new(bean, roast, method, extra_id, cup_score())


func cup_score() -> float:
	return compose_score(_method_score, _grind_factor, method)
