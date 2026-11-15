# ABOUTME: BrewingBalance holds the cup-tier thresholds as a typed resource.
# ABOUTME: The numbers live in game/resources/brewing/brewing_balance.tres.
class_name BrewingBalance
extends Resource

@export var good_tier_min_score: float
@export var perfect_tier_min_score: float
@export var perfect_wake_radius: float
@export var standard_cup_score: float

@export var max_method_skill: int
@export var good_brew_skill_gain: int
@export var perfect_brew_skill_gain: int
@export var master_lesson_skill_gain: int
# Section 14: every master teaches this many lessons.
@export var lessons_per_master: int
@export var auto_brew_score: float
