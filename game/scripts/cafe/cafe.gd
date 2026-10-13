# ABOUTME: Cafe is the first playable room: wake all sleepwalkers with coffee to win.
# ABOUTME: Owns the win and lose overlays; the actors report their own state changes.
class_name Cafe
extends Node2D

signal game_over
signal game_won

const GAME_OVER_TEXT := "You fell asleep. The hug was too warm."
const WIN_TEXT := "Block served! Everyone is awake."

var _awake_count := 0
var _game_over := false
var _game_won := false

@onready var player: Player = $Player
@onready var sleepwalkers: Node2D = $Sleepwalkers
@onready var overlay: ColorRect = $UI/Overlay
@onready var status_label: Label = $UI/StatusLabel
@onready var restart_button: Button = $UI/RestartButton


func _ready() -> void:
	player.fell_asleep.connect(_on_player_fell_asleep)
	for child: Node in sleepwalkers.get_children():
		var sleepwalker := child as Sleepwalker
		if sleepwalker != null:
			sleepwalker.woke_up.connect(_on_sleepwalker_woke)
	overlay.visible = false
	status_label.visible = false
	restart_button.visible = false
	restart_button.pressed.connect(_on_restart_pressed)


func get_sleepwalker(index: int) -> Sleepwalker:
	return sleepwalkers.get_child(index) as Sleepwalker


func is_game_over() -> bool:
	return _game_over


func is_game_won() -> bool:
	return _game_won


func _on_sleepwalker_woke() -> void:
	if _game_over:
		return
	_awake_count += 1
	if _awake_count >= sleepwalkers.get_child_count():
		_game_won = true
		game_won.emit()
		_show_end_screen(WIN_TEXT)


func _on_player_fell_asleep() -> void:
	if _game_won:
		return
	_game_over = true
	game_over.emit()
	_show_end_screen(GAME_OVER_TEXT)


func _show_end_screen(message: String) -> void:
	overlay.visible = true
	status_label.visible = true
	restart_button.visible = true
	status_label.text = message


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
