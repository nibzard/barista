# ABOUTME: Unit tests for the stubbed purchase interface behind the paywall.
# ABOUTME: The one payment of section 4; the real billing is backlog T053.
extends GdUnitTestSuite


func test_the_stub_grants_the_one_payment_at_once() -> void:
	var state := UnlockState.new()
	var gateway := PurchaseGateway.new()
	var grants: Array[int] = []
	gateway.purchase_granted.connect(func() -> void: grants.append(1))

	assert_bool(gateway.begin_purchase(state)).is_true()
	assert_bool(state.is_unlocked()).is_true()
	assert_int(grants.size()).is_equal(1)


func test_a_repeated_call_grants_nothing() -> void:
	# One payment unlocks the full game: a paid state answers no second grant.
	var state := UnlockState.new()
	state.unlock()
	var gateway := PurchaseGateway.new()
	var grants: Array[int] = []
	gateway.purchase_granted.connect(func() -> void: grants.append(1))

	assert_bool(gateway.begin_purchase(state)).is_false()
	assert_bool(state.is_unlocked()).is_true()
	assert_int(grants.size()).is_equal(0)


func test_a_missing_state_changes_nothing() -> void:
	var gateway := PurchaseGateway.new()
	var grants: Array[int] = []
	gateway.purchase_granted.connect(func() -> void: grants.append(1))

	assert_bool(gateway.begin_purchase(null)).is_false()
	assert_int(grants.size()).is_equal(0)
