extends Node

# Autoload singleton: season win/lose state and population cap. Winning =
# surviving season_length_days nights (i.e. reaching the following dawn);
# losing = the Homestead's health reaching zero (it calls lose()). Restart
# resets every stateful autoload before reloading the scene, since autoloads
# survive a scene reload.

const BASE_POPULATION_CAP := 3

@export var season_length_days: int = 20

var ended: bool = false
var population_cap: int = BASE_POPULATION_CAP

signal game_ended(won: bool, day: int)
signal population_cap_changed(new_cap: int)

func _ready() -> void:
	GameClock.day_started.connect(_on_day_started)

func _on_day_started(day_count: int) -> void:
	if not ended and day_count > season_length_days:
		ended = true
		game_ended.emit(true, season_length_days)

func lose() -> void:
	if ended:
		return
	ended = true
	game_ended.emit(false, GameClock.day_count)

func current_population() -> int:
	return get_tree().get_nodes_in_group("villagers").size()

func has_population_room() -> bool:
	return current_population() < population_cap

func add_population_cap(bonus: int) -> void:
	population_cap += bonus
	population_cap_changed.emit(population_cap)

func restart() -> void:
	ended = false
	population_cap = BASE_POPULATION_CAP
	GameClock.reset()
	Economy.reset()
	Progression.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
