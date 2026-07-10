extends Node3D

# Phase 0 scaffolding: drives sun angle, sun color, and sky color on a timer
# so a full day/night cycle is visible end-to-end without any gameplay yet.

@export var day_length_seconds: float = 60.0

@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment

var time_of_day: float = 0.25 # 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset
var day_count: int = 1

const SKY_DAY := Color(0.55, 0.75, 0.95)
const SKY_NIGHT := Color(0.04, 0.05, 0.12)
const SUN_DAY := Color(1.0, 0.95, 0.8)
const SUN_NIGHT := Color(0.15, 0.2, 0.4)

func _process(delta: float) -> void:
	time_of_day += delta / day_length_seconds
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day_count += 1
		print("Day %d begins" % day_count)

	var factor := day_factor()
	sun.rotation.x = time_of_day * TAU - PI / 2.0
	sun.light_energy = lerp(0.05, 1.2, factor)
	sun.light_color = SUN_NIGHT.lerp(SUN_DAY, factor)
	world_environment.environment.background_color = SKY_NIGHT.lerp(SKY_DAY, factor)

func day_factor() -> float:
	return (1.0 - cos(time_of_day * TAU)) / 2.0

func is_daytime() -> bool:
	return day_factor() > 0.5
