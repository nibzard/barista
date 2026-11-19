# ABOUTME: Integration tests for the Moonwalker clue trail, section 24: the
# ABOUTME: busker of the San Coffesco park, the glove in the grass, and the
# ABOUTME: Elvis fans of Steamtle with their no-sightings report.
extends GdUnitTestSuite

const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const GLOVE := preload("res://resources/items/gear/sequined_glove.tres")

const BUSKER_LINE := "The gloved one? He dances where the speakers die."
const FANS_LINE := "The smooth one? The fan club stays open. No sightings. None."
const SETTLE_FRAMES := 6


func test_san_coffesco_builds_the_busker_at_the_park() -> void:
	var city := SAN_COFFESCO_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await _settle()
	var mystery := (
		city.get_tree().get_first_node_in_group(&"moonwalker_mystery") as MoonwalkerMystery
	)
	assert_object(mystery).is_not_null()
	var npcs := mystery.hint_npcs()
	assert_int(npcs.size()).is_equal(1)
	var busker := npcs[0]
	assert_str(busker.hint.speaker_name).is_equal("THE BUSKER")
	var park := city.city_map().find_quest_site("The Fog Park")
	assert_vector(busker.global_position).is_equal(park.quest_site_marker().global_position)


func test_the_busker_speaks_his_clue_on_the_walk_up() -> void:
	var city := SAN_COFFESCO_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await _settle()
	var busker := _hint_npc(city)
	assert_bool(busker.is_speaking()).is_false()
	city.player.global_position = busker.global_position
	await _settle()
	assert_bool(busker.is_speaking()).is_true()
	assert_str(busker.spoken_line()).is_equal(BUSKER_LINE)


func test_the_park_grass_holds_the_sequined_glove() -> void:
	var city := SAN_COFFESCO_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await _settle()
	var park := city.city_map().find_quest_site("The Fog Park")
	assert_object(park).is_not_null()
	var find_point := park.find_point()
	assert_object(find_point).is_not_null()
	assert_int(find_point.remaining_amount(GLOVE)).is_equal(1)


func test_steamtle_builds_the_fans_at_their_club() -> void:
	var city := STEAMTLE_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await _settle()
	var mystery := (
		city.get_tree().get_first_node_in_group(&"moonwalker_mystery") as MoonwalkerMystery
	)
	var npcs := mystery.hint_npcs()
	assert_int(npcs.size()).is_equal(1)
	var fans := npcs[0]
	assert_str(fans.hint.speaker_name).is_equal("THE ELVIS FANS")
	city.player.global_position = fans.global_position
	await _settle()
	assert_str(fans.spoken_line()).is_equal(FANS_LINE)


func _hint_npc(city: CityRun) -> MysteryHintNpc:
	var mystery := (
		city.get_tree().get_first_node_in_group(&"moonwalker_mystery") as MoonwalkerMystery
	)
	return mystery.hint_npcs()[0]


func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES):
		await get_tree().physics_frame
