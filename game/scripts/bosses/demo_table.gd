# ABOUTME: DemoTable is the product table of the Sam Oatman keynote.
# ABOUTME: The one place the cure lands: a cup set down like a product sample.
class_name DemoTable
extends StaticBody2D

# The show that owns this table. The boss binds it on ready.
var keynote: SamOatman = null


func _ready() -> void:
	add_to_group(CureDelivery.WAKEABLE_GROUP)


func bind_show(show: SamOatman) -> void:
	keynote = show


func is_awake() -> bool:
	return keynote != null and keynote.is_cured()


func try_wake(cup: BrewedCup) -> bool:
	# A cup that lands on the demo table asks the show what it means: the
	# right brew becomes the next product, the wrong one washes off.
	if keynote == null:
		return false
	return keynote.receive_cup(cup)
