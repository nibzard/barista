# ABOUTME: BrewHand is the brewed batch in the player's hand: the last brew's
# ABOUTME: payload and how many of its cups remain. Pure logic, no nodes.
class_name BrewHand
extends RefCounted

var _cup: BrewedCup = null
var _cups_left := 0


func receive(cup: BrewedCup, cups_added: int) -> bool:
	# A finished brew lands in the hand with the cups it earned. A brew with
	# no cup keeps nothing. A brew over an unspent batch replaces it; the
	# older cups stay in the supply count as plain cups.
	if cups_added <= 0 or cup == null:
		return false
	_cup = cup
	_cups_left = cups_added
	return true


func active_payload() -> BrewedCup:
	# The payload of the next cup out of the hand, or nothing while the hand
	# holds only plain cups from the pot.
	if _cups_left > 0:
		return _cup
	return null


func cups_left() -> int:
	return _cups_left


func consume() -> void:
	# One cup left the hand, so a brewed cup spent its turn before a plain
	# one. The last one empties the batch.
	if _cups_left <= 0:
		return
	_cups_left -= 1
	if _cups_left == 0:
		_cup = null


func save_state() -> Dictionary:
	# The save system stores the brewed batch in hand, section 18: the payload
	# of the last brew and how many of its cups remain. A hand of plain cups
	# holds no brew, so it stores nothing.
	if _cup == null or _cups_left <= 0:
		return {}
	return {
		"bean_id": _cup.bean.bean_id,
		"roast_id": _cup.roast.roast_id,
		"method_id": _cup.method.method_id,
		"extra_id": _cup.extra_id,
		"score": _cup.score,
		"cups_left": _cups_left,
	}


func load_state(saved: Dictionary, library: BrewingLibrary) -> void:
	# A loaded hand stands where it stood, silent. Unknown ids drop away, so a
	# data change never breaks a slot: the cups stay in the supply as plain
	# ones, and the payload is gone.
	_cup = null
	_cups_left = 0
	if library == null or saved.is_empty():
		return
	var bean := library.find_bean(str(saved.get("bean_id", "")))
	var roast := library.find_roast(str(saved.get("roast_id", "")))
	var method := library.find_method(str(saved.get("method_id", "")))
	var cups := maxi(0, int(saved.get("cups_left", 0)))
	if bean == null or roast == null or method == null or cups <= 0:
		return
	_cup = BrewedCup.new(
		bean, roast, method, str(saved.get("extra_id", "")), float(saved.get("score", 0.0))
	)
	_cups_left = cups
