# ABOUTME: Unit tests that pin every balance .tres file to its tuned values.
# ABOUTME: Guards the rule that gameplay constants live in resources, not scripts.
extends GdUnitTestSuite

const PLAYER_BALANCE := preload("res://resources/balance/player.tres")
const SLEEPWALKER_BALANCE := preload("res://resources/balance/sleepwalker.tres")
const TOURIST_BALANCE := preload("res://resources/balance/tourist.tres")
const TECH_BRO_BALANCE := preload("res://resources/balance/tech_bro.tres")
const GAMER_BALANCE := preload("res://resources/balance/gamer.tres")
const KAREN_BALANCE := preload("res://resources/balance/karen.tres")
const COFFEE_CUP_BALANCE := preload("res://resources/balance/coffee_cup.tres")
const SLEEP_METER_BALANCE := preload("res://resources/balance/sleep_meter.tres")
const COFFEE_SUPPLY_BALANCE := preload("res://resources/balance/coffee_supply.tres")
const CLUSTER_BOMB_BALANCE := preload("res://resources/balance/cluster_bomb.tres")
const WAKE_UPS_BALANCE := preload("res://resources/balance/wake_ups.tres")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const BROADCAST_TOWER_BALANCE := preload("res://resources/balance/broadcast_tower.tres")
const GRIND_DIAL_BALANCE := preload("res://resources/balance/grind_dial.tres")
const POUR_BALANCE := preload("res://resources/balance/pour.tres")
const PRESS_BALANCE := preload("res://resources/balance/press.tres")
const FOAM_WATCH_BALANCE := preload("res://resources/balance/foam_watch.tres")
const MOBILE_CAFE_BALANCE := preload("res://resources/balance/mobile_cafe.tres")
const SLEEP_JAM_BALANCE := preload("res://resources/balance/sleep_jam.tres")
const TUTORIAL_BALANCE := preload("res://resources/balance/tutorial.tres")

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const TOURIST_SCENE := preload("res://scenes/enemies/tourist.tscn")
const TECH_BRO_SCENE := preload("res://scenes/enemies/tech_bro.tscn")
const GAMER_SCENE := preload("res://scenes/enemies/gamer.tscn")
const KAREN_SCENE := preload("res://scenes/enemies/karen.tscn")
const COFFEE_CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const BROADCAST_TOWER_SCENE := preload("res://scenes/tower/broadcast_tower.tscn")
const GRIND_DIAL_SCENE := preload("res://scenes/minigames/grind_dial.tscn")
const POUR_SCENE := preload("res://scenes/minigames/pour_bloom.tscn")
const PRESS_SCENE := preload("res://scenes/minigames/press_shot.tscn")
const FOAM_WATCH_SCENE := preload("res://scenes/minigames/foam_watch.tscn")
const MOBILE_CAFE_SCENE := preload("res://scenes/van/mobile_cafe.tscn")
const TUTORIAL_SCENE := preload("res://scenes/tutorial/tutorial_director.tscn")
const INTRO_SCENE := preload("res://scenes/city/san_coffesco_intro.tscn")
const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")


func test_player_balance_values() -> void:
	assert_bool(PLAYER_BALANCE is PlayerBalance).is_true()
	assert_float(PLAYER_BALANCE.move_speed).is_equal(220.0)
	assert_float(PLAYER_BALANCE.drink_slow_walk_factor).is_equal(0.5)
	assert_float(PLAYER_BALANCE.dodge_duration_seconds).is_equal(0.4)
	# The roll cooldown: 0.8 s from the roll start halves the chain-roll
	# invulnerability uptime, the T071 playtest outcome.
	assert_float(PLAYER_BALANCE.dodge_cooldown_seconds).is_equal(0.8)
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
	assert_float(SLEEPWALKER_BALANCE.gather_stop_distance).is_equal(26.0)
	# The fan crowd of the Sleepvana show walks at the follow speed, section 13.
	assert_float(SLEEPWALKER_BALANCE.follow_speed).is_equal(160.0)
	assert_float(SLEEPWALKER_BALANCE.follow_speed).is_greater(SLEEPWALKER_BALANCE.walk_speed)


func test_tourist_balance_values() -> void:
	assert_bool(TOURIST_BALANCE is TouristBalance).is_true()
	assert_float(TOURIST_BALANCE.photo_interval_seconds).is_equal(2.0)
	assert_float(TOURIST_BALANCE.flash_windup_seconds).is_equal(0.5)
	assert_float(TOURIST_BALANCE.flash_stun_seconds).is_equal(0.75)
	assert_float(TOURIST_BALANCE.flash_radius).is_equal(140.0)
	assert_float(TOURIST_BALANCE.photo_recovery_seconds).is_equal(1.0)


func test_tech_bro_balance_values() -> void:
	assert_bool(TECH_BRO_BALANCE is TechBroBalance).is_true()
	assert_float(TECH_BRO_BALANCE.pitch_interval_seconds).is_equal(2.5)
	assert_float(TECH_BRO_BALANCE.orbit_radius).is_equal(56.0)
	assert_float(TECH_BRO_BALANCE.orbit_angular_speed_degrees_per_second).is_equal(140.0)
	assert_float(TECH_BRO_BALANCE.dive_trigger_radius).is_equal(130.0)
	assert_float(TECH_BRO_BALANCE.dive_speed).is_equal(300.0)
	assert_float(TECH_BRO_BALANCE.bump_radius).is_equal(22.0)
	assert_float(TECH_BRO_BALANCE.bump_stun_seconds).is_equal(0.35)
	assert_float(TECH_BRO_BALANCE.dive_cooldown_seconds).is_equal(1.2)


func test_gamer_balance_values() -> void:
	assert_bool(GAMER_BALANCE is GamerBalance).is_true()
	# The dash outruns the player (220) and the steady chase (70), but the
	# bursts stay short with a long rest between them.
	assert_float(GAMER_BALANCE.dash_speed).is_equal(320.0)
	assert_float(GAMER_BALANCE.dash_duration_seconds).is_equal(0.25)
	assert_float(GAMER_BALANCE.windup_seconds).is_equal(0.35)
	assert_float(GAMER_BALANCE.rest_seconds).is_equal(0.8)
	assert_float(GAMER_BALANCE.dash_duration_seconds).is_less(GAMER_BALANCE.rest_seconds)


func test_karen_balance_values() -> void:
	assert_bool(KAREN_BALANCE is KarenBalance).is_true()
	# Section 6: she looks slow but moves very fast. The lull creeps far under
	# the neighbor walk of 40, and the sprint outruns the player walk of 220,
	# so the surprise attack is real: only the roll escapes it.
	assert_float(KAREN_BALANCE.lull_speed).is_equal(12.0)
	assert_float(KAREN_BALANCE.sprint_speed).is_equal(240.0)
	assert_float(KAREN_BALANCE.lull_speed).is_less(SLEEPWALKER_BALANCE.walk_speed)
	assert_float(KAREN_BALANCE.sprint_speed).is_greater(PLAYER_BALANCE.move_speed)
	assert_float(KAREN_BALANCE.lull_speed).is_less(KAREN_BALANCE.sprint_speed)


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
	# Section 15: one scavenge crate of the shared kit holds this stock. The
	# scrap funds the van upgrades, so it moves with the mobile cafe costs.
	assert_int(CITY_BALANCE.scavenge_house_beans).is_equal(3)
	assert_int(CITY_BALANCE.scavenge_scrap_parts).is_equal(9)
	assert_int(CITY_BALANCE.scavenge_scrap_parts).is_greater(0)
	# Section 10: the cafe safe zone grows with the city on the route.
	assert_int(CITY_BALANCE.cafe_zone_radius_per_tier.size()).is_equal(3)
	assert_float(CITY_BALANCE.cafe_zone_radius_per_tier[0]).is_equal(180.0)
	assert_float(CITY_BALANCE.cafe_zone_radius_per_tier[1]).is_equal(240.0)
	assert_float(CITY_BALANCE.cafe_zone_radius_per_tier[2]).is_equal(300.0)
	for i: int in range(1, CITY_BALANCE.cafe_zone_radius_per_tier.size()):
		assert_float(CITY_BALANCE.cafe_zone_radius_per_tier[i]).is_greater(
			CITY_BALANCE.cafe_zone_radius_per_tier[i - 1]
		)


func test_broadcast_tower_balance_values() -> void:
	assert_bool(BROADCAST_TOWER_BALANCE is BroadcastTowerBalance).is_true()
	# Section 21: one second of silence. Section 15: one fuse opens one tower.
	assert_float(BROADCAST_TOWER_BALANCE.silence_seconds).is_equal(1.0)
	assert_int(BROADCAST_TOWER_BALANCE.fuses_needed).is_equal(1)


func test_grind_dial_balance_values() -> void:
	assert_bool(GRIND_DIAL_BALANCE is GrindDialBalance).is_true()
	# One full dial sweep takes about 1.4 seconds. A stopped-but-wrong grind
	# bottoms out above a miss: some grind is better than no grind.
	assert_float(GRIND_DIAL_BALANCE.marker_speed_units_per_second).is_equal(0.7)
	assert_float(GRIND_DIAL_BALANCE.hit_score).is_equal(100.0)
	assert_float(GRIND_DIAL_BALANCE.wrong_zone_penalty_per_unit).is_equal(100.0)
	assert_float(GRIND_DIAL_BALANCE.wrong_zone_floor_score).is_equal(30.0)
	assert_float(GRIND_DIAL_BALANCE.miss_score).is_equal(0.0)
	assert_float(GRIND_DIAL_BALANCE.wrong_zone_floor_score).is_greater(
		GRIND_DIAL_BALANCE.miss_score
	)


func test_pour_balance_values() -> void:
	assert_bool(POUR_BALANCE is PourBalance).is_true()
	# Section 8: a slow circle fills the ring. Inside the 0.55 to 0.85 rate
	# band the bloom fills in about 4 seconds. Full throttle pools 0.3 excess
	# per second and floods in about 3.3 seconds. A stalled bloom tops out
	# below the good-tier line, and a full circle in 2 seconds is rate 1.0.
	assert_float(POUR_BALANCE.sweet_spot_start).is_equal(0.55)
	assert_float(POUR_BALANCE.sweet_spot_end).is_equal(0.85)
	assert_float(POUR_BALANCE.fill_rate_per_second).is_equal(0.25)
	assert_float(POUR_BALANCE.dry_rate_per_second).is_equal(0.12)
	assert_float(POUR_BALANCE.flood_build_multiplier).is_equal(2.0)
	assert_float(POUR_BALANCE.drain_rate_per_second).is_equal(0.1)
	assert_float(POUR_BALANCE.flood_excess).is_equal(1.0)
	assert_float(POUR_BALANCE.brew_window_seconds).is_equal(10.0)
	assert_float(POUR_BALANCE.bloomed_score).is_equal(100.0)
	assert_float(POUR_BALANCE.excess_penalty_per_unit).is_equal(25.0)
	assert_float(POUR_BALANCE.flood_score).is_equal(0.0)
	assert_float(POUR_BALANCE.stalled_score_max).is_equal(40.0)
	assert_float(POUR_BALANCE.full_turn_seconds).is_equal(2.0)
	assert_float(POUR_BALANCE.sweet_spot_start).is_less(POUR_BALANCE.sweet_spot_end)
	assert_float(POUR_BALANCE.stalled_score_max).is_less(
		(
			POUR_BALANCE.bloomed_score
			- POUR_BALANCE.flood_excess * POUR_BALANCE.excess_penalty_per_unit
		)
	)


func test_press_balance_values() -> void:
	assert_bool(PRESS_BALANCE is PressBalance).is_true()
	# Section 8: hold the pressure in the green zone while it creeps, then
	# release at the exact mark. The needle bleeds faster than it builds, the
	# zone creeps to the top of the gauge but never off it inside the hold
	# window, a sour or bitter cup keeps a floor, and a no-shot press stays
	# below the good-tier line.
	assert_float(PRESS_BALANCE.pressure_build_per_second).is_equal(0.55)
	assert_float(PRESS_BALANCE.pressure_bleed_per_second).is_equal(0.75)
	assert_float(PRESS_BALANCE.pressure_max).is_equal(1.5)
	assert_float(PRESS_BALANCE.zone_start_center).is_equal(0.35)
	assert_float(PRESS_BALANCE.zone_width).is_equal(0.18)
	assert_float(PRESS_BALANCE.zone_creep_per_second).is_equal(0.045)
	assert_float(PRESS_BALANCE.hold_fill_per_second).is_equal(0.3)
	assert_float(PRESS_BALANCE.press_window_seconds).is_equal(12.0)
	assert_float(PRESS_BALANCE.release_mark_pressure).is_equal(0.95)
	assert_float(PRESS_BALANCE.perfect_tolerance).is_equal(0.05)
	assert_float(PRESS_BALANCE.pull_window_seconds).is_equal(4.0)
	assert_float(PRESS_BALANCE.pressed_score).is_equal(100.0)
	assert_float(PRESS_BALANCE.drift_penalty_per_second).is_equal(12.0)
	assert_float(PRESS_BALANCE.off_mark_penalty_per_unit).is_equal(140.0)
	assert_float(PRESS_BALANCE.off_mark_floor_score).is_equal(30.0)
	assert_float(PRESS_BALANCE.no_shot_score_max).is_equal(40.0)
	assert_float(PRESS_BALANCE.pressure_bleed_per_second).is_greater(
		PRESS_BALANCE.pressure_build_per_second
	)
	(
		assert_float(
			(
				PRESS_BALANCE.zone_start_center
				+ PRESS_BALANCE.zone_creep_per_second * PRESS_BALANCE.press_window_seconds
				+ PRESS_BALANCE.zone_width * 0.5
			)
		)
		. is_less_equal(1.0)
	)
	assert_float(PRESS_BALANCE.off_mark_floor_score).is_greater(0.0)
	assert_float(PRESS_BALANCE.no_shot_score_max).is_less(80.0)


func test_foam_watch_balance_values() -> void:
	assert_bool(FOAM_WATCH_BALANCE is FoamWatchBalance).is_true()
	# Section 8: the pot heats up and the foam rises. More foam gives a better
	# cup, but the pot can boil over: the rush makes the last stretch fast, the
	# grace window is the last safe moment, and both failure modes stay far
	# below the good-tier line.
	assert_float(FOAM_WATCH_BALANCE.heat_rate_per_second).is_equal(0.5)
	assert_float(FOAM_WATCH_BALANCE.foam_rate_per_second).is_equal(0.3)
	assert_float(FOAM_WATCH_BALANCE.rush_start_foam).is_equal(0.6)
	assert_float(FOAM_WATCH_BALANCE.rush_multiplier).is_equal(2.2)
	assert_float(FOAM_WATCH_BALANCE.boil_over_grace_seconds).is_equal(0.8)
	assert_float(FOAM_WATCH_BALANCE.lifted_score).is_equal(100.0)
	assert_float(FOAM_WATCH_BALANCE.boil_over_score).is_equal(0.0)
	assert_float(FOAM_WATCH_BALANCE.cold_score).is_equal(0.0)
	assert_float(FOAM_WATCH_BALANCE.rush_start_foam).is_less(FoamWatch.RIM_FOAM)
	var rush_rate: float = (
		FOAM_WATCH_BALANCE.foam_rate_per_second * FOAM_WATCH_BALANCE.rush_multiplier
	)
	assert_float(rush_rate).is_greater(FOAM_WATCH_BALANCE.foam_rate_per_second)
	assert_float(FOAM_WATCH_BALANCE.boil_over_score).is_less(80.0)
	assert_float(FOAM_WATCH_BALANCE.cold_score).is_less(80.0)
	assert_float(FOAM_WATCH_BALANCE.boil_over_grace_seconds).is_greater(0.0)


func test_mobile_cafe_balance_values() -> void:
	assert_bool(MOBILE_CAFE_BALANCE is MobileCafeBalance).is_true()
	# Section 10: three van levels; scrap parts pay for the upgrades, and the
	# field cafe reaches the survivors of a whole block.
	assert_int(MOBILE_CAFE_BALANCE.max_level).is_equal(3)
	assert_int(MOBILE_CAFE_BALANCE.kitchen_scrap_cost).is_equal(5)
	assert_int(MOBILE_CAFE_BALANCE.field_cafe_scrap_cost).is_equal(12)
	assert_float(MOBILE_CAFE_BALANCE.field_base_radius).is_equal(300.0)
	assert_object(MOBILE_CAFE_BALANCE.scrap_item).is_not_null()
	assert_str(MOBILE_CAFE_BALANCE.scrap_item.item_id).is_equal("scrap_part")


func test_sleep_jam_balance_values() -> void:
	assert_bool(SLEEP_JAM_BALANCE is SleepJamBalance).is_true()
	assert_float(SLEEP_JAM_BALANCE.lullaby_radius).is_equal(360.0)
	assert_str(SLEEP_JAM_BALANCE.wake_line).is_equal("Best set ever. What year is it?")


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
	assert_object(player.cluster_bomb_balance).is_not_null()
	assert_int(player.cluster_bomb_balance.max_charges).is_equal(CLUSTER_BOMB_BALANCE.max_charges)
	var sleepwalker := auto_free(NEIGHBOR_SCENE.instantiate()) as Sleepwalker
	assert_object(sleepwalker.balance).is_not_null()
	assert_float(sleepwalker.balance.walk_speed).is_equal(SLEEPWALKER_BALANCE.walk_speed)
	var tourist := auto_free(TOURIST_SCENE.instantiate()) as Sleepwalker
	assert_object(tourist.tourist_balance).is_not_null()
	assert_float(tourist.tourist_balance.flash_stun_seconds).is_equal(
		TOURIST_BALANCE.flash_stun_seconds
	)
	var tech_bro := auto_free(TECH_BRO_SCENE.instantiate()) as Sleepwalker
	assert_object(tech_bro.tech_bro_balance).is_not_null()
	assert_float(tech_bro.tech_bro_balance.bump_stun_seconds).is_equal(
		TECH_BRO_BALANCE.bump_stun_seconds
	)
	var gamer := auto_free(GAMER_SCENE.instantiate()) as Sleepwalker
	assert_object(gamer.gamer_balance).is_not_null()
	assert_float(gamer.gamer_balance.dash_speed).is_equal(GAMER_BALANCE.dash_speed)
	var karen := auto_free(KAREN_SCENE.instantiate()) as Sleepwalker
	assert_object(karen.karen_balance).is_not_null()
	assert_float(karen.karen_balance.sprint_speed).is_equal(KAREN_BALANCE.sprint_speed)
	assert_float(karen.karen_balance.lull_speed).is_equal(KAREN_BALANCE.lull_speed)
	var drone := tech_bro.get_node("Drone") as Drone
	assert_object(drone.balance).is_not_null()
	assert_float(drone.balance.dive_speed).is_equal(TECH_BRO_BALANCE.dive_speed)
	var cup := auto_free(COFFEE_CUP_SCENE.instantiate()) as CoffeeCup
	assert_object(cup.balance).is_not_null()
	assert_float(cup.balance.flight_time_seconds).is_equal(COFFEE_CUP_BALANCE.flight_time_seconds)
	var tower := auto_free(BROADCAST_TOWER_SCENE.instantiate()) as BroadcastTower
	assert_object(tower.balance).is_not_null()
	assert_float(tower.balance.silence_seconds).is_equal(BROADCAST_TOWER_BALANCE.silence_seconds)
	assert_int(tower.balance.fuses_needed).is_equal(BROADCAST_TOWER_BALANCE.fuses_needed)
	var dial := auto_free(GRIND_DIAL_SCENE.instantiate()) as GrindDialView
	assert_object(dial.balance).is_not_null()
	assert_float(dial.balance.marker_speed_units_per_second).is_equal(
		GRIND_DIAL_BALANCE.marker_speed_units_per_second
	)
	var pour := auto_free(POUR_SCENE.instantiate()) as PourBloomView
	assert_object(pour.balance).is_not_null()
	assert_float(pour.balance.fill_rate_per_second).is_equal(POUR_BALANCE.fill_rate_per_second)
	assert_float(pour.balance.full_turn_seconds).is_equal(POUR_BALANCE.full_turn_seconds)
	var press := auto_free(PRESS_SCENE.instantiate()) as PressShotView
	assert_object(press.balance).is_not_null()
	assert_float(press.balance.pressure_build_per_second).is_equal(
		PRESS_BALANCE.pressure_build_per_second
	)
	assert_float(press.balance.release_mark_pressure).is_equal(PRESS_BALANCE.release_mark_pressure)
	var watch := auto_free(FOAM_WATCH_SCENE.instantiate()) as FoamWatchView
	assert_object(watch.balance).is_not_null()
	assert_float(watch.balance.heat_rate_per_second).is_equal(
		FOAM_WATCH_BALANCE.heat_rate_per_second
	)
	assert_float(watch.balance.boil_over_grace_seconds).is_equal(
		FOAM_WATCH_BALANCE.boil_over_grace_seconds
	)
	var van := auto_free(MOBILE_CAFE_SCENE.instantiate()) as MobileCafeVan
	assert_object(van.balance).is_not_null()
	assert_int(van.balance.kitchen_scrap_cost).is_equal(MOBILE_CAFE_BALANCE.kitchen_scrap_cost)
	assert_float(van.balance.field_base_radius).is_equal(MOBILE_CAFE_BALANCE.field_base_radius)
	var tutorial := auto_free(TUTORIAL_SCENE.instantiate()) as TutorialDirector
	assert_object(tutorial.balance).is_not_null()
	assert_float(tutorial.balance.video_seconds).is_equal(TUTORIAL_BALANCE.video_seconds)
	# Only the intro run turns the tutorial on, section 19: the first ten
	# minutes play once, at the first run of the first city.
	var intro := auto_free(INTRO_SCENE.instantiate()) as CityRun
	assert_bool(intro.run_tutorial).is_true()
	var plain := auto_free(SAN_COFFESCO_SCENE.instantiate()) as CityRun
	assert_bool(plain.run_tutorial).is_false()


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
