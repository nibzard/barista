# ABOUTME: Unit tests for the FishVolley clock of the Fish Throwers, T029.
# ABOUTME: Proves the steady rhythm, the seller order, and the perfect aim.
extends GdUnitTestSuite

const THROWER_COUNT := 4
const INTERVAL := 1.2
const BALANCE := preload("res://resources/balance/fish_throwers.tres")


func test_one_fish_per_beat_in_a_steady_rhythm() -> void:
	# The acceptance case for the volley pattern: every beat lasts the whole
	# interval, and every beat throws exactly one fish.
	var volley := FishVolley.new(THROWER_COUNT, INTERVAL)
	var fired: Array[int] = []
	for _beat: int in range(10):
		fired.append(volley.tick(INTERVAL))
	assert_int(fired.size()).is_equal(10)
	for fired_at: int in fired:
		assert_int(fired_at).is_greater_equal(0)


func test_no_fish_falls_inside_a_beat() -> void:
	# The steady rhythm never hurries: half-beat ticks stay silent until the
	# beat closes.
	var volley := FishVolley.new(THROWER_COUNT, INTERVAL)
	assert_int(volley.tick(INTERVAL * 0.5)).is_equal(-1)
	assert_int(volley.beats_passed()).is_equal(0)
	assert_int(volley.tick(INTERVAL * 0.5)).is_greater_equal(0)
	assert_int(volley.beats_passed()).is_equal(1)
	for _quarter: int in range(3):
		assert_int(volley.tick(INTERVAL * 0.25)).is_equal(-1)
	assert_int(volley.tick(INTERVAL * 0.25)).is_greater_equal(0)
	assert_int(volley.beats_passed()).is_equal(2)


func test_the_beats_cycle_the_sellers_in_order() -> void:
	# The volley pattern: the crew throws in seller order, back to the first
	# seller after the full crew, beat after beat.
	var volley := FishVolley.new(THROWER_COUNT, INTERVAL)
	var order: Array[int] = []
	for _beat: int in range(THROWER_COUNT * 2):
		order.append(volley.tick(INTERVAL))
	assert_array(order).is_equal([0, 1, 2, 3, 0, 1, 2, 3])


func test_thrower_for_beat_wraps_any_crew_size() -> void:
	assert_int(FishVolley.thrower_for_beat(1, 3)).is_equal(0)
	assert_int(FishVolley.thrower_for_beat(3, 3)).is_equal(2)
	assert_int(FishVolley.thrower_for_beat(4, 3)).is_equal(0)
	assert_int(FishVolley.thrower_for_beat(7, 3)).is_equal(0)
	assert_int(FishVolley.thrower_for_beat(9, 3)).is_equal(2)


func test_a_stalled_tick_fires_one_fish_and_the_beat_restarts() -> void:
	# A stall never bursts the rhythm: one tick that spans three beats throws
	# one fish, and the next full beat throws the next seller in line.
	var volley := FishVolley.new(THROWER_COUNT, INTERVAL)
	assert_int(volley.tick(INTERVAL * 3.0)).is_equal(0)
	assert_int(volley.beats_passed()).is_equal(1)
	assert_int(volley.tick(INTERVAL)).is_equal(1)
	assert_int(volley.beats_passed()).is_equal(2)


func test_perfect_aim_points_at_the_player_spot() -> void:
	# Perfect aim, section 6: the fish flies the exact line to the spot where
	# the player stands at the throw, with no lead and no scatter.
	var aim := FishVolley.aim(Vector2.ZERO, Vector2(30.0, 40.0))
	assert_vector(aim).is_equal(Vector2(0.6, 0.8))


func test_perfect_aim_works_from_any_stall() -> void:
	var aim := FishVolley.aim(Vector2(100.0, 20.0), Vector2(100.0, 50.0))
	assert_vector(aim).is_equal(Vector2(0.0, 1.0))


func test_a_seller_standing_on_the_player_holds_the_fish() -> void:
	# They never drop a fish: with no line to throw, the seller holds it.
	var aim := FishVolley.aim(Vector2(40.0, 40.0), Vector2(40.0, 40.0))
	assert_vector(aim).is_equal(Vector2.ZERO)


func test_the_balance_pins_the_market_rhythm() -> void:
	# The tuned numbers of the fight, from the balance resource: one fish per
	# beat every 1.2 seconds, at a speed the player can dodge sideways.
	assert_bool(BALANCE is FishThrowersBalance).is_true()
	assert_float(BALANCE.volley_interval_seconds).is_equal(1.2)
	assert_float(BALANCE.fish_speed).is_equal(300.0)
	assert_float(BALANCE.fish_flight_range).is_equal(520.0)
	assert_float(BALANCE.fish_stun_seconds).is_equal(0.35)
	assert_float(BALANCE.volley_trigger_radius).is_equal(300.0)
	assert_str(BALANCE.cheer_line).is_equal("Fresh fish! One last throw for the morning market!")
