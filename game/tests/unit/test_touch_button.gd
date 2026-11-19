# ABOUTME: Unit tests of the touch button glyphs, ART_DIRECTION section 11.
# ABOUTME: Touch buttons are round coasters with a chalk icon, not a word.
extends GdUnitTestSuite


func test_every_button_kind_wears_an_icon() -> void:
	# The words left the coasters: each of the thirteen kinds maps to a
	# glyph, and no glyph serves twice by accident.
	var kinds: Array = TouchControls.ButtonKind.values()
	assert_int(TouchControls.BUTTON_ICONS.size()).is_equal(kinds.size())
	var worn: Array = []
	for kind: int in kinds:
		var glyph := TouchControls.icon_for(kind as TouchControls.ButtonKind)
		assert_int(glyph).is_between(0, 12)
		assert_bool(worn.has(glyph)).is_false()
		worn.append(glyph)


func test_section_eleven_names_the_three_glyphs() -> void:
	# Cup for throw, mug for drink, roll arrow for dodge.
	assert_int(TouchControls.icon_for(TouchControls.ButtonKind.THROW)).is_equal(
		TouchButton.Icon.CUP
	)
	assert_int(TouchControls.icon_for(TouchControls.ButtonKind.DRINK)).is_equal(
		TouchButton.Icon.MUG
	)
	assert_int(TouchControls.icon_for(TouchControls.ButtonKind.DODGE)).is_equal(
		TouchButton.Icon.ROLL_ARROW
	)


func test_the_button_carries_no_label_property() -> void:
	# The readout is the glyph: a word property would let a text fallback
	# sneak back onto the coaster.
	var button: TouchButton = auto_free(TouchButton.new())
	assert_bool("label" in button).is_false()
	assert_int(button.icon).is_equal(TouchButton.Icon.CUP)


func test_the_glyph_set_covers_the_whole_enum() -> void:
	# Thirteen kinds, thirteen glyphs: the worn list in the first test stays
	# complete only while the enum and the map grow together.
	assert_int(TouchButton.Icon.values().size()).is_equal(13)
