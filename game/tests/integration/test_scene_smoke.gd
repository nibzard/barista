# ABOUTME: Smoke tests that verify all core scenes load and instantiate without errors.
# ABOUTME: Catches broken .tscn files and missing input actions in headless runs.
extends GdUnitTestSuite

const SCENE_PATHS := [
	"res://scenes/main/menu.tscn",
	"res://scenes/cafe/cafe.tscn",
	"res://scenes/cafe/cafe_television.tscn",
	"res://scenes/player/player.tscn",
	"res://scenes/enemies/neighbor.tscn",
	"res://scenes/enemies/tourist.tscn",
	"res://scenes/enemies/tech_bro.tscn",
	"res://scenes/enemies/gamer.tscn",
	"res://scenes/enemies/tinfoil_man.tscn",
	"res://scenes/enemies/karen.tscn",
	"res://scenes/enemies/drone.tscn",
	"res://scenes/projectiles/coffee_cup.tscn",
	"res://scenes/projectiles/fish.tscn",
	"res://scenes/bosses/sleep_jam_band.tscn",
	"res://scenes/bosses/fish_throwers.tscn",
	"res://scenes/components/sleep_zone.tscn",
	"res://scenes/components/scavenge_point.tscn",
	"res://scenes/components/building_shell.tscn",
	"res://scenes/components/bean_slick.tscn",
	"res://scenes/components/coffee_plant.tscn",
	"res://scenes/city/city_block.tscn",
	"res://scenes/city/city_map.tscn",
	"res://scenes/city/bridge_gate.tscn",
	"res://scenes/city/city_run.tscn",
	"res://scenes/city/san_coffesco.tscn",
	"res://scenes/city/san_coffesco_intro.tscn",
	"res://scenes/city/steamtle.tscn",
	"res://scenes/city/pourtland.tscn",
	"res://scenes/van/mobile_cafe.tscn",
	"res://scenes/masters/master_npc.tscn",
	"res://scenes/quests/band_member.tscn",
	"res://scenes/quests/sleepvana_stage.tscn",
	"res://scenes/quests/aisle_7_stage.tscn",
	"res://scenes/quests/aisle_7_wife.tscn",
	"res://scenes/quests/aisle_7_husband.tscn",
	"res://scenes/tower/broadcast_tower.tscn",
	"res://scenes/audio/address_audio_director.tscn",
	"res://scenes/hud/hud.tscn",
	"res://scenes/touch/touch_controls.tscn",
	"res://scenes/dex/sleepy_dex_app.tscn",
	"res://scenes/tutorial/tutorial_director.tscn",
	"res://scenes/tutorial/tutorial_video_view.tscn",
	"res://scenes/tutorial/morgen_replay.tscn",
	"res://scenes/ending/outro_director.tscn",
	"res://scenes/ending/outro_karen.tscn",
	"res://scenes/minigames/grind_dial.tscn",
	"res://scenes/minigames/pour_bloom.tscn",
	"res://scenes/minigames/press_shot.tscn",
	"res://scenes/minigames/foam_watch.tscn",
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
	&"stop_grind",
	&"hold_pressure",
	&"lift_pot",
	&"call_van",
	&"toggle_dex",
	&"start_brew",
	&"use_tool",
	&"cycle_tool",
	&"plant_coffee",
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
