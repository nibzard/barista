# ABOUTME: Smoke tests that verify all core scenes load and instantiate without errors.
# ABOUTME: Catches broken .tscn files and missing input actions in headless runs.
extends GdUnitTestSuite

const SCENE_PATHS := [
	"res://scenes/main/menu.tscn",
	"res://scenes/cafe/cafe.tscn",
	"res://scenes/player/player.tscn",
	"res://scenes/enemies/neighbor.tscn",
	"res://scenes/projectiles/coffee_cup.tscn",
	"res://scenes/components/sleep_zone.tscn",
	"res://scenes/components/scavenge_point.tscn",
	"res://scenes/city/city_block.tscn",
	"res://scenes/city/city_map.tscn",
	"res://scenes/tower/broadcast_tower.tscn",
	"res://scenes/hud/hud.tscn",
]

const INPUT_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"throw_coffee",
	&"drink_coffee",
	&"dodge",
	&"refill_coffee",
	&"interact",
]


func test_scenes_instantiate() -> void:
	for scene_path: String in SCENE_PATHS:
		var scene: PackedScene = load(scene_path)
		assert_object(scene).is_not_null()
		var instance: Node = scene.instantiate()
		add_child(auto_free(instance))
		assert_bool(instance.is_inside_tree()).is_true()


func test_input_actions_exist() -> void:
	for action: StringName in INPUT_ACTIONS:
		var action_exists := InputMap.has_action(action)
		(
			assert_bool(action_exists)
			. override_failure_message("Input action '%s' is missing from project.godot" % action)
			. is_true()
		)
