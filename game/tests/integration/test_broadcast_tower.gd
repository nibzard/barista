# ABOUTME: Integration tests for the broadcast tower: the fuse-gated switch flow.
# ABOUTME: Covers the switch beat from GAME_DESIGN sections 19 and 21, plus the save contract.
extends GdUnitTestSuite

const TOWER_SCENE := preload("res://scenes/tower/broadcast_tower.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 300

var _tower: BroadcastTower
var _player: Player


func before_test() -> void:
	_tower = TOWER_SCENE.instantiate() as BroadcastTower
	add_child(auto_free(_tower))
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(auto_free(_player))
	await get_tree().physics_frame


func test_switch_without_a_fuse_does_nothing() -> void:
	assert_bool(_tower.insert_fuse(_player)).is_false()
	assert_bool(_tower.switch_off()).is_false()
	assert_int(_tower.phase).is_equal(BroadcastTower.Phase.BROADCASTING)
	assert_bool(_tower.is_switched_off()).is_false()
	assert_bool(_tower.is_wake_up_restored()).is_false()


func test_switch_still_fails_when_the_bag_holds_a_fuse_but_the_slot_is_empty() -> void:
	_player.pickup_item(FUSE_ITEM, 1)
	assert_bool(_tower.switch_off()).is_false()
	assert_int(_tower.phase).is_equal(BroadcastTower.Phase.BROADCASTING)
	assert_int(_player.inventory.count(FUSE_ITEM.item_id)).is_equal(1)


func test_insert_fuse_consumes_one_fuse_and_fills_the_slot() -> void:
	_player.pickup_item(FUSE_ITEM, 2)
	assert_bool(_tower.insert_fuse(_player)).is_true()
	assert_int(_tower.phase).is_equal(BroadcastTower.Phase.FUSED)
	assert_int(_player.inventory.count(FUSE_ITEM.item_id)).is_equal(1)
	assert_bool(_tower.is_switched_off()).is_false()
	# The slot takes exactly one fuse; a second insert does nothing.
	assert_bool(_tower.insert_fuse(_player)).is_false()
	assert_int(_player.inventory.count(FUSE_ITEM.item_id)).is_equal(1)


func test_switch_off_runs_silence_then_birdsong() -> void:
	var events: Array = []
	_tower.fuse_inserted.connect(func() -> void: events.append("fuse_inserted"))
	_tower.switched_off.connect(func() -> void: events.append("switched_off"))
	_tower.birdsong.connect(func() -> void: events.append("birdsong"))
	_player.pickup_item(FUSE_ITEM, 1)
	_tower.insert_fuse(_player)

	assert_bool(_tower.switch_off()).is_true()
	# The address stops mid-word in the same frame: the silence starts at once.
	assert_int(_tower.phase).is_equal(BroadcastTower.Phase.SILENCE)
	assert_bool(_tower.is_switched_off()).is_true()
	assert_bool(_tower.is_wake_up_restored()).is_true()

	var frames := 0
	while _tower.phase != BroadcastTower.Phase.BIRDSONG and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_tower.phase).is_equal(BroadcastTower.Phase.BIRDSONG)
	# Section 21: one second of silence at 60 physics frames per second.
	assert_int(frames).is_between(55, 65)
	assert_array(events).is_equal(["fuse_inserted", "switched_off", "birdsong"])


func test_the_tower_switches_off_only_once() -> void:
	_player.pickup_item(FUSE_ITEM, 2)
	_tower.insert_fuse(_player)
	_tower.switch_off()
	assert_bool(_tower.switch_off()).is_false()
	assert_bool(_tower.insert_fuse(_player)).is_false()
	assert_int(_tower.phase).is_equal(BroadcastTower.Phase.SILENCE)


func test_sleeping_player_cannot_insert_a_fuse() -> void:
	_player.pickup_item(FUSE_ITEM, 1)
	_player.wake_ups.remaining = 0
	_player.sleep_meter.drain(200.0)
	await get_tree().physics_frame
	assert_bool(_player.is_asleep()).is_true()

	assert_bool(_tower.insert_fuse(_player)).is_false()
	assert_int(_player.inventory.count(FUSE_ITEM.item_id)).is_equal(1)
	assert_int(_tower.phase).is_equal(BroadcastTower.Phase.BROADCASTING)


func test_tower_state_round_trips_for_the_save_system() -> void:
	assert_int(_tower.save_state()).is_equal(BroadcastTower.Phase.BROADCASTING)

	_player.pickup_item(FUSE_ITEM, 1)
	_tower.insert_fuse(_player)
	var fused_state: int = _tower.save_state()
	_tower.switch_off()
	var off_state: int = _tower.save_state()

	var loaded := auto_free(TOWER_SCENE.instantiate()) as BroadcastTower
	add_child(loaded)
	loaded.load_state(fused_state)
	assert_int(loaded.phase).is_equal(BroadcastTower.Phase.FUSED)
	assert_bool(loaded.is_switched_off()).is_false()

	loaded.load_state(off_state)
	assert_bool(loaded.is_switched_off()).is_true()
	assert_bool(loaded.is_wake_up_restored()).is_true()

	loaded.load_state(99)
	assert_int(loaded.phase).is_equal(BroadcastTower.Phase.BROADCASTING)


func test_load_state_does_not_replay_the_beat() -> void:
	var loaded := auto_free(TOWER_SCENE.instantiate()) as BroadcastTower
	add_child(loaded)
	var events: Array = []
	loaded.switched_off.connect(func() -> void: events.append("switched_off"))
	loaded.birdsong.connect(func() -> void: events.append("birdsong"))

	loaded.load_state(BroadcastTower.Phase.SILENCE)
	for frame: int in range(10):
		await get_tree().physics_frame

	assert_array(events).is_empty()
	# A loaded off tower rests at birdsong; the beat never runs again.
	assert_int(loaded.phase).is_equal(BroadcastTower.Phase.BIRDSONG)
