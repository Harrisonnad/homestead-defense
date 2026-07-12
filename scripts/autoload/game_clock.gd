extends Node

# Autoload singleton: owns time-of-day/day-count state and emits signals when
# the day/night phase flips, so any system (visuals, spawner, HUD) can react
# without depending on the Main scene tree.

@export var day_length_seconds: float = 60.0

var time_of_day: float = 0.3 # seeded past sunrise so no spurious signal fires on frame 1
var day_count: int = 1

signal day_started(day_count: int)
signal night_started()

func _process(delta: float) -> void:
	var was_day := is_daytime()
	time_of_day += delta / day_length_seconds
	if time_of_day >= 1.0:
		time_of_day -= 1.0

	var now_day := is_daytime()
	if now_day and not was_day:
		day_count += 1
		day_started.emit(day_count)
	elif was_day and not now_day:
		night_started.emit()

func reset() -> void:
	time_of_day = 0.3
	day_count = 1

func day_factor() -> float:
	return (1.0 - cos(time_of_day * TAU)) / 2.0

func is_daytime() -> bool:
	return day_factor() > 0.5
