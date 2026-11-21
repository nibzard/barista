# ABOUTME: PersonFigure dresses a placeholder body polygon as a drawn chibi person.
# ABOUTME: It reads the body color to show sleep or wake, so the game logic stays unchanged.
class_name PersonFigure
extends Node2D

const NODE_NAME := "PersonFigure"
# Every placeholder sleeper uses this pajama indigo until the wake tints it.
const DEFAULT_SLEEP_COLOR := Color(0.42, 0.38, 0.72)

# The name that picks a stable skin and hair, see ChibiPainter.look_for.
var look_key := ""
# The clothes color once the person is awake.
var outfit := Color.WHITE
var sleep_color := DEFAULT_SLEEP_COLOR
var gear := ChibiPainter.Gear.NONE

var _body: Polygon2D = null
var _awake := false
var _synced := false


static func dress(
	body: Polygon2D,
	key: String,
	outfit_color: Color,
	gear_item: ChibiPainter.Gear,
	figure_scale := 1.0
) -> PersonFigure:
	# The body polygon keeps its color, collision role, and every reference,
	# but stops drawing: only the figure shows. Older placeholder details on
	# the body, like a vest rectangle, hide with it.
	if body == null:
		return null
	var existing := body.get_node_or_null(NodePath(NODE_NAME)) as PersonFigure
	if existing != null:
		return existing
	var figure := PersonFigure.new()
	figure.name = NODE_NAME
	figure.look_key = key
	figure.outfit = outfit_color
	figure.gear = gear_item
	figure.scale = Vector2.ONE * figure_scale
	body.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	for child: Node in body.get_children():
		if child is Polygon2D:
			(child as Polygon2D).visible = false
	body.add_child(figure)
	return figure


static func celebrate(body: Node2D) -> void:
	# The pop of light of a live wake. A save restore never calls this, so a
	# reload stays quiet.
	if body == null:
		return
	var burst := WakeBurst.new()
	burst.name = "WakeBurst"
	body.add_child(burst)


func _ready() -> void:
	_body = get_parent() as Polygon2D
	_sync()


func _process(_delta: float) -> void:
	_sync()


func is_awake() -> bool:
	return _awake


func _sync() -> void:
	if _body == null:
		return
	var awake := not _body.color.is_equal_approx(sleep_color)
	if _synced and awake == _awake:
		return
	_synced = true
	_awake = awake
	queue_redraw()


func _draw() -> void:
	ChibiPainter.paint(self, outfit if _awake else sleep_color, look_key, gear, _awake)
