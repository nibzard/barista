# ABOUTME: Integration tests for the SleepZone boring-attack bridge, T064.
# ABOUTME: Pins the reusable aura rule: any boss composes Kind.BORING directly.
extends GdUnitTestSuite

const SLEEP_ZONE_SCENE := preload("res://scenes/components/sleep_zone.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const METER_BALANCE := preload("res://resources/balance/sleep_meter.tres")

const PHYSICS_FRAMES_PER_SECOND := 60
# The test stand: the player sits at the center of a plain boring aura.
const AURA_RADIUS := 120.0

var _zone: SleepZone
var _player: Player


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so every case
	# composes its own aura, the way a boss scene does: a plain SleepZone
	# scene with the boring kind, no band and no city around it.
	_zone = auto_free(SLEEP_ZONE_SCENE.instantiate()) as SleepZone
	_zone.kind = SleepZone.Kind.BORING
	var shape_node := _zone.get_node(^"CollisionShape2D") as CollisionShape2D
	(shape_node.shape as CircleShape2D).radius = AURA_RADIUS
	add_child(_zone)
	_player = auto_free(PLAYER_SCENE.instantiate()) as Player
	add_child(_player)
	_player.global_position = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_a_boring_zone_drains_the_meter_at_the_boring_rate() -> void:
	# Section 14: a boring attack drains 5 per second, not the sleep-zone
	# 1.5 and not the passive 0.5. The strongest tier alone sets the rate.
	var drop := await _meter_drop(2.0)
	var expected := METER_BALANCE.boring_attack_drain_per_second * 2.0
	assert_float(drop).is_between(expected - 2.0, expected + 2.0)


func test_broadcast_silence_does_not_quieten_a_boring_zone() -> void:
	# The aura is the show of the boss, not the address of the city: a
	# silence call on the zone itself leaves the boring drain running.
	# Only the sleep poles of a dead tower go quiet.
	_zone.silence_broadcast()
	assert_bool(_zone.is_broadcast_silenced()).is_true()
	var drop := await _meter_drop(1.0)
	var expected := METER_BALANCE.boring_attack_drain_per_second
	assert_float(drop).is_between(expected - 1.0, expected + 1.0)


func test_a_deactivated_boring_zone_stops_draining() -> void:
	# The wake ends the show: set_active(false) turns the aura off, so a
	# stay inside the dead circle costs only the passive drain.
	_zone.set_active(false)
	assert_bool(_zone.is_active()).is_false()
	var drop := await _meter_drop(1.0)
	assert_float(drop).is_between(0.25, 0.75)


func _meter_drop(seconds: float) -> float:
	# Read the meter before and after a stay of the given length.
	var meter := _player.sleep_meter
	var start := meter.value
	for _frame: int in range(int(seconds * PHYSICS_FRAMES_PER_SECOND)):
		await get_tree().physics_frame
	return start - meter.value
