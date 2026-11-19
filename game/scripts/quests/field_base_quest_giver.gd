# ABOUTME: FieldBaseQuestGiver is the world half of the field base side quests:
# ABOUTME: the gathered survivor that asks, and the one button that answers.
class_name FieldBaseQuestGiver
extends Node2D

const OFFER_TOAST := "A SURVIVOR ASKS: BRING %d HOUSE BEANS FOR THE FIELD KITCHEN."
const ACCEPT_TOAST := "THE FIELD KITCHEN STOCK IS ON. BRING %d HOUSE BEANS TO THE VAN."
const DELIVER_TOAST := "THE FIELD KITCHEN BREWS AGAIN. THE SURVIVORS GIVE %d SCRAP PARTS."
const ASK_LINE := "The field kitchen runs dry. Beans, barista. Beans."

# The ask label rides above the asking survivor, like the tutorial line.
const ASK_LABEL_WIDTH := 300.0
const ASK_LABEL_HEIGHT := 56.0
const ASK_LABEL_TEXT_SIZE := 18
const ASK_LABEL_COLOR := Color(0.96, 0.93, 0.85, 1.0)
const ASK_LABEL_OFFSET := Vector2(0.0, -64.0)

@export var balance: FieldBaseQuestBalance
@export var definition: SideQuestDefinition

var quests: FieldBaseQuests = null

# The run arrives as a plain Node: naming the run class here would tie the
# giver's compile back into the city script (T112).
var _run: Node = null
var _ask_label: Label


func _ready() -> void:
	quests = FieldBaseQuests.new(balance, definition)
	_compose_ask_label()


func setup(run: Node) -> void:
	# The giver binds to the run and registers the round into its quest log,
	# beside the signature quests of the route, section 12.
	_run = run
	quests.register(run.quest_log)
	quests.phase_changed.connect(_on_phase_changed)


func _physics_process(_delta: float) -> void:
	if _run == null or quests == null:
		return
	var van: MobileCafeVan = _run.van()
	var field_base_open: bool = van != null and van.is_field_base_open()
	var gathered: Array[Sleepwalker] = []
	if field_base_open:
		gathered = van.gathered_survivors()
	quests.poll(_run.quest_log, gathered.size(), field_base_open)
	if quests.is_asking() and not gathered.is_empty():
		global_position = gathered[0].global_position + ASK_LABEL_OFFSET


func try_interact(player: Player) -> bool:
	# One button answers the survivor at the van: yes to the ask, then the
	# beans once the bag holds them. Returns true when the press was consumed,
	# so the van keeps its key otherwise, section 10.
	if _run == null or quests == null or player == null:
		return false
	var van: MobileCafeVan = _run.van()
	if van == null or not van.is_field_base_open() or not van.is_player_at_van():
		return false
	if quests.is_asking():
		var gathered_count: int = van.gathered_survivors().size()
		if not quests.try_accept(_run.quest_log, gathered_count, true):
			return false
		_run.hud.show_toast(ACCEPT_TOAST % quests.beans_goal())
		return true
	if not quests.try_deliver(_run.quest_log, player.inventory, true):
		return false
	_run.hud.show_toast(DELIVER_TOAST % quests.reward_scrap_parts())
	return true


func ask_line() -> String:
	return ASK_LINE


func is_ask_visible() -> bool:
	return _ask_label != null and _ask_label.visible


func _on_phase_changed(new_phase: int) -> void:
	# The ask appears with the asking phase: the survivor speaks above the
	# tables, and one toast names the small favor. Every other phase hides
	# the line.
	if new_phase == FieldBaseQuests.Phase.ASKING:
		_ask_label.text = ASK_LINE
		_ask_label.visible = true
		_run.hud.show_toast(OFFER_TOAST % quests.beans_goal())
		return
	_ask_label.visible = false


func _compose_ask_label() -> void:
	_ask_label = Label.new()
	_ask_label.position = Vector2(-ASK_LABEL_WIDTH * 0.5, -ASK_LABEL_HEIGHT * 0.5)
	_ask_label.size = Vector2(ASK_LABEL_WIDTH, ASK_LABEL_HEIGHT)
	_ask_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ask_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ask_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ask_label.add_theme_font_size_override("font_size", ASK_LABEL_TEXT_SIZE)
	_ask_label.add_theme_color_override("font_color", ASK_LABEL_COLOR)
	_ask_label.visible = false
	add_child(_ask_label)
