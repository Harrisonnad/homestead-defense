extends Node

# Autoload singleton: season win/lose state. Winning = surviving
# season_length_days nights (i.e. reaching the following dawn); losing =
# the Homestead's health reaching zero (it calls lose()). Restart resets
# every stateful autoload before reloading the scene, since autoloads
# survive a scene reload.

@export var season_length_days: int = 20

var ended: bool = false

signal game_ended(won: bool, day: int)

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

func restart() -> void:
	ended = false
	GameClock.reset()
	Economy.reset()
	Progression.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
