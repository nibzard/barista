# ABOUTME: PitchHallArt dresses the Sam Oatman hall: the slide screen and the demo table.
# ABOUTME: Presentation only: it sits on a placeholder polygon and reads its color for state.
class_name PitchHallArt
extends Node2D

enum Kind { SCREEN, TABLE }

const NODE_NAME := "PitchHallArt"
const FRAME_COLOR := Color("#1E1A24")
const INK := Color("#3B2418")
const SLIDE_RED := Color("#C8102E")
const CLOTH := Color("#2B2B33")
const CLOTH_LIGHT := Color("#4A4A57")
const SLIDE_TITLE := "SYNERGY Q4"

var kind := Kind.SCREEN
# The parent color that means the slides show. The screen polls it, so the
# boss script keeps its plain color writes.
var lit_color := Color.WHITE

var _body: Polygon2D = null
var _lit := false
var _synced := false


static func attach(body: Polygon2D, art_kind: Kind, lit := Color.WHITE) -> PitchHallArt:
	if body == null:
		return null
	var existing := body.get_node_or_null(NodePath(NODE_NAME)) as PitchHallArt
	if existing != null:
		return existing
	var art := PitchHallArt.new()
	art.name = NODE_NAME
	art.kind = art_kind
	art.lit_color = lit
	body.add_child(art)
	return art


func _ready() -> void:
	_body = get_parent() as Polygon2D
	_sync()


func _process(_delta: float) -> void:
	_sync()


func is_lit() -> bool:
	return _lit


func _sync() -> void:
	if _body == null:
		return
	var lit := _body.color.is_equal_approx(lit_color)
	if _synced and lit == _lit:
		return
	_synced = true
	_lit = lit
	queue_redraw()


func _draw() -> void:
	if _body == null or _body.polygon.is_empty():
		return
	var rect := _bounds(_body.polygon)
	if kind == Kind.SCREEN:
		_draw_screen(rect)
	else:
		_draw_table(rect)


func _draw_screen(rect: Rect2) -> void:
	# A projector screen in a black frame. The lit slide is the most boring
	# slide in the world: a title, three bullets, and a chart that only rises.
	draw_rect(rect.grow(6.0), FRAME_COLOR)
	draw_rect(rect, _body.color)
	if not _lit:
		draw_line(
			rect.position + Vector2(20.0, 16.0),
			rect.position + Vector2(70.0, 16.0),
			Color(1.0, 1.0, 1.0, 0.08),
			3.0
		)
		return
	var pad := 18.0
	draw_string(
		ChalkTheme.display_font(),
		rect.position + Vector2(pad, pad + 20.0),
		SLIDE_TITLE,
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x * 0.6,
		22,
		INK
	)
	draw_line(
		rect.position + Vector2(pad, pad + 30.0),
		rect.position + Vector2(rect.size.x * 0.55, pad + 30.0),
		SLIDE_RED,
		3.0
	)
	for i: int in 3:
		var y := rect.position.y + pad + 52.0 + float(i) * 24.0
		draw_circle(Vector2(rect.position.x + pad + 4.0, y), 3.5, INK)
		draw_line(
			Vector2(rect.position.x + pad + 14.0, y),
			Vector2(rect.position.x + pad + 14.0 + 90.0 - float(i) * 18.0, y),
			Color(INK, 0.55),
			4.0
		)
	var base := Vector2(rect.end.x - pad - 100.0, rect.end.y - pad)
	for bar: int in 4:
		var height := 18.0 + 22.0 * float(bar)
		var bar_rect := Rect2(base + Vector2(bar * 25.0, -height), Vector2(18.0, height))
		draw_rect(bar_rect, SLIDE_RED if bar == 3 else Color(INK, 0.45))
	draw_line(base, base + Vector2(100.0, 0.0), INK, 2.0)


func _draw_table(rect: Rect2) -> void:
	# The demo table wears a dark cloth with one red product mat on top.
	draw_rect(Rect2(rect.position + Vector2(-6.0, 6.0), rect.size), Color(0.2, 0.22, 0.32, 0.3))
	draw_rect(rect, CLOTH)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), CLOTH_LIGHT)
	for fold: float in [0.25, 0.5, 0.75]:
		var x := rect.position.x + rect.size.x * fold
		draw_line(Vector2(x, rect.position.y + 7.0), Vector2(x, rect.end.y), CLOTH_LIGHT, 1.0)
	var mat := Rect2(rect.get_center() - Vector2(12.0, 6.0), Vector2(24.0, 8.0))
	draw_rect(mat, SLIDE_RED)
	draw_rect(rect, INK, false, 2.0)


static func _bounds(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect
