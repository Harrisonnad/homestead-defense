extends Node3D

# Visual responder only: reads GameClock and drives sun angle, sun color, and
# sky color. Time-of-day/day-count state itself lives in the GameClock autoload.

@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment

const SKY_DAY := Color(0.55, 0.75, 0.95)
const SKY_NIGHT := Color(0.04, 0.05, 0.12)
const SUN_DAY := Color(1.0, 0.95, 0.8)
const SUN_NIGHT := Color(0.15, 0.2, 0.4)

func _process(_delta: float) -> void:
	var factor := GameClock.day_factor()
	sun.rotation.x = GameClock.time_of_day * TAU - PI / 2.0
	sun.light_energy = lerp(0.05, 1.2, factor)
	sun.light_color = SUN_NIGHT.lerp(SUN_DAY, factor)
	world_environment.environment.background_color = SKY_NIGHT.lerp(SKY_DAY, factor)
