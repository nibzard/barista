# ABOUTME: Unit tests for Inventory add, remove, and stack limits, GAME_DESIGN section 15.
# ABOUTME: Pure logic tests, no scene tree. Also pins the V1 item data set.
extends GdUnitTestSuite

const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")
const GOLDEN_COAST_ARABICA := preload("res://resources/items/beans/golden_coast_arabica.tres")
const MOSS_HOLLOW_ORGANIC := preload("res://resources/items/beans/moss_hollow_organic.tres")
const GEISHA_VAULT := preload("res://resources/items/beans/geisha_vault.tres")
const FUSE := preload("res://resources/items/materials/fuse.tres")
const SCRAP_PART := preload("res://resources/items/materials/scrap_part.tres")
const THERMOS_BELT := preload("res://resources/items/gear/thermos_belt.tres")
const DESIGNER_DRIPPER := preload("res://resources/items/gear/designer_dripper.tres")
const SEQUINED_GLOVE := preload("res://resources/items/gear/sequined_glove.tres")
const BLENDER := preload("res://resources/items/appliances/blender.tres")
const TURKISH_POT := preload("res://resources/items/appliances/turkish_pot.tres")

const BREWING_LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const ALL_ITEMS: Array[ItemType] = [
	HOUSE_BEANS,
	GOLDEN_COAST_ARABICA,
	MOSS_HOLLOW_ORGANIC,
	GEISHA_VAULT,
	FUSE,
	SCRAP_PART,
	THERMOS_BELT,
	DESIGNER_DRIPPER,
	SEQUINED_GLOVE,
	BLENDER,
	TURKISH_POT,
]

const BEAN_ITEMS: Array[ItemType] = [
	HOUSE_BEANS,
	GOLDEN_COAST_ARABICA,
	MOSS_HOLLOW_ORGANIC,
	GEISHA_VAULT,
]

const UNIQUE_ITEMS: Array[ItemType] = [
	THERMOS_BELT,
	DESIGNER_DRIPPER,
	SEQUINED_GLOVE,
	BLENDER,
	TURKISH_POT,
]

var _inventory: Inventory


func before_test() -> void:
	_inventory = Inventory.new()


func test_add_counts_the_units_added() -> void:
	assert_int(_inventory.add(SCRAP_PART, 4)).is_equal(4)
	assert_int(_inventory.count("scrap_part")).is_equal(4)
	assert_bool(_inventory.has_item("scrap_part")).is_true()


func test_add_stacks_up_to_the_item_limit() -> void:
	assert_int(_inventory.add(HOUSE_BEANS, 90)).is_equal(90)
	assert_int(_inventory.add(HOUSE_BEANS, 20)).is_equal(9)
	assert_int(_inventory.count("house")).is_equal(99)
	assert_int(_inventory.add(HOUSE_BEANS, 1)).is_equal(0)


func test_add_ignores_non_positive_amounts() -> void:
	assert_int(_inventory.add(FUSE, 0)).is_equal(0)
	assert_int(_inventory.add(FUSE, -2)).is_equal(0)
	assert_int(_inventory.count("fuse")).is_equal(0)


func test_unique_gear_never_stacks() -> void:
	for item: ItemType in UNIQUE_ITEMS:
		assert_int(_inventory.add(item, 1)).is_equal(1)
		assert_int(_inventory.add(item, 1)).is_equal(0)
		assert_int(_inventory.count(item.item_id)).is_equal(1)


func test_stacks_stay_separate_per_item() -> void:
	_inventory.add(FUSE, 2)
	_inventory.add(SCRAP_PART, 5)
	_inventory.add(HOUSE_BEANS, 7)
	assert_int(_inventory.count("fuse")).is_equal(2)
	assert_int(_inventory.count("scrap_part")).is_equal(5)
	assert_int(_inventory.count("house")).is_equal(7)
	assert_bool(_inventory.has_item("golden_coast_arabica")).is_false()


func test_remove_spends_units_from_the_stack() -> void:
	_inventory.add(SCRAP_PART, 5)
	assert_bool(_inventory.remove("scrap_part", 3)).is_true()
	assert_int(_inventory.count("scrap_part")).is_equal(2)
	assert_bool(_inventory.remove("scrap_part", 2)).is_true()
	assert_int(_inventory.count("scrap_part")).is_equal(0)
	assert_bool(_inventory.has_item("scrap_part")).is_false()


func test_remove_fails_when_the_stack_is_short() -> void:
	_inventory.add(FUSE, 1)
	assert_bool(_inventory.remove("fuse", 2)).is_false()
	assert_int(_inventory.count("fuse")).is_equal(1)
	assert_bool(_inventory.remove("geisha_vault", 1)).is_false()


func test_remove_rejects_non_positive_amounts() -> void:
	_inventory.add(FUSE, 1)
	assert_bool(_inventory.remove("fuse", 0)).is_false()
	assert_bool(_inventory.remove("fuse", -1)).is_false()
	assert_int(_inventory.count("fuse")).is_equal(1)


func test_v1_gear_and_material_data() -> void:
	assert_str(FUSE.item_id).is_equal("fuse")
	assert_str(FUSE.display_name).is_equal("Fuse")
	assert_int(FUSE.category).is_equal(ItemType.Category.MATERIAL)
	assert_int(FUSE.max_stack).is_equal(9)
	assert_str(SCRAP_PART.item_id).is_equal("scrap_part")
	assert_int(SCRAP_PART.category).is_equal(ItemType.Category.MATERIAL)
	assert_int(SCRAP_PART.max_stack).is_equal(99)
	assert_str(THERMOS_BELT.item_id).is_equal("thermos_belt")
	assert_int(THERMOS_BELT.category).is_equal(ItemType.Category.GEAR)
	assert_str(DESIGNER_DRIPPER.item_id).is_equal("designer_dripper")
	assert_int(DESIGNER_DRIPPER.category).is_equal(ItemType.Category.GEAR)
	assert_str(SEQUINED_GLOVE.item_id).is_equal("sequined_glove")
	assert_int(SEQUINED_GLOVE.category).is_equal(ItemType.Category.GEAR)


func test_v1_appliances_match_the_recipe_appliance_ids() -> void:
	# The recipes gate the Frappuccino behind "blender" and the Turkish cup
	# behind "turkish_pot"; the appliance items carry the same ids.
	assert_str(BLENDER.item_id).is_equal("blender")
	assert_int(BLENDER.category).is_equal(ItemType.Category.APPLIANCE)
	assert_str(TURKISH_POT.item_id).is_equal("turkish_pot")
	assert_int(TURKISH_POT.category).is_equal(ItemType.Category.APPLIANCE)
	var frappuccino := BREWING_LIBRARY.find_recipe("frappuccino")
	assert_str(frappuccino.required_appliance).is_equal(BLENDER.item_id)
	var turkish_cup := BREWING_LIBRARY.find_recipe("turkish_cup")
	assert_str(turkish_cup.required_appliance).is_equal(TURKISH_POT.item_id)


func test_every_brewing_bean_has_one_bean_item_with_the_same_id() -> void:
	# Brewing spends beans by bean id, so the bean item ids must match.
	for bean: BeanType in BREWING_LIBRARY.beans:
		var matches := 0
		for item: ItemType in BEAN_ITEMS:
			if item.category == ItemType.Category.BEAN and item.item_id == bean.bean_id:
				matches += 1
				assert_bool(item.bean == bean).is_true()
		assert_int(matches).is_equal(1)


func test_bean_items_stack_high() -> void:
	for item: ItemType in BEAN_ITEMS:
		assert_int(item.max_stack).is_equal(99)
		assert_int(item.category).is_equal(ItemType.Category.BEAN)


func test_every_item_has_an_id_and_a_name() -> void:
	for item: ItemType in ALL_ITEMS:
		assert_str(item.item_id).is_not_empty()
		assert_str(item.display_name).is_not_empty()
