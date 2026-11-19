# ABOUTME: Pins the Moonwalker mystery data, section 24: the enemy, the dex
# ABOUTME: entry, the cure, and the clue trail across the three cities.
extends GdUnitTestSuite

const CITY_BALANCE := preload("res://resources/balance/city.tres")
const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")
const ENEMY := preload("res://resources/enemies/moonwalker.tres")
const DEX_ENTRY := preload("res://resources/dex/entries/moonwalker.tres")
const CURE := preload("res://resources/brewing/cures/moonwalker.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const GLOVE := preload("res://resources/items/gear/sequined_glove.tres")
const BUSKER := preload("res://resources/quests/mystery/park_busker.tres")
const ELVIS_FANS := preload("res://resources/quests/mystery/elvis_fans.tres")

const PARK_SITE := "The Fog Park"
const FAN_SITE := "The Fan Club"
const BUSKER_LINE := "The gloved one? He dances where the speakers die."
const FANS_LINE := "The smooth one? The fan club stays open. No sightings. None."


func test_the_enemy_type_pins_the_moonwalk_behavior_and_the_hee_hee() -> void:
	assert_str(ENEMY.type_id).is_equal("moonwalker")
	assert_int(ENEMY.special_behavior).is_equal(EnemyType.SpecialBehavior.MOONWALK)
	assert_str(ENEMY.wake_line).is_equal("Hee-hee!")


func test_the_cure_is_one_ristretto() -> void:
	assert_str(CURE.cure_recipe_id).is_equal("ristretto")
	assert_bool(CURE.is_basic).is_false()
	assert_object(LIBRARY.find_recipe("ristretto")).is_not_null()


func test_the_dex_entry_stays_rare_and_reads_smooth() -> void:
	assert_bool(DEX_ENTRY.is_rare()).is_true()
	assert_str(DEX_ENTRY.type_id()).is_equal("moonwalker")
	assert_str(DEX_ENTRY.status_line(true)).is_equal("Status: smooth")
	# The plain rows keep the default: the override never leaks into the
	# not-found text or into entries without their own line.
	assert_str(DEX_ENTRY.status_line(false)).is_empty()


func test_san_coffesco_holds_the_park_the_glove_and_the_busker() -> void:
	var park := SAN_COFFESCO.blocks[2]
	assert_int(park.kind).is_equal(CityBlock.Kind.QUEST_SITE)
	assert_str(park.site_name).is_equal(PARK_SITE)
	assert_int(park.finds.size()).is_equal(1)
	assert_str(park.finds[0].item.item_id).is_equal(GLOVE.item_id)
	assert_int(SAN_COFFESCO.mystery_hints.size()).is_equal(1)
	assert_str(SAN_COFFESCO.mystery_hints[0].line).is_equal(BUSKER_LINE)
	assert_str(SAN_COFFESCO.mystery_hints[0].site_name).is_equal(PARK_SITE)
	assert_bool(SAN_COFFESCO.moonwalker_haunts).is_false()


func test_steamtle_holds_the_fans_with_no_sightings() -> void:
	assert_int(STEAMTLE.mystery_hints.size()).is_equal(1)
	assert_str(STEAMTLE.mystery_hints[0].line).is_equal(FANS_LINE)
	assert_str(STEAMTLE.mystery_hints[0].site_name).is_equal(FAN_SITE)
	var has_club := false
	for block: CityBlock in STEAMTLE.blocks:
		has_club = has_club or block.site_name == FAN_SITE
	assert_bool(has_club).is_true()
	assert_bool(STEAMTLE.moonwalker_haunts).is_false()


func test_only_pourtland_haunts() -> void:
	assert_bool(POURTLAND.moonwalker_haunts).is_true()
	assert_bool(POURTLAND.mystery_hints.is_empty()).is_true()


func test_the_edited_cities_still_pass_the_section_17_rules() -> void:
	for city: CityDefinition in [SAN_COFFESCO, STEAMTLE, POURTLAND]:
		var violations := CityRules.validate(city, CITY_BALANCE)
		(
			assert_int(violations.size())
			. override_failure_message("%s: %s" % [city.city_id, str(violations)])
			. is_equal(0)
		)


func test_the_hint_speakers_carry_their_data() -> void:
	assert_str(BUSKER.speaker_name).is_equal("THE BUSKER")
	assert_str(ELVIS_FANS.speaker_name).is_equal("THE ELVIS FANS")
