# ABOUTME: QuestMarkers renders the quest markers of the city run: one ring on
# ABOUTME: the main objective and one dot per active side quest. QuestLog
# ABOUTME: signals drive it; the layer draws only what the log says.
class_name QuestMarkers
extends Node2D

# The markers ride above the city blocks and the crowd.
const MARKER_Z_INDEX := 40
const OBJECTIVE_RING_RADIUS := 64.0
const OBJECTIVE_RING_WIDTH := 6.0
const OBJECTIVE_RING_COLOR := Color(0.98, 0.83, 0.25, 0.85)
const OBJECTIVE_RING_SEGMENTS := 48
const SIDE_DOT_RADIUS := 10.0
const SIDE_DOT_COLOR := Color(0.55, 0.9, 0.5, 0.85)
const LABEL_TEXT_SIZE := 22
const LABEL_COLOR := Color(0.99, 0.87, 0.35, 1)
const LABEL_GAP := 24.0
const EDGE_MARGIN := 48.0
const EDGE_ARROW_SIZE := 16.0
# The road-east marker floats past the east edge of the last block.
const ROAD_EAST_OFFSET := Vector2(60.0, 0.0)
const TOWER_LABEL := "THE TOWER"
const BOSS_FALLBACK_LABEL := "THE BOSS"
const ROAD_EAST_LABEL := "THE ROAD EAST"

var _log: QuestLog = null
var _map: CityMap = null
var _objective: MainQuest.Objective = MainQuest.Objective.TOWER
var _has_objective_target := false
var _objective_position := Vector2.ZERO
var _objective_label := ""
var _side_positions: Array[Vector2] = []
var _suppressed := false
var _last_view_center := Vector2.INF


func _ready() -> void:
	z_index = MARKER_Z_INDEX


func _process(_delta: float) -> void:
	# Redraw the off-screen objective arrow as the camera moves across the city.
	if not _has_objective_target:
		return
	var center := _view_rect().get_center()
	if center != _last_view_center:
		_last_view_center = center
		queue_redraw()


func bind(quest_log: QuestLog, map: CityMap) -> void:
	_log = quest_log
	_map = map
	_log.objective_changed.connect(_on_objective_changed)
	_log.side_quest_changed.connect(_on_side_quest_changed)
	_refresh_objective()
	_refresh_side_quests()
	queue_redraw()


func has_objective_marker() -> bool:
	return _has_objective_target


func set_suppressed(suppressed: bool) -> void:
	# Section 19 step 7: the tutorial hides every marker until the survivor at
	# the door names the tower. The release redraws from the quest log alone.
	if _suppressed == suppressed:
		return
	_suppressed = suppressed
	_refresh_objective()
	_refresh_side_quests()
	queue_redraw()


func is_suppressed() -> bool:
	return _suppressed


func objective_marker_position() -> Vector2:
	return _objective_position


func objective_marker_label() -> String:
	return _objective_label


func side_marker_positions() -> Array[Vector2]:
	return _side_positions.duplicate()


func _on_objective_changed(_objective: MainQuest.Objective) -> void:
	_refresh_objective()
	queue_redraw()


func _on_side_quest_changed(_quest_id: String, _new_state: int) -> void:
	_refresh_side_quests()
	queue_redraw()


func _refresh_objective() -> void:
	# Section 19 step 7: the marker sits on the tower first, then on the boss
	# arena, then on the open road east. A route with no next city shows no
	# road marker. A suppressed layer shows nothing at all.
	_has_objective_target = false
	_objective_label = ""
	if _suppressed or _log == null or _map == null:
		return
	_objective = _log.current_objective()
	match _objective:
		MainQuest.Objective.TOWER:
			var tower := _map.broadcast_tower()
			if tower != null:
				_set_objective_target(tower.global_position, TOWER_LABEL)
		MainQuest.Objective.BOSS:
			var arena := _map.find_block_of_kind(CityBlock.Kind.BOSS_ARENA)
			if arena != null:
				_set_objective_target(_block_center(arena), _boss_label())
		MainQuest.Objective.ROAD_EAST:
			if not _log.main_quest.next_city().is_empty():
				var bounds := _map.city_size()
				_set_objective_target(
					Vector2(bounds.x, bounds.y * 0.5) + ROAD_EAST_OFFSET, ROAD_EAST_LABEL
				)


func _refresh_side_quests() -> void:
	# Every active side quest of this city marks its site: the named place of
	# the goal, or the signature quest landmark when the data names no site.
	# A quest of another city gets no marker here.
	_side_positions.clear()
	if _suppressed or _log == null or _map == null or _map.definition == null:
		return
	for quest: SideQuest in _log.active_side_quests():
		if quest.definition == null or quest.definition.city_id != _map.definition.city_id:
			continue
		var anchor := _site_anchor(quest.site_name())
		if anchor == null:
			continue
		_side_positions.append(_anchor_position(anchor))


func _set_objective_target(position: Vector2, label: String) -> void:
	_has_objective_target = true
	_objective_position = position
	_objective_label = label


func _boss_label() -> String:
	if _map.definition == null or _map.definition.boss_name.is_empty():
		return BOSS_FALLBACK_LABEL
	return _map.definition.boss_name.to_upper()


func _site_anchor(site_name: String) -> Node2D:
	# A named site must stand on this city map. An empty site name means the
	# signature quest landmark of the city.
	if not site_name.is_empty():
		var view := _map.find_quest_site(site_name)
		if view == null or view.quest_site_marker() == null:
			return null
		return view.quest_site_marker()
	return _map.find_block_of_kind(CityBlock.Kind.QUEST)


func _anchor_position(anchor: Node2D) -> Vector2:
	var view := anchor as CityBlockView
	if view != null:
		return _block_center(view)
	return anchor.global_position


func _block_center(view: CityBlockView) -> Vector2:
	return view.global_position + view.size * 0.5


func _draw() -> void:
	if _has_objective_target:
		_draw_objective()
	for position: Vector2 in _side_positions:
		draw_circle(position, SIDE_DOT_RADIUS, SIDE_DOT_COLOR)


func _draw_objective() -> void:
	var view := _view_rect()
	if view.has_point(_objective_position):
		draw_arc(
			_objective_position,
			OBJECTIVE_RING_RADIUS,
			0.0,
			TAU,
			OBJECTIVE_RING_SEGMENTS,
			OBJECTIVE_RING_COLOR,
			OBJECTIVE_RING_WIDTH
		)
		_draw_label(
			_objective_position + Vector2(0.0, -OBJECTIVE_RING_RADIUS - LABEL_GAP), _objective_label
		)
		return
	_draw_edge_arrow(_objective_position, view)


func _draw_label(at: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_TEXT_SIZE).x
	draw_string(
		font,
		at + Vector2(-width * 0.5, 0.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_TEXT_SIZE,
		LABEL_COLOR
	)


func _draw_edge_arrow(target: Vector2, view: Rect2) -> void:
	# The target sits far off screen: the arrow stands at the screen edge and
	# points the way, like the far tower marker of section 19 step 7.
	var center := view.get_center()
	var direction := (target - center).normalized()
	if direction == Vector2.ZERO:
		return
	var inner_half := view.size * 0.5 - Vector2(EDGE_MARGIN + 28.0, EDGE_MARGIN + 16.0)
	var edge := _ray_exit(center, direction, inner_half)
	var side := Vector2(-direction.y, direction.x) * (EDGE_ARROW_SIZE * 1.25)
	var tip := edge + direction * (EDGE_ARROW_SIZE * 1.45)
	draw_colored_polygon(PackedVector2Array([tip, edge + side, edge - side]), OBJECTIVE_RING_COLOR)
	if not _objective_label.is_empty():
		var meters := maxi(1, roundi(center.distance_to(target) / 16.0))
		var text := "%s (%dm)" % [_objective_label, meters]
		var label_pos := edge - direction * 86.0 + Vector2(0.0, 6.0)
		_draw_label(label_pos, text)


func _ray_exit(center: Vector2, direction: Vector2, half: Vector2) -> Vector2:
	# The point where the ray from the center leaves a rect with these half
	# extents.
	var distance := INF
	if absf(direction.x) > 0.0001:
		distance = minf(distance, half.x / absf(direction.x))
	if absf(direction.y) > 0.0001:
		distance = minf(distance, half.y / absf(direction.y))
	if distance == INF:
		return center
	return center + direction * distance


func _view_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var half := viewport.get_visible_rect().size * 0.5
	var camera := viewport.get_camera_2d()
	if camera == null:
		return Rect2(-half, half * 2.0)
	return Rect2(camera.get_screen_center_position() - half, half * 2.0)
