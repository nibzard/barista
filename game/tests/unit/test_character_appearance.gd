# ABOUTME: Unit tests for the cosmetic character creation state, task T046.
# ABOUTME: Section 5 options, the placeholder portrait, and the save round-trip.
extends GdUnitTestSuite

const CATALOG := preload("res://resources/player/appearance_catalog.tres")

const TEST_SAVE_ROOT := "user://test-character-appearance"


func before_test() -> void:
	_remove_dir(TEST_SAVE_ROOT)


func after_test() -> void:
	_remove_dir(TEST_SAVE_ROOT)


func _slot(case_name: String) -> String:
	return "%s/%s/slot.json" % [TEST_SAVE_ROOT, case_name]


func _remove_dir(path: String) -> void:
	# Godot 4.7 ships no recursive remove, so the suite walks the tree itself
	# and leaves no test slot behind on the device.
	var dir := DirAccess.open(path)
	if dir == null:
		return
	var entries: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			entries.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for name: String in entries:
		var child := path.path_join(name)
		if DirAccess.dir_exists_absolute(child):
			_remove_dir(child)
		else:
			DirAccess.remove_absolute(child)
	DirAccess.remove_absolute(path)


func _custom_appearance() -> CharacterAppearance:
	# Every field off its default, so one lost field fails the round-trip by
	# value: female body, deep tone, mohawk, wizard beard, three tattoos, and
	# the full steampunk outfit.
	var saved := {
		"body_type": CharacterAppearance.BODY_FEMALE,
		"skin_tone": "deep",
		"hair_style": "mohawk",
		"beard_length": CharacterAppearance.BEARD_WIZARD,
		"tattoos":
		[
			CharacterAppearance.TATTOO_LEFT_ARM,
			CharacterAppearance.TATTOO_NECK,
			CharacterAppearance.TATTOO_RIGHT_HAND,
		],
		"hat": "top_hat",
		"goggles": "welding",
		"apron": "leather",
		"boots": "steel",
	}
	return CharacterAppearance.from_dict(saved, CATALOG)


func _build_portrait(appearance: CharacterAppearance) -> Polygon2D:
	var body := Polygon2D.new()
	auto_free(body)
	BaristaPortrait.build(body, appearance, CATALOG)
	return body


func _assert_category_is_sound(category: Array[AppearanceOption]) -> void:
	# Every option carries a unique id and a label, so the save never stores
	# an ambiguous choice and the screen never shows a blank row.
	assert_bool(category.is_empty()).is_false()
	var seen_ids: Dictionary = {}
	for option: AppearanceOption in category:
		assert_str(option.option_id).is_not_empty()
		assert_str(option.display_name).is_not_empty()
		assert_bool(seen_ids.has(option.option_id)).is_false()
		seen_ids[option.option_id] = true


func _assert_color_is(actual: Color, expected: Color) -> void:
	# GdUnit ships no color assert, so the suite compares through the
	# engine's own tolerance check.
	assert_bool(actual.is_equal_approx(expected)).is_true()


func test_the_catalog_pins_the_section_5_option_lists() -> void:
	assert_array(AppearanceCatalog.ids(CATALOG.body_types)).is_equal(
		[CharacterAppearance.BODY_MALE, CharacterAppearance.BODY_FEMALE]
	)
	# The beard lengths of section 5, in order, open to every body type.
	(
		assert_array(AppearanceCatalog.ids(CATALOG.beard_lengths))
		. is_equal(
			[
				CharacterAppearance.BEARD_CLEAN,
				CharacterAppearance.BEARD_STUBBLE,
				CharacterAppearance.BEARD_HIPSTER,
				CharacterAppearance.BEARD_LUMBERJACK,
				CharacterAppearance.BEARD_WIZARD,
			]
		)
	)
	(
		assert_array(AppearanceCatalog.ids(CATALOG.tattoo_placements))
		. is_equal(
			[
				CharacterAppearance.TATTOO_LEFT_ARM,
				CharacterAppearance.TATTOO_RIGHT_ARM,
				CharacterAppearance.TATTOO_NECK,
				CharacterAppearance.TATTOO_LEFT_HAND,
				CharacterAppearance.TATTOO_RIGHT_HAND,
			]
		)
	)
	var categories: Array = [
		CATALOG.body_types,
		CATALOG.skin_tones,
		CATALOG.hair_styles,
		CATALOG.beard_lengths,
		CATALOG.tattoo_placements,
		CATALOG.hats,
		CATALOG.goggles,
		CATALOG.aprons,
		CATALOG.boots,
	]
	for category: Array[AppearanceOption] in categories:
		_assert_category_is_sound(category)


func test_a_fresh_document_reads_as_the_default_barista() -> void:
	var appearance := CharacterAppearance.from_dict({}, CATALOG)
	assert_str(appearance.body_type).is_equal(CharacterAppearance.BODY_MALE)
	assert_str(appearance.beard_length).is_equal(CharacterAppearance.BEARD_CLEAN)
	assert_str(appearance.hair_style).is_equal(CharacterAppearance.HAIR_BALD)
	assert_str(appearance.hat).is_equal(CharacterAppearance.HAT_NONE)
	assert_str(appearance.goggles).is_equal(CharacterAppearance.GOGGLES_NONE)
	assert_int(appearance.tattoo_count()).is_equal(0)
	assert_bool(appearance.matches(CharacterAppearance.make_default(CATALOG))).is_true()


func test_every_beard_is_open_to_every_body_type() -> void:
	# Section 5: the beard is open to all body types. No body filters the
	# beard list, and every combination paints a portrait.
	for body_id: String in AppearanceCatalog.ids(CATALOG.body_types):
		for beard_id: String in AppearanceCatalog.ids(CATALOG.beard_lengths):
			var appearance := CharacterAppearance.from_dict(
				{"body_type": body_id, "beard_length": beard_id}, CATALOG
			)
			assert_str(appearance.body_type).is_equal(body_id)
			assert_str(appearance.beard_length).is_equal(beard_id)
			var body := _build_portrait(appearance)
			if beard_id == CharacterAppearance.BEARD_CLEAN:
				assert_object(body.get_node_or_null(^"Beard")).is_null()
			else:
				assert_object(body.get_node_or_null(^"Beard")).is_not_null()


func test_a_fully_custom_selection_round_trips_through_the_document() -> void:
	var original := _custom_appearance()
	var reloaded := CharacterAppearance.from_dict(original.to_dict(), CATALOG)
	assert_bool(reloaded.matches(original)).is_true()
	assert_int(reloaded.tattoo_count()).is_equal(3)


func test_unknown_ids_fall_back_to_the_catalog_default() -> void:
	var appearance := (
		CharacterAppearance
		. from_dict(
			{
				"body_type": "robot",
				"skin_tone": 7,
				"hair_style": "mullet",
				"beard_length": "goatee",
				"hat": "crown",
				"goggles": "vr",
				"apron": "hazmat",
				"boots": "sandals",
			},
			CATALOG
		)
	)
	assert_bool(appearance.matches(CharacterAppearance.make_default(CATALOG))).is_true()


func test_tattoos_drop_duplicates_and_foreign_values() -> void:
	var appearance := (
		CharacterAppearance
		. from_dict(
			{
				"tattoos":
				[
					CharacterAppearance.TATTOO_LEFT_ARM,
					CharacterAppearance.TATTOO_LEFT_ARM,
					"scales",
					CharacterAppearance.TATTOO_NECK,
					7,
					true,
				]
			},
			CATALOG
		)
	)
	assert_int(appearance.tattoo_count()).is_equal(2)
	assert_bool(appearance.tattoo_placements.has(CharacterAppearance.TATTOO_LEFT_ARM)).is_true()
	assert_bool(appearance.tattoo_placements.has(CharacterAppearance.TATTOO_NECK)).is_true()
	# A foreign value in place of the list reads as no tattoos at all.
	var foreign := CharacterAppearance.from_dict({"tattoos": {"spot": 1}}, CATALOG)
	assert_int(foreign.tattoo_count()).is_equal(0)


func test_the_portrait_paints_the_skin_tone_and_the_body_shape() -> void:
	var deep := AppearanceCatalog.color_of(CATALOG.skin_tones, "deep")
	var male := _build_portrait(CharacterAppearance.from_dict({"skin_tone": "deep"}, CATALOG))
	_assert_color_is(male.color, deep)
	var male_polygon := male.polygon
	var female := _build_portrait(
		CharacterAppearance.from_dict(
			{"body_type": CharacterAppearance.BODY_FEMALE, "skin_tone": "deep"}, CATALOG
		)
	)
	assert_bool(female.polygon == male_polygon).is_false()
	# The bald default draws no hair part, and a chosen style draws one.
	assert_object(male.get_node_or_null(^"Hair")).is_null()
	var long_hair := _build_portrait(CharacterAppearance.from_dict({"hair_style": "long"}, CATALOG))
	assert_object(long_hair.get_node_or_null(^"Hair")).is_not_null()


func test_the_portrait_draws_the_steampunk_clothing_parts() -> void:
	var outfit := _build_portrait(_custom_appearance())
	var hat := outfit.get_node_or_null(^"Hat") as Polygon2D
	assert_object(hat).is_not_null()
	_assert_color_is(hat.color, AppearanceCatalog.color_of(CATALOG.hats, "top_hat"))
	var goggles := outfit.get_node_or_null(^"Goggles") as Polygon2D
	assert_object(goggles).is_not_null()
	_assert_color_is(goggles.color, AppearanceCatalog.color_of(CATALOG.goggles, "welding"))
	var apron := outfit.get_node_or_null(^"Apron") as Polygon2D
	assert_object(apron).is_not_null()
	_assert_color_is(apron.color, AppearanceCatalog.color_of(CATALOG.aprons, "leather"))
	var boots := outfit.get_node_or_null(^"Boots") as Polygon2D
	assert_object(boots).is_not_null()
	_assert_color_is(boots.color, AppearanceCatalog.color_of(CATALOG.boots, "steel"))
	# The "none" options draw no part, so the default look stays bare-faced.
	var bare := _build_portrait(CharacterAppearance.from_dict({}, CATALOG))
	assert_object(bare.get_node_or_null(^"Hat")).is_null()
	assert_object(bare.get_node_or_null(^"Goggles")).is_null()


func test_the_portrait_draws_one_part_per_tattoo_placement() -> void:
	var inked := _build_portrait(_custom_appearance())
	assert_object(inked.get_node_or_null(^"TattooLeftArm")).is_not_null()
	assert_object(inked.get_node_or_null(^"TattooNeck")).is_not_null()
	assert_object(inked.get_node_or_null(^"TattooRightHand")).is_not_null()
	assert_object(inked.get_node_or_null(^"TattooRightArm")).is_null()
	var tattoos := 0
	for child: Node in inked.get_children():
		if child.name.begins_with("Tattoo"):
			tattoos += 1
	assert_int(tattoos).is_equal(3)


func test_record_appearance_round_trips_through_the_slot() -> void:
	var path := _slot("appearance-round-trip")
	var fresh := SaveSystem.new(path)
	assert_bool(fresh.has_appearance()).is_false()
	assert_str(fresh.saved_appearance(CATALOG).beard_length).is_equal(
		CharacterAppearance.BEARD_CLEAN
	)
	var original := _custom_appearance()
	assert_int(fresh.record_appearance(original)).is_equal(OK)

	var reopened := SaveSystem.new(path)
	assert_bool(reopened.has_appearance()).is_true()
	assert_bool(reopened.saved_appearance(CATALOG).matches(original)).is_true()


func test_a_later_save_point_keeps_the_created_look() -> void:
	var path := _slot("look-survives-the-save-point")
	var original := _custom_appearance()
	var system := SaveSystem.new(path)
	assert_int(system.record_appearance(original)).is_equal(OK)
	(
		assert_int(
			(
				system
				. record_save_point(
					SaveData.POINT_CAFE_ENTRY,
					{
						"city_id": "san_coffesco",
						"scene_path": "res://scenes/city/san_coffesco.tscn",
						"position": Vector2(100, 200),
					}
				)
			)
		)
		. is_equal(OK)
	)

	var reopened := SaveSystem.new(path)
	assert_bool(reopened.has_run_state()).is_true()
	assert_bool(reopened.saved_appearance(CATALOG).matches(original)).is_true()


func test_a_save_from_an_older_version_reads_as_no_appearance() -> void:
	# A version 2 slot predates character creation. The grown document reads
	# it as no save at all, so the menu starts the creation screen fresh.
	var path := _slot("old-version")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(
		(
			'{"save_version": 2, "scene_path": "res://scenes/city/steamtle.tscn",'
			+ ' "appearance": {"beard_length": "wizard"}}'
		)
	)
	file.close()

	var system := SaveSystem.new(path)
	assert_bool(system.has_save()).is_true()
	assert_bool(system.has_run_state()).is_false()
	assert_bool(system.has_appearance()).is_false()
	assert_str(system.saved_appearance(CATALOG).beard_length).is_equal(
		CharacterAppearance.BEARD_CLEAN
	)
