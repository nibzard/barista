# ABOUTME: ChalkTheme builds the cafe chalkboard interface of ART_DIRECTION section 11.
# ABOUTME: Menus are chalkboards with a wood frame; text is hand-chalk white.
class_name ChalkTheme
extends RefCounted

# The board, the wood frame, and the chalk of the interface kit. Mug red
# never enters the interface, only corporate screens.
const BOARD_COLOR := Color("#2E302B")
const BOARD_DEEP_COLOR := Color("#23251F")
const WOOD_COLOR := Color("#6B4A30")
const WOOD_LIGHT_COLOR := Color("#8A6440")
const CHALK_COLOR := Color("#F4F0E6")
const CHALK_DIM_COLOR := Color("#F4F0E6AA")
const BUTTER_COLOR := Color("#F2C866")
const ESPRESSO_COLOR := Color("#3B2418")
# The darkest value of the world is espresso brown, never black (section 2).
const SHADOW_COLOR := Color(0.11, 0.07, 0.05, 0.55)
const OUTLINE_COLOR := Color(0.11, 0.07, 0.05, 0.92)
const CORNER_RADIUS := 10
const FRAME_WIDTH := 4
const BUTTON_FONT_SIZE := 26
const BODY_FONT_SIZE := 20
const TITLE_FONT_SIZE := 44
# Nunito ships as a variable font whose default instance is weight 200
# (ExtraLight). That weight is too thin to read on a phone, so the body face
# is an instance at a semi-bold weight.
const BODY_FONT_WEIGHT := 650
# SIL OFL 1.1 fonts per ART_DIRECTION section 11: Patrick Hand for chalkboard
# display titles and signs, Nunito for warm, rounded, phone-readable body text.
const DISPLAY_FONT_PATH := "res://assets/fonts/PatrickHand-Regular.ttf"
const BODY_FONT_PATH := "res://assets/fonts/Nunito-Variable.ttf"
# The saved copy of build() that project.godot sets as the theme of every
# window. A test keeps the saved copy in step with build().
const PROJECT_THEME_PATH := "res://resources/ui/chalk_theme.tres"


static func display_font() -> Font:
	return load(DISPLAY_FONT_PATH) as Font


static func body_font() -> Font:
	var base := load(BODY_FONT_PATH) as FontFile
	if base == null:
		return null
	var weighted := FontVariation.new()
	weighted.base_font = base
	weighted.variation_opentype = {_weight_tag(): BODY_FONT_WEIGHT}
	return weighted


static func apply_display_font(control: Control) -> void:
	var font := display_font()
	if control != null and font != null:
		control.add_theme_font_override(&"font", font)


static func apply_world_label(label: Label, font_size: int = 22) -> void:
	# A label that stands on the street or the floor: chalk text with a thick
	# espresso outline, so it reads on cream stone and on dark wood.
	if label == null:
		return
	apply_display_font(label)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", CHALK_COLOR)
	label.add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override(&"outline_size", 8)


static func draw_chalk_text(
	canvas: CanvasItem,
	at: Vector2,
	text: String,
	width: float,
	font_size: int,
	color: Color = CHALK_COLOR,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
) -> void:
	# World text drawn in _draw: the chalk face with a thick espresso outline,
	# so a name or a sign reads on cream stone, on wood, and in the haze.
	var font := display_font()
	if font == null:
		font = ThemeDB.fallback_font
	canvas.draw_string_outline(font, at, text, alignment, width, font_size, 7, OUTLINE_COLOR)
	canvas.draw_string(font, at, text, alignment, width, font_size, color)


static func build() -> Theme:
	# One theme for every screen: project.godot sets the saved copy on every
	# window, so each button, label, and panel reads the chalkboard.
	var theme := Theme.new()
	var body := body_font()
	if body != null:
		theme.default_font = body
	theme.default_font_size = BODY_FONT_SIZE
	var display := display_font()
	if display != null:
		theme.set_font("font", "HeaderLarge", display)
		theme.set_font("font", "Button", display)
		theme.set_font("font", "OptionButton", display)
	theme.set_type_variation("HeaderLarge", "Label")
	theme.set_font_size("font_size", "HeaderLarge", TITLE_FONT_SIZE)
	theme.set_color("font_color", "HeaderLarge", BUTTER_COLOR)
	theme.set_color("font_outline_color", "HeaderLarge", OUTLINE_COLOR)
	theme.set_constant("outline_size", "HeaderLarge", 10)
	_add_buttons(theme)
	_add_text(theme)
	_add_panels(theme)
	_add_ranges(theme)
	return theme


static func _add_buttons(theme: Theme) -> void:
	for type_name: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type_name, _button_box(BOARD_COLOR, WOOD_COLOR, 0))
		theme.set_stylebox(
			"hover", type_name, _button_box(BOARD_COLOR.lightened(0.07), WOOD_LIGHT_COLOR, 0)
		)
		theme.set_stylebox("pressed", type_name, _button_box(BOARD_DEEP_COLOR, BUTTER_COLOR, 3))
		theme.set_stylebox(
			"hover_pressed", type_name, _button_box(BOARD_DEEP_COLOR, BUTTER_COLOR, 3)
		)
		theme.set_stylebox(
			"disabled", type_name, _button_box(BOARD_DEEP_COLOR, WOOD_COLOR.darkened(0.35), 0)
		)
		theme.set_stylebox("focus", type_name, _focus_box())
		theme.set_color("font_color", type_name, CHALK_COLOR)
		theme.set_color("font_hover_color", type_name, BUTTER_COLOR)
		theme.set_color("font_pressed_color", type_name, BUTTER_COLOR)
		theme.set_color("font_hover_pressed_color", type_name, BUTTER_COLOR)
		theme.set_color("font_focus_color", type_name, CHALK_COLOR)
		theme.set_color("font_disabled_color", type_name, CHALK_DIM_COLOR)
		theme.set_color("font_outline_color", type_name, OUTLINE_COLOR)
		theme.set_constant("outline_size", type_name, 4)
		theme.set_font_size("font_size", type_name, BUTTON_FONT_SIZE)


static func _add_text(theme: Theme) -> void:
	theme.set_color("font_color", "Label", CHALK_COLOR)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	theme.set_color("default_color", "RichTextLabel", CHALK_COLOR)
	theme.set_color("font_color", "LineEdit", CHALK_COLOR)
	theme.set_color("caret_color", "LineEdit", BUTTER_COLOR)
	theme.set_color("selection_color", "LineEdit", Color(BUTTER_COLOR, 0.35))
	theme.set_stylebox("normal", "LineEdit", _board_box(BOARD_DEEP_COLOR, WOOD_COLOR))
	theme.set_stylebox("focus", "LineEdit", _focus_box())
	theme.set_stylebox("panel", "TooltipPanel", _board_box(BOARD_COLOR, BUTTER_COLOR))
	theme.set_color("font_color", "TooltipLabel", CHALK_COLOR)


static func _add_panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", _board_box(BOARD_COLOR, WOOD_COLOR))
	theme.set_stylebox("panel", "Panel", _board_box(BOARD_COLOR, WOOD_COLOR))
	theme.set_constant("separation", "HBoxContainer", 10)
	theme.set_constant("separation", "VBoxContainer", 10)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(CHALK_COLOR, 0.45)
	grabber.set_corner_radius_all(4)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(BOARD_DEEP_COLOR, 0.6)
	track.set_corner_radius_all(4)
	track.content_margin_left = 3.0
	track.content_margin_right = 3.0
	for bar: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, track)
		theme.set_stylebox("grabber", bar, grabber)
		theme.set_stylebox("grabber_highlight", bar, grabber)
		theme.set_stylebox("grabber_pressed", bar, grabber)


static func _add_ranges(theme: Theme) -> void:
	var background := _board_box(BOARD_DEEP_COLOR, WOOD_COLOR)
	background.set_border_width_all(2)
	theme.set_stylebox("background", "ProgressBar", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BUTTER_COLOR
	fill.set_corner_radius_all(CORNER_RADIUS - 2)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", ESPRESSO_COLOR)
	var slider := StyleBoxFlat.new()
	slider.bg_color = BOARD_DEEP_COLOR
	slider.set_border_width_all(2)
	slider.border_color = WOOD_COLOR
	slider.set_corner_radius_all(6)
	slider.content_margin_top = 6.0
	slider.content_margin_bottom = 6.0
	theme.set_stylebox("slider", "HSlider", slider)
	var area := StyleBoxFlat.new()
	area.bg_color = BUTTER_COLOR
	area.set_corner_radius_all(6)
	theme.set_stylebox("grabber_area", "HSlider", area)
	theme.set_stylebox("grabber_area_highlight", "HSlider", area)


static func _button_box(board_color: Color, frame_color: Color, press_depth: int) -> StyleBoxFlat:
	# A wood-framed chalkboard plank with a soft espresso drop shadow. The
	# pressed plank sinks: the shadow shrinks and the text moves down.
	var box := _board_box(board_color, frame_color)
	box.shadow_color = SHADOW_COLOR
	box.shadow_size = 0 if press_depth > 0 else 4
	box.shadow_offset = Vector2(0, 4 - press_depth)
	box.content_margin_top = 8.0 + press_depth
	box.content_margin_bottom = maxf(8.0 - press_depth, 2.0)
	box.border_width_bottom = FRAME_WIDTH + (0 if press_depth > 0 else 2)
	return box


static func _board_box(board_color: Color, frame_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = board_color
	box.border_color = frame_color
	box.set_border_width_all(FRAME_WIDTH)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.anti_aliasing = true
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Color(BUTTER_COLOR, 0.8)
	box.set_border_width_all(2)
	box.set_corner_radius_all(CORNER_RADIUS + 2)
	box.expand_margin_left = 3.0
	box.expand_margin_right = 3.0
	box.expand_margin_top = 3.0
	box.expand_margin_bottom = 3.0
	return box


static func _weight_tag() -> int:
	return TextServerManager.get_primary_interface().name_to_tag("wght")
