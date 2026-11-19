# ABOUTME: Character creation screen: the cosmetic choices of section 5.
# ABOUTME: Stands between the main menu and the first run of section 19.
class_name CharacterCreation
extends Control

const INTRO_SCENE_PATH := "res://scenes/city/san_coffesco_intro.tscn"
const MENU_SCENE_PATH := "res://scenes/main/menu.tscn"

# One cycle row per category of section 5. The title names the row node, the
# property is the CharacterAppearance field the row writes, and the options
# come from the catalog list of the same order.
const ROW_BODY_TYPE := "RowBodyType"
const ROW_SKIN_TONE := "RowSkinTone"
const ROW_HAIR_STYLE := "RowHairStyle"
const ROW_BEARD := "RowBeard"
const ROW_HAT := "RowHat"
const ROW_GOGGLES := "RowGoggles"
const ROW_APRON := "RowApron"
const ROW_BOOTS := "RowBoots"
const ROW_TATTOOS := "RowTattoos"

@export var catalog: AppearanceCatalog

# The save slot the start button writes. A test points it at its own
# temporary slot before it presses, so the real slot of the device stays
# untouched.
var save_file_path := SaveStore.DEFAULT_SAVE_FILE

var _appearance: CharacterAppearance = null

@onready var rows_box: VBoxContainer = $Main/Right/Rows
@onready var preview_body: Polygon2D = $Main/PreviewPanel/Preview/Portrait/Body
@onready var back_button: Button = $Main/Right/Bottom/BackButton
@onready var start_button: Button = $Main/Right/Bottom/StartButton


func _ready() -> void:
	if _appearance == null:
		# A slot that already holds a look starts from it, so a revisit edits
		# the same barista instead of resetting the choices.
		var save_system := SaveSystem.new(save_file_path)
		_appearance = save_system.saved_appearance(catalog)
	_build_rows()
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_refresh()


func set_appearance(new_appearance: CharacterAppearance) -> void:
	# A test or a caller with its own state paints the screen before the
	# first draw; after _ready the same call works as a full reset.
	_appearance = new_appearance
	if is_node_ready():
		_refresh()


func appearance() -> CharacterAppearance:
	return _appearance


func _build_rows() -> void:
	_add_cycle_row(ROW_BODY_TYPE, "BODY TYPE", &"body_type", catalog.body_types)
	_add_cycle_row(ROW_SKIN_TONE, "SKIN TONE", &"skin_tone", catalog.skin_tones)
	_add_cycle_row(ROW_HAIR_STYLE, "HAIR STYLE", &"hair_style", catalog.hair_styles)
	_add_cycle_row(ROW_BEARD, "BEARD", &"beard_length", catalog.beard_lengths)
	_add_cycle_row(ROW_HAT, "HAT", &"hat", catalog.hats)
	_add_cycle_row(ROW_GOGGLES, "GOGGLES", &"goggles", catalog.goggles)
	_add_cycle_row(ROW_APRON, "APRON", &"apron", catalog.aprons)
	_add_cycle_row(ROW_BOOTS, "BOOTS", &"boots", catalog.boots)
	_add_tattoo_row()


func _add_cycle_row(
	row_name: String, title: String, property: StringName, options: Array[AppearanceOption]
) -> void:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 12)
	var prev := _row_button("<", "Prev")
	var title_label := _title_label(title)
	var value_label := _value_label()
	var next := _row_button(">", "Next")
	row.add_child(prev)
	row.add_child(title_label)
	row.add_child(value_label)
	row.add_child(next)
	rows_box.add_child(row)
	prev.pressed.connect(_on_cycle_pressed.bind(property, options, -1))
	next.pressed.connect(_on_cycle_pressed.bind(property, options, 1))
	value_label.set_meta(&"property", property)
	value_label.set_meta(&"options", options)


func _add_tattoo_row() -> void:
	# Tattoos are number and placement in one row: the plus button inks the
	# next free placement, the minus button fades the last one, section 5.
	var row := HBoxContainer.new()
	row.name = ROW_TATTOOS
	row.add_theme_constant_override("separation", 12)
	var remove := _row_button("-", "Remove")
	var title_label := _title_label("TATTOOS")
	var value_label := _value_label()
	var add := _row_button("+", "Add")
	row.add_child(remove)
	row.add_child(title_label)
	row.add_child(value_label)
	row.add_child(add)
	rows_box.add_child(row)
	remove.pressed.connect(_on_remove_tattoo_pressed)
	add.pressed.connect(_on_add_tattoo_pressed)
	value_label.set_meta(&"tattoos", true)


func _on_cycle_pressed(property: StringName, options: Array[AppearanceOption], step: int) -> void:
	var current := SaveData.string_or_default(_appearance.get(property), "")
	var index := 0
	for option_index: int in options.size():
		if options[option_index].option_id == current:
			index = option_index
			break
	var next_index := wrapi(index + step, 0, options.size())
	_appearance.set(property, options[next_index].option_id)
	_refresh()


func _on_add_tattoo_pressed() -> void:
	for option: AppearanceOption in catalog.tattoo_placements:
		if not _appearance.tattoo_placements.has(option.option_id):
			_appearance.tattoo_placements.append(option.option_id)
			_refresh()
			return


func _on_remove_tattoo_pressed() -> void:
	if not _appearance.tattoo_placements.is_empty():
		_appearance.tattoo_placements.remove_at(_appearance.tattoo_placements.size() - 1)
		_refresh()


func _on_start_pressed() -> void:
	# The look persists before the first run starts, section 18: the slot
	# holds the selection even when the player closes the app right here. The
	# system parks for the scene change like the menu continue does, so the
	# intro run reads the same slot the screen just wrote.
	var save_system := SaveSystem.new(save_file_path)
	save_system.record_appearance(_appearance)
	SaveSystem.park_for_scene_change(save_system)
	get_tree().change_scene_to_file(INTRO_SCENE_PATH)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _refresh() -> void:
	for row: Node in rows_box.get_children():
		var value_label := _value_label_of(row)
		if value_label == null:
			continue
		if bool(value_label.get_meta(&"tattoos", false)):
			value_label.text = _tattoo_text()
		else:
			var property := value_label.get_meta(&"property") as StringName
			var options := value_label.get_meta(&"options") as Array[AppearanceOption]
			var option_id := SaveData.string_or_default(_appearance.get(property), "")
			value_label.text = (AppearanceCatalog.display_name(options, option_id).to_upper())
	BaristaPortrait.build(preview_body, _appearance, catalog)


func _tattoo_text() -> String:
	if _appearance.tattoo_placements.is_empty():
		return "NONE"
	var names: Array[String] = []
	for placement: String in _appearance.tattoo_placements:
		names.append(
			AppearanceCatalog.display_name(catalog.tattoo_placements, placement).to_upper()
		)
	return "%d: %s" % [_appearance.tattoo_count(), ", ".join(names)]


func _value_label_of(row: Node) -> Label:
	for child: Node in row.get_children():
		var is_value := (
			child is Label and (child.has_meta(&"property") or child.has_meta(&"tattoos"))
		)
		if is_value:
			return child as Label
	return null


func _row_button(text: String, button_name: String) -> Button:
	# Touch-first, section 4: every control is a button big enough for a
	# thumb. No row needs a keyboard.
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = Vector2(56, 48)
	return button


func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(150, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _value_label() -> Label:
	var label := Label.new()
	label.name = "Value"
	label.custom_minimum_size = Vector2(300, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
