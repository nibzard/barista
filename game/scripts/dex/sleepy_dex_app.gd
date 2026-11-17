# ABOUTME: SleepyDexApp is the smartphone screen: the SleepyDex list on a phone.
# ABOUTME: Presentation only: every unlock rule comes from the pure SleepyDex.
class_name SleepyDexApp
extends Control

const STATUS_FOUND := "Status: found"
const STATUS_NOT_FOUND := "Status: not found"
const ANY_CUP_CURE := "Wakes from: any cup."
const CURE_TEXT := "Wakes from: %s"
const CURE_ROAST_TEXT := "Wakes from: %s (%s)"
const COUNTER_TEXT := "%d/%d FOUND"
const KEYCHAIN_TEXT := "TROLL DOLL KEYCHAIN\n%s"
# Placeholder look until the art pass, in the chalk style of the HUD.
const CHALK_COLOR := Color(0.93, 0.95, 0.88, 1)
const KEYCHAIN_COLOR := Color(0.98, 0.9, 0.55, 1)
const PORTRAIT_SIZE := Vector2(48, 48)
const NOT_FOUND_DARKEN := 0.55
const NAME_FONT_SIZE := 20
const ROW_FONT_SIZE := 15

@export var library: BrewingLibrary

var dex: SleepyDex = null

var _row_style: StyleBoxFlat = _build_row_style()

@onready var counter_label: Label = $Phone/Margin/Rows/Header/CounterLabel
@onready var list: VBoxContainer = $Phone/Margin/Rows/ListScroll/List
@onready var fact_label: Label = $Phone/Margin/Rows/Footer/FactLabel
@onready var keychain_label: Label = $Phone/Margin/Rows/Footer/KeychainLabel
@onready var close_button: Button = $Phone/Margin/Rows/Footer/CloseButton


func _ready() -> void:
	close_button.pressed.connect(close)


func bind(sleepy_dex: SleepyDex) -> void:
	# The city hands its dex over once. A rebind never doubles the listeners.
	if dex != null:
		dex.entry_opened.disconnect(_rebuild)
		dex.keychain_awarded.disconnect(_rebuild)
	dex = sleepy_dex
	dex.entry_opened.connect(_rebuild)
	dex.keychain_awarded.connect(_rebuild)
	_rebuild()


func open() -> void:
	if dex == null:
		return
	_rebuild()
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func row_count() -> int:
	return list.get_child_count()


func row_name(index: int) -> String:
	return _row_label_text(index, 0)


func row_status(index: int) -> String:
	return _row_label_text(index, 1)


func row_cure(index: int) -> String:
	return _row_label_text(index, 2)


func row_portrait_color(index: int) -> Color:
	var panel := list.get_child(index) as PanelContainer
	if panel == null:
		return Color.BLACK
	var row := panel.get_child(0) as HBoxContainer
	if row == null:
		return Color.BLACK
	var portrait := row.get_child(0) as ColorRect
	if portrait == null:
		return Color.BLACK
	return portrait.color


func counter_text() -> String:
	return counter_label.text


func keychain_text() -> String:
	return keychain_label.text


func fact_text() -> String:
	return fact_label.text


func is_keychain_visible() -> bool:
	return keychain_label.visible


func _rebuild(_type_id: String = "") -> void:
	# One pass redraws the whole list: the dex state is small, and every
	# opening, rare included, rebuilds it the same way.
	if dex == null:
		return
	_clear_rows()
	for entry: SleepyDexEntry in dex.listed_entries():
		_add_row(entry)
	counter_label.text = COUNTER_TEXT % [dex.found_count(), dex.entry_count()]
	keychain_label.visible = dex.has_keychain()
	keychain_label.text = KEYCHAIN_TEXT % SleepyDex.KEYCHAIN_LINE


func _clear_rows() -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _add_row(entry: SleepyDexEntry) -> void:
	var found := dex.is_found(entry.type_id())
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _row_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	panel.add_child(row)
	var portrait := ColorRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.color = (
		entry.portrait_color() if found else entry.portrait_color().darkened(NOT_FOUND_DARKEN)
	)
	row.add_child(portrait)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override(&"separation", 2)
	texts.add_child(_make_label(entry.display_name(), NAME_FONT_SIZE, CHALK_COLOR))
	texts.add_child(
		_make_label(STATUS_FOUND if found else STATUS_NOT_FOUND, ROW_FONT_SIZE, CHALK_COLOR)
	)
	texts.add_child(_make_label(_cure_text(entry), ROW_FONT_SIZE, CHALK_COLOR))
	row.add_child(texts)
	list.add_child(panel)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _cure_text(entry: SleepyDexEntry) -> String:
	# Section 9: every entry names the coffee that wakes the type. The basic
	# type wakes from any cup; every special type names its recipe and the
	# roasts with enough wake power for it, section 15.
	if entry.enemy_type == null or entry.enemy_type.cure == null:
		return ANY_CUP_CURE
	var cure := entry.enemy_type.cure
	if cure.is_basic or cure.cure_recipe_id.is_empty():
		return ANY_CUP_CURE
	if library == null:
		return CURE_TEXT % cure.cure_recipe_id
	var recipe := library.find_recipe(cure.cure_recipe_id)
	if recipe == null:
		return CURE_TEXT % cure.cure_recipe_id
	return CURE_ROAST_TEXT % [recipe.display_name, _roast_qualifier(cure, recipe)]


func _roast_qualifier(cure: SleepwalkerCure, recipe: Recipe) -> String:
	# A pinned roast names itself. A free roast lists every roast with
	# enough wake power to wake this sleeper.
	if recipe.roast_match == Recipe.Match.EXACT:
		var pinned := library.find_roast_by_kind(recipe.roast)
		if pinned != null:
			return "%s roast" % pinned.roast_id
	var ids := CureMatcher.roast_ids_with_enough_power(cure, library)
	if ids.is_empty():
		return "any roast"
	return "%s roast" % " or ".join(PackedStringArray(ids))


func _row_label_text(index: int, text_index: int) -> String:
	var panel := list.get_child(index) as PanelContainer
	if panel == null:
		return ""
	var row := panel.get_child(0) as HBoxContainer
	if row == null or row.get_child_count() < 2:
		return ""
	var texts := row.get_child(1) as VBoxContainer
	if texts == null or text_index >= texts.get_child_count():
		return ""
	var label := texts.get_child(text_index) as Label
	return label.text if label != null else ""


static func _build_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.17, 0.15, 0.9)
	style.set_corner_radius_all(10)
	return style
