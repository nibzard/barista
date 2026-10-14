# ABOUTME: Unit tests that pin every balance .tres file to its tuned values.
# ABOUTME: Guards the rule that gameplay constants live in resources, not scripts.
extends GdUnitTestSuite

const PLAYER_BALANCE := preload("res://resources/balance/player.tres")
const SLEEPWALKER_BALANCE := preload("res://resources/balance/sleepwalker.tres")
const COFFEE_CUP_BALANCE := preload("res://resources/balance/coffee_cup.tres")
const SLEEP_METER_BALANCE := preload("res://resources/balance/sleep_meter.tres")
const COFFEE_SUPPLY_BALANCE := preload("res://resources/balance/coffee_supply.tres")
const WAKE_UPS_BALANCE := preload("res://resources/balance/wake_ups.tres")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const BROADCAST_TOWER_BALANCE := preload("res://resources/balance/broadcast_tower.tres")

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const COFFEE_CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const BROADCAST_TOWER_SCENE := preload("res://scenes/tower/broadcast_tower.tscn")


func test_player_balance_values() -> void:
	assert_bool(PLAYER_BALANCE is PlayerBalance).is_true()
	assert_float(PLAYER_BALANCE.move_speed).is_equal(220.0)
	assert_float(PLAYER_BALANCE.drink_slow_walk_factor).is_equal(0.5)
	assert_float(PLAYER_BALANCE.dodge_duration_seconds).is_equal(0.4)
	assert_float(PLAYER_BALANCE.dodge_speed).is_equal(440.0)
	assert_int(PLAYER_BALANCE.hug_mash_presses_to_break).is_equal(5)
	assert_float(PLAYER_BALANCE.hug_break_grace_seconds).is_equal(0.5)


func test_sleepwalker_balance_values() -> void:
	assert_bool(SLEEPWALKER_BALANCE is SleepwalkerBalance).is_true()
	assert_float(SLEEPWALKER_BALANCE.walk_speed).is_equal(40.0)
	assert_float(SLEEPWALKER_BALANCE.chase_speed).is_equal(70.0)
	assert_float(SLEEPWALKER_BALANCE.wander_change_min_seconds).is_equal(1.0)
	assert_float(SLEEPWALKER_BALANCE.wander_change_max_seconds).is_equal(3.0)
	assert_float(SLEEPWALKER_BALANCE.idle_chance).is_equal(0.25)


func test_coffee_cup_balance_values() -> void:
	assert_bool(COFFEE_CUP_BALANCE is CoffeeCupBalance).is_true()
	assert_float(COFFEE_CUP_BALANCE.flight_time_seconds).is_equal(1.0)
	assert_float(COFFEE_CUP_BALANCE.throw_range).is_equal(500.0)
	assert_float(COFFEE_CUP_BALANCE.arc_peak_height).is_equal(40.0)
	assert_float(COFFEE_CUP_BALANCE.aim_cone_half_angle_degrees).is_equal(30.0)


func test_sleep_meter_balance_values() -> void:
	assert_bool(SLEEP_METER_BALANCE is SleepMeterBalance).is_true()
	assert_float(SLEEP_METER_BALANCE.max_value).is_equal(100.0)
	assert_float(SLEEP_METER_BALANCE.passive_drain_per_second).is_equal(0.5)
	assert_float(SLEEP_METER_BALANCE.sleep_zone_drain_per_second).is_equal(1.5)
	assert_float(SLEEP_METER_BALANCE.boring_attack_drain_per_second).is_equal(5.0)
	assert_float(SLEEP_METER_BALANCE.hug_drain_per_second).is_equal(15.0)
	assert_float(SLEEP_METER_BALANCE.cup_gain).is_equal(40.0)
	assert_float(SLEEP_METER_BALANCE.drink_duration_seconds).is_equal(1.5)


func test_coffee_supply_balance_values() -> void:
	assert_bool(COFFEE_SUPPLY_BALANCE is CoffeeSupplyBalance).is_true()
	assert_int(COFFEE_SUPPLY_BALANCE.base_carry_limit).is_equal(12)
	assert_int(COFFEE_SUPPLY_BALANCE.mobile_cafe_level2_carry_limit).is_equal(20)
	assert_int(COFFEE_SUPPLY_BALANCE.thermos_belt_carry_bonus).is_equal(3)
	assert_int(COFFEE_SUPPLY_BALANCE.drink_cost).is_equal(1)
	assert_int(COFFEE_SUPPLY_BALANCE.support_tool_cost).is_equal(0)
	assert_int(COFFEE_SUPPLY_BALANCE.cup_throw_cost).is_equal(1)
	assert_int(COFFEE_SUPPLY_BALANCE.travel_mug_cost).is_equal(0)
	assert_int(COFFEE_SUPPLY_BALANCE.thermos_cost).is_equal(3)
	assert_int(COFFEE_SUPPLY_BALANCE.moka_launcher_cost).is_equal(4)
	assert_float(COFFEE_SUPPLY_BALANCE.minigun_cups_per_second).is_equal(6.0)


func test_wake_ups_balance_values() -> void:
	assert_bool(WAKE_UPS_BALANCE is WakeUpsBalance).is_true()
	assert_int(WAKE_UPS_BALANCE.start_wake_ups).is_equal(5)
	assert_int(WAKE_UPS_BALANCE.max_wake_ups).is_equal(5)


func test_city_balance_values() -> void:
	assert_bool(CITY_BALANCE is CityBalance).is_true()
	assert_int(CITY_BALANCE.min_blocks).is_equal(6)
	assert_int(CITY_BALANCE.max_blocks).is_equal(9)
	assert_int(CITY_BALANCE.density_min).is_equal(3)
	assert_int(CITY_BALANCE.density_max).is_equal(4)
	assert_int(CITY_BALANCE.speaker_pole_count).is_equal(3)
	assert_float(CITY_BALANCE.blocks_per_screen).is_equal(1.5)


func test_broadcast_tower_balance_values() -> void:
	assert_bool(BROADCAST_TOWER_BALANCE is BroadcastTowerBalance).is_true()
	# Section 21: one second of silence. Section 15: one fuse opens one tower.
	assert_float(BROADCAST_TOWER_BALANCE.silence_seconds).is_equal(1.0)
	assert_int(BROADCAST_TOWER_BALANCE.fuses_needed).is_equal(1)


func test_scenes_load_balance_resources() -> void:
	var player := auto_free(PLAYER_SCENE.instantiate()) as Player
	assert_object(player.balance).is_not_null()
	assert_float(player.balance.move_speed).is_equal(PLAYER_BALANCE.move_speed)
	assert_object(player.supply_balance).is_not_null()
	assert_int(player.supply_balance.base_carry_limit).is_equal(
		COFFEE_SUPPLY_BALANCE.base_carry_limit
	)
	assert_object(player.wake_ups_balance).is_not_null()
	assert_int(player.wake_ups_balance.start_wake_ups).is_equal(WAKE_UPS_BALANCE.start_wake_ups)
	assert_object(player.cup_balance).is_not_null()
	assert_float(player.cup_balance.flight_time_seconds).is_equal(
		COFFEE_CUP_BALANCE.flight_time_seconds
	)
	var sleepwalker := auto_free(NEIGHBOR_SCENE.instantiate()) as Sleepwalker
	assert_object(sleepwalker.balance).is_not_null()
	assert_float(sleepwalker.balance.walk_speed).is_equal(SLEEPWALKER_BALANCE.walk_speed)
	var cup := auto_free(COFFEE_CUP_SCENE.instantiate()) as CoffeeCup
	assert_object(cup.balance).is_not_null()
	assert_float(cup.balance.flight_time_seconds).is_equal(COFFEE_CUP_BALANCE.flight_time_seconds)
	var tower := auto_free(BROADCAST_TOWER_SCENE.instantiate()) as BroadcastTower
	assert_object(tower.balance).is_not_null()
	assert_float(tower.balance.silence_seconds).is_equal(BROADCAST_TOWER_BALANCE.silence_seconds)
	assert_int(tower.balance.fuses_needed).is_equal(BROADCAST_TOWER_BALANCE.fuses_needed)


func test_neighbor_hug_grab_range_is_short() -> void:
	# Section 14: the hug grab range is short. The grab circle stays much
	# smaller than the sense circle that starts the chase.
	var sleepwalker := auto_free(NEIGHBOR_SCENE.instantiate()) as Sleepwalker
	var hug_shape := sleepwalker.get_node("HugArea/HugShape") as CollisionShape2D
	var hug_circle := hug_shape.shape as CircleShape2D
	var sense_shape := sleepwalker.get_node("SenseArea/SenseShape") as CollisionShape2D
	var sense_circle := sense_shape.shape as CircleShape2D
	assert_float(hug_circle.radius).is_equal(18.0)
	assert_float(hug_circle.radius).is_less(sense_circle.radius)
