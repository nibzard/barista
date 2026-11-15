# ABOUTME: BrewingMaster is one brewing master of section 8 as data.
# ABOUTME: One fixed role, one fixed lesson, three lessons at the school.
class_name BrewingMaster
extends Resource

@export var master_id: String
@export var display_name: String
# The city the master lives in. Each V1 master lives in a different city.
@export var city_id: String
# The one line the master says all the time, like the "Ultimately..." of
# James Offmug.
@export var catchphrase: String
# The one fixed role of the master, like "He teaches the V60 pour-over."
@export var role_line: String
# The one fixed lesson. The master speaks it at every lesson.
@export var lesson_line: String
# Placeholder robe color until the art pass replaces the shapes.
@export var accent_color := Color.WHITE
# The methods the master teaches, by method id. One lesson trains every
# taught method.
@export var taught_methods: Array[String] = []
# The recipes the master grants, in lesson order: entry N arrives with
# lesson N. An empty id grants nothing for that lesson.
@export var lesson_recipes: Array[String] = []
