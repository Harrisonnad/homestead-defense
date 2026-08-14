extends Node

# Autoload singleton: season win/lose state and population cap. Winning =
# surviving season_length_days nights (i.e. reaching the following dawn);
# losing = the Homestead's health reaching zero (it calls lose()). Restart
# resets every stateful autoload before reloading the scene, since autoloads
# survive a scene reload.

const BASE_POPULATION_CAP := 3
const DIFFICULTIES := ["easy", "normal", "hard"]
# Seasonal enemy identity (master spec §5.7) - 4 even quarters of the whole
# 20-day season (a different "season" than the word used everywhere else
# in this file - that one means "the whole playthrough arc," this is a
# spring/summer/fall/winter subdivision of it). Backs WaveSpawner's
# seasonal composition (Locust Swarm in summer, Wolf Pack in winter) - no
# UI surface yet, purely a wave-composition input.
const SEASONS := ["spring", "summer", "fall", "winter"]

@export var season_length_days: int = 20

var ended: bool = false
var population_cap: int = BASE_POPULATION_CAP

# Set by main_menu.gd's New Game flow before the scene change, same pattern
# as SaveManager.pending_load - consumed once by MapBuilder._ready() (seed)
# and WaveSpawner._ready() (difficulty), then left alone for the rest of
# the season. pending_seed = 0 means "random," matching MapBuilder's own
# seed_override convention.
var pending_seed: int = 0
var difficulty: String = "normal"

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

func current_season() -> String:
	var quarter_length: float = season_length_days / float(SEASONS.size())
	var index := clampi(int((GameClock.day_count - 1) / quarter_length), 0, SEASONS.size() - 1)
	return SEASONS[index]

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
	AchievementManager.reset()
	NightReport.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()
