# ABOUTME: RobotaxiRidePanel is the hail-a-ride overlay of the robotaxi fast
# ABOUTME: travel, section 13: one button per destination stand. The panel
# ABOUTME: composes itself in code, like the line label of the aisle 7 wife.
class_name RobotaxiRidePanel
extends CanvasLayer

signal destination_chosen(stand_index: int)
signal closed

const TITLE_TEXT := "ROBOTAXI - WHERE TO?"
const STAY_TEXT := "STAY"
const BOARD_TITLE_SIZE := 26
const BOARD_TEXT_SIZE := 19
const BOARD_MIN_WIDTH := 340.0
const BOARD_TEXT_COLOR := Color(0.96, 0.93, 0.85, 1.0)
const BOARD_BACKGROUND := Color(0.16, 0.13, 0.1, 0.97)
# The ride board rides above the chalkboard HUD, like the brew stand overlay.
const BOARD_LAYER := 11

var _stand_indexes: Array[int] = []
var _buttons: Array[Button] = []

var _title_label: Label
var _button_column: VBoxContainer


func _ready() -> void:
	layer = BOARD_LAYER
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var board := PanelContainer.new()
	board.name = "Board"
	board.custom_minimum_size = Vector2(BOARD_MIN_WIDTH, 0.0)
	center.add_child(board)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 10)
	board.add_child(column)
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = TITLE_TEXT
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", BOARD_TITLE_SIZE)
	_title_label.add_theme_color_override("font_color", BOARD_TEXT_COLOR)
	column.add_child(_title_label)
	_button_column = VBoxContainer.new()
	_button_column.name = "ButtonColumn"
	_button_column.add_theme_constant_override("separation", 8)
	column.add_child(_button_column)
	var stay := Button.new()
	stay.name = "StayButton"
	stay.text = STAY_TEXT
	stay.pressed.connect(closed.emit)
	column.add_child(stay)


func begin(stand_names: Array[String], current_index: int) -> void:
	# One button per destination stand except the one the player stands at.
	for child: Node in _button_column.get_children():
		_button_column.remove_child(child)
		child.queue_free()
	_stand_indexes.clear()
	_buttons.clear()
	for i: int in range(stand_names.size()):
		if i == current_index:
			continue
		var destination := Button.new()
		destination.text = stand_names[i]
		destination.pressed.connect(destination_chosen.emit.bind(i))
		_button_column.add_child(destination)
		_stand_indexes.append(i)
		_buttons.append(destination)


func destination_indexes() -> Array[int]:
	# The stand indexes the board offers, in button order.
	return _stand_indexes.duplicate()


func press_destination(stand_index: int) -> void:
	# The touch path of a choice: the button press routes through the signal,
	# so the keyboard test path and the live path stay one code path.
	var order := _stand_indexes.find(stand_index)
	if order < 0:
		return
	_buttons[order].pressed.emit()


func press_stay() -> void:
	# The STAY button: the player keeps his curb and the board closes.
	closed.emit()


func close() -> void:
	# The board ends; the stage frees the panel.
	closed.emit()
