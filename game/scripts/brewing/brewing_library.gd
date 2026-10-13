# ABOUTME: BrewingLibrary wires every brewing .tres resource into one dataset.
# ABOUTME: It looks up methods, beans, roasts, extras, recipes, and cures by id.
class_name BrewingLibrary
extends Resource

@export var methods: Array[BrewingMethod] = []
@export var beans: Array[BeanType] = []
@export var roasts: Array[RoastProfile] = []
@export var extras: Array[RecipeExtra] = []
@export var recipes: Array[Recipe] = []
@export var cures: Array[SleepwalkerCure] = []


func find_method(method_id: String) -> BrewingMethod:
	for method: BrewingMethod in methods:
		if method.method_id == method_id:
			return method
	return null


func find_bean(bean_id: String) -> BeanType:
	for bean: BeanType in beans:
		if bean.bean_id == bean_id:
			return bean
	return null


func find_roast(roast_id: String) -> RoastProfile:
	for roast: RoastProfile in roasts:
		if roast.roast_id == roast_id:
			return roast
	return null


func find_extra(extra_id: String) -> RecipeExtra:
	for extra: RecipeExtra in extras:
		if extra.extra_id == extra_id:
			return extra
	return null


func find_recipe(recipe_id: String) -> Recipe:
	for recipe: Recipe in recipes:
		if recipe.recipe_id == recipe_id:
			return recipe
	return null


func find_cure(sleeper_type_id: String) -> SleepwalkerCure:
	for cure: SleepwalkerCure in cures:
		if cure.sleeper_type_id == sleeper_type_id:
			return cure
	return null


func find_matching_recipe(
	bean: BeanType, roast: RoastProfile, method: BrewingMethod, extra_id: String
) -> Recipe:
	for recipe: Recipe in recipes:
		if recipe.matches(bean, roast, method, extra_id):
			return recipe
	return null
