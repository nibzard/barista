# ABOUTME: Main menu scene script: starts the cafe level or quits the game.
# ABOUTME: Scene switching lives here so the levels stay independent.
extends Control

const CAFE_SCENE_PATH := "res://scenes/cafe/cafe.tscn"

@onready var play_button: Button = $Center/VBox/PlayButton
@onready var quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(CAFE_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
