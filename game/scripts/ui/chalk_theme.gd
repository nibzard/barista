# ABOUTME: ChalkTheme builds the cafe chalkboard interface of ART_DIRECTION section 11.
# ABOUTME: Menus are chalkboards with a wood frame; text is hand-chalk white.
class_name ChalkTheme
extends RefCounted

# The board, the wood frame, and the chalk of the interface kit. Mug red
# never enters the interface, only corporate screens.
const BOARD_COLOR := Color("#2E302B")
const WOOD_COLOR := Color("#6B4A30")
const CHALK_COLOR := Color("#F4F0E6")
const CHALK_DIM_COLOR := Color("#F4F0E6AA")
const BUTTER_COLOR := Color("#F2C866")
const CORNER_RADIUS := 8
const FRAME_WIDTH := 4
const BUTTON_FONT_SIZE := 22


static func build() -> Theme:
	# One theme for every menu screen: set it on the root Control and every
	# button and label below it reads the chalkboard.
	var theme := Theme.new()
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var brightness := 0.0
		if state == "hover":
			brightness = 0.08
		elif state == "pressed":
			brightness = 0.14
		theme.set_stylebox(state, "Button", _board_box(BOARD_COLOR.lightened(brightness)))
	theme.set_color("font_color", "Button", CHALK_COLOR)
	theme.set_color("font_hover_color", "Button", BUTTER_COLOR)
	theme.set_color("font_pressed_color", "Button", BUTTER_COLOR)
	theme.set_color("font_focus_color", "Button", CHALK_COLOR)
	theme.set_color("font_disabled_color", "Button", CHALK_DIM_COLOR)
	theme.set_font_size("font_size", "Button", BUTTON_FONT_SIZE)
	theme.set_color("font_color", "Label", CHALK_COLOR)
	theme.set_stylebox("panel", "PanelContainer", _board_box(BOARD_COLOR))
	return theme


static func _board_box(board_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = board_color
	box.border_color = WOOD_COLOR
	box.set_border_width_all(FRAME_WIDTH)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box
