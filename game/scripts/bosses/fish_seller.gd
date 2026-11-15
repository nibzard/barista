# ABOUTME: FishSeller is one body of the Fish Throwers crew, cup target and all.
# ABOUTME: The head fishmonger wears the apron that takes the market cure.
class_name FishSeller
extends StaticBody2D

# Exactly one seller in the market is the head fishmonger. The cure must land
# in his apron, section 6.
@export var is_head := false

# The market that this seller belongs to. The boss binds it on ready.
var crew: FishThrowers = null

var _awake := false


func bind_crew(market: FishThrowers) -> void:
	crew = market


func try_wake(cup: BrewedCup) -> bool:
	# A thrown cup that lands on a seller asks the market what it means. The
	# head-first rule lives there, not in the single seller.
	if crew == null:
		return false
	return crew.receive_cup(self, cup)


func set_awake(awake: bool) -> void:
	_awake = awake


func is_awake() -> bool:
	return _awake
