# ABOUTME: PurchaseGateway is the stubbed purchase interface behind the paywall.
# ABOUTME: The one payment of section 4 lands here; the real billing is T053.
class_name PurchaseGateway
extends RefCounted

signal purchase_granted


func begin_purchase(state: UnlockState) -> bool:
	# The stub stands in for the store sheet: the payment lands inside the
	# same call, so the free city plays whole without any store account. The
	# real billing of T053 answers this call with the store flow and grants
	# through the same signal, so the gate and the run never change. Returns
	# true only when this call granted the payment.
	if state == null or state.is_unlocked():
		return false
	state.unlock()
	purchase_granted.emit()
	return true
