# ABOUTME: Main menu scene script: starts the free city or quits the game.
# ABOUTME: Scene switching lives here so the levels stay independent.
extends Control

const CITY_SCENE_PATH := "res://scenes/city/san_coffesco_intro.tscn"

@onready var play_button: Button = $Center/VBox/PlayButton
@onready var quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	# The first run plays the tutorial of section 19 inside San Coffesco.
	# Character creation (T046) stands before this scene when it ships.
	get_tree().change_scene_to_file(CITY_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
