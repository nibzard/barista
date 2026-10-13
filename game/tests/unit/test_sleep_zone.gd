# ABOUTME: Unit tests for the SleepZone component scene wiring.
# ABOUTME: The zone must detect the player layer; cafe flow tests cover the drain.
extends GdUnitTestSuite

const SLEEP_ZONE_SCENE := preload("res://scenes/components/sleep_zone.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func test_zone_defaults_to_sleep_kind() -> void:
	var zone := auto_free(SLEEP_ZONE_SCENE.instantiate()) as SleepZone
	assert_int(zone.kind).is_equal(SleepZone.Kind.SLEEP)


func test_kind_enum_order_is_stable() -> void:
	# The cafe scene pins kind by number, so SLEEP must stay first.
	assert_int(SleepZone.Kind.SLEEP).is_equal(0)
	assert_int(SleepZone.Kind.SAFE).is_equal(1)


func test_zone_monitors_only_the_player_layer() -> void:
	var zone := auto_free(SLEEP_ZONE_SCENE.instantiate()) as SleepZone
	var player := auto_free(PLAYER_SCENE.instantiate()) as Player
	assert_bool(zone.monitoring).is_true()
	assert_bool(zone.monitorable).is_false()
	assert_int(zone.collision_layer).is_equal(0)
	assert_int(zone.collision_mask).is_equal(player.collision_layer)
