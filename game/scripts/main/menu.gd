# ABOUTME: Main menu scene script: mode select, start, or quit.
# ABOUTME: Scene switching lives here so the levels stay independent.
extends Control

const CITY_SCENE_PATH := "res://scenes/city/san_coffesco_intro.tscn"
const CREATION_SCENE_PATH := "res://scenes/main/character_creation.tscn"
# Section 9: the note under the mode buttons names the rule of the selection.
const NORMAL_NOTE_TEXT := "NORMAL: FIVE WAKE-UPS. THE CAFE WAKES YOU."
const HARDCORE_NOTE_TEXT := "HARDCORE: NO WAKE-UPS. ONE SLEEP ENDS THE RUN. DEATH DELETES THE SAVE."
# The fresh-start gate stands beside Play because Play only continues: the
# note names the price of the reset before the player pays it.
const NEW_GAME_NOTE_TEXT := "START A NEW GAME? THIS DELETES THE CURRENT SAVE AND THE BARISTA."

# The save slot the play button reads. A test points it at its own temporary
# slot before it presses, so the real slot of the device stays untouched.
var save_file_path := SaveStore.DEFAULT_SAVE_FILE
# The mode the next fresh start plays, section 9. A running save keeps the
# mode its slot holds: the continue path never rewrites it.
var selected_mode := SaveData.MODE_NORMAL

@onready var play_button: Button = $Center/VBox/PlayButton
@onready var new_game_button: Button = $Center/VBox/NewGameButton
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var normal_button: Button = $Center/VBox/ModeRow/NormalButton
@onready var hardcore_button: Button = $Center/VBox/ModeRow/HardcoreButton
@onready var mode_note: Label = $Center/VBox/ModeNote
@onready var new_game_note: Label = $Center/VBox/NewGameNote
@onready var confirm_row: HBoxContainer = $Center/VBox/ConfirmRow
@onready var cancel_button: Button = $Center/VBox/ConfirmRow/CancelButton
@onready var confirm_button: Button = $Center/VBox/ConfirmRow/ConfirmButton


func _ready() -> void:
	# The chalkboard menu of the interface kit, ART_DIRECTION section 11.
	theme = ChalkTheme.build()
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	normal_button.pressed.connect(_on_normal_pressed)
	hardcore_button.pressed.connect(_on_hardcore_pressed)
	# The slot names the mode the next run plays: a running save answers with
	# its own mode, a fresh slot with the default normal.
	selected_mode = SaveSystem.new(save_file_path).saved_game_mode()
	new_game_note.text = NEW_GAME_NOTE_TEXT
	_sync_mode_buttons()
	_hide_new_game_confirmation()


func _on_normal_pressed() -> void:
	_select_mode(SaveData.MODE_NORMAL)


func _on_hardcore_pressed() -> void:
	_select_mode(SaveData.MODE_HARDCORE)


func _select_mode(mode: String) -> void:
	selected_mode = mode
	_sync_mode_buttons()


func _sync_mode_buttons() -> void:
	normal_button.set_pressed_no_signal(selected_mode == SaveData.MODE_NORMAL)
	hardcore_button.set_pressed_no_signal(selected_mode == SaveData.MODE_HARDCORE)
	mode_note.text = (
		HARDCORE_NOTE_TEXT if selected_mode == SaveData.MODE_HARDCORE else NORMAL_NOTE_TEXT
	)


func _on_play_pressed() -> void:
	var save_system := SaveSystem.new(save_file_path)
	var continue_path := save_system.continue_scene_path()
	if not continue_path.is_empty():
		# The slot rides the scene change, so the city that lands reads the
		# same document the menu just read.
		SaveSystem.park_for_scene_change(save_system)
		get_tree().change_scene_to_file(continue_path)
		return
	# Section 9: the chosen mode rides the slot before the first run starts,
	# and every save point of the run rewrites it from the live game.
	save_system.record_game_mode(selected_mode)
	# Section 19: character creation stands between this menu and the first
	# run. A slot that already holds the created look skips straight to the
	# run: the selection persists, section 18, and the player never builds
	# the same barista twice.
	if save_system.has_appearance():
		SaveSystem.park_for_scene_change(save_system)
		get_tree().change_scene_to_file(CITY_SCENE_PATH)
		return
	get_tree().change_scene_to_file(CREATION_SCENE_PATH)


func _on_new_game_pressed() -> void:
	# Play continues a standing save, so the fresh start needs its own gate.
	# The confirmation stands between one stray tap and the deleted slot.
	_show_new_game_confirmation()


func _on_cancel_pressed() -> void:
	_hide_new_game_confirmation()


func _on_confirm_pressed() -> void:
	# The confirmed reset keeps both advertised modes reachable for the life of
	# the install: Android owns the user:// storage, so no app-data wipe may
	# stand between a player and a second barista or the other mode. The
	# cleared slot takes the picked mode like any fresh start, and the deleted
	# look sends the player back through character creation.
	MoveHandoff.reset_all()
	SaveSystem.take_after_scene_change()
	var save_system := SaveSystem.new(save_file_path)
	save_system.delete_save()
	save_system.record_game_mode(selected_mode)
	get_tree().change_scene_to_file(CREATION_SCENE_PATH)


func _show_new_game_confirmation() -> void:
	new_game_note.visible = true
	confirm_row.visible = true
	play_button.visible = false
	new_game_button.visible = false
	quit_button.visible = false


func _hide_new_game_confirmation() -> void:
	new_game_note.visible = false
	confirm_row.visible = false
	play_button.visible = true
	quit_button.visible = true
	# The gate opens only when a run or barista exists: a slot holding only a
	# mode selection starts through Play alone.
	var save_system := SaveSystem.new(save_file_path)
	new_game_button.visible = save_system.has_run_state() or save_system.has_appearance()


func _on_quit_pressed() -> void:
	get_tree().quit()
