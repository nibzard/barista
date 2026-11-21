# ABOUTME: Unit tests for the project-wide chalkboard theme of ART_DIRECTION section 11.
# ABOUTME: They keep the saved project theme in step with ChalkTheme.build() and the fonts readable.
extends GdUnitTestSuite


func test_project_setting_names_the_saved_chalk_theme() -> void:
	var path := str(ProjectSettings.get_setting("gui/theme/custom", ""))
	assert_str(path).is_equal(ChalkTheme.PROJECT_THEME_PATH)
	assert_str(str(ProjectSettings.get_setting("gui/theme/custom_font", ""))).is_empty()


func test_saved_theme_matches_the_built_theme() -> void:
	# Regenerate the file with ResourceSaver.save(ChalkTheme.build(), path)
	# when this case fails after a change to build().
	var saved := load(ChalkTheme.PROJECT_THEME_PATH) as Theme
	var built := ChalkTheme.build()
	assert_object(saved).is_not_null()
	assert_int(saved.default_font_size).is_equal(built.default_font_size)
	for type_name: String in ["Button", "Label", "HeaderLarge", "PanelContainer", "ProgressBar"]:
		assert_array(saved.get_color_list(type_name)).contains_exactly_in_any_order(
			built.get_color_list(type_name)
		)
		assert_array(saved.get_stylebox_list(type_name)).contains_exactly_in_any_order(
			built.get_stylebox_list(type_name)
		)
		for color_name: String in built.get_color_list(type_name):
			assert_that(saved.get_color(color_name, type_name)).is_equal(
				built.get_color(color_name, type_name)
			)
	var saved_normal := saved.get_stylebox("normal", "Button") as StyleBoxFlat
	var built_normal := built.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_that(saved_normal.bg_color).is_equal(built_normal.bg_color)
	assert_int(saved_normal.shadow_size).is_equal(built_normal.shadow_size)


func test_body_font_is_a_readable_weight_of_nunito() -> void:
	# The variable Nunito file defaults to weight 200, which is too thin on a phone.
	var body := ChalkTheme.body_font() as FontVariation
	assert_object(body).is_not_null()
	var weights: Array = body.variation_opentype.values()
	assert_int(weights.size()).is_equal(1)
	assert_int(int(weights[0])).is_greater_equal(600)
	var saved := load(ChalkTheme.PROJECT_THEME_PATH) as Theme
	assert_object(saved.default_font as FontVariation).is_not_null()


func test_buttons_use_the_display_face_and_sink_when_pressed() -> void:
	var built := ChalkTheme.build()
	assert_object(built.get_font("font", "Button")).is_same(ChalkTheme.display_font())
	var normal := built.get_stylebox("normal", "Button") as StyleBoxFlat
	var pressed := built.get_stylebox("pressed", "Button") as StyleBoxFlat
	assert_float(pressed.content_margin_top).is_greater(normal.content_margin_top)
	assert_int(pressed.shadow_size).is_less(normal.shadow_size)


func test_world_label_gets_a_chalk_face_and_an_outline() -> void:
	var label: Label = auto_free(Label.new())
	ChalkTheme.apply_world_label(label, 24)
	assert_int(label.get_theme_constant(&"outline_size")).is_greater_equal(6)
	assert_int(label.get_theme_font_size(&"font_size")).is_equal(24)
	assert_that(label.get_theme_color(&"font_color")).is_equal(ChalkTheme.CHALK_COLOR)
