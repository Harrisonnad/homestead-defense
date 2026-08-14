extends Node3D

# Visual responder only: reads GameClock and drives sun angle, sun color, and
# sky color. Time-of-day/day-count state itself lives in the GameClock autoload.

@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment

const SKY_DAY := Color(0.55, 0.75, 0.95)
const SKY_NIGHT := Color(0.04, 0.05, 0.12)
const SUN_DAY := Color(1.0, 0.95, 0.8)
const SUN_NIGHT := Color(0.15, 0.2, 0.4)
const FOG_NIGHT := Color(0.05, 0.06, 0.1)
const AMBIENT_DAY := Color(0.5, 0.55, 0.6) # neutral fill, close to the old implicit sky-derived ambient
const AMBIENT_NIGHT := Color(0.25, 0.28, 0.35) # violet fill, night-only (see below)

# Seasonal identity (visual counterpart to GameState.current_season(), which
# already drives wave composition - see map_builder.gd's matching terrain
# palette). A gentle daytime sky/fog tint per season, blended on top of the
# existing day/night lerp rather than replacing it - night colors stay
# constant across seasons (the fungal-world night identity, §4, isn't
# seasonal, only the daytime look shifts). Summer matches the pre-existing
# SKY_DAY/fog values exactly, so a summer day looks identical to before this
# change.
const SEASON_SKY_DAY := {
	"spring": Color(0.65, 0.85, 0.92),
	"summer": Color(0.55, 0.75, 0.95),
	"fall": Color(0.62, 0.62, 0.7),
	"winter": Color(0.75, 0.8, 0.88),
}
const SEASON_FOG_DAY := {
	"spring": Color(0.75, 0.82, 0.75),
	"summer": Color(0.7, 0.75, 0.78),
	"fall": Color(0.78, 0.68, 0.55),
	"winter": Color(0.85, 0.87, 0.9),
}

func _ready() -> void:
	if SaveManager.pending_load:
		SaveManager.pending_load = false
		SaveManager.load_game.call_deferred()

func _process(_delta: float) -> void:
	var factor := GameClock.day_factor()
	sun.rotation.x = GameClock.time_of_day * TAU - PI / 2.0
	# Night floor raised from 0.05 -> 0.14 (see scripts/night_light.gd) so the
	# world isn't pure black between buildings' light pools - still a strong
	# day/night contrast (1.2 at noon), just enough ambient baseline that the
	# core night-defense gameplay is readable without a NightLight nearby.
	sun.light_energy = lerp(0.14, 1.2, factor)
	sun.light_color = SUN_NIGHT.lerp(SUN_DAY, factor)
	var season := GameState.current_season()
	var sky_day: Color = SEASON_SKY_DAY.get(season, SKY_DAY)
	var fog_day: Color = SEASON_FOG_DAY.get(season, Color(0.7, 0.75, 0.78))
	world_environment.environment.background_color = SKY_NIGHT.lerp(sky_day, factor)
	world_environment.environment.fog_light_color = FOG_NIGHT.lerp(fog_day, factor)
	# The night-floor ambient fill added alongside NightLight (see
	# night_light.gd) was a fixed *violet-tinted* Environment value, so it was
	# bleeding the fungal night theme into full daylight too (#25) - unlike
	# everything else here, it never responded to day_factor at all. First
	# fix attempt zeroed its energy at full day, but that also killed the
	# ambient fill light itself (previously implicit from the sky background,
	# always present) rather than just its color - a real render showed
	# daytime reading noticeably flatter/darker than before. Correct fix:
	# keep the fill light's energy constant and only lerp its *color* between
	# a neutral daytime tone and the violet night tone, so the fungal tint is
	# night-only but overall daytime brightness is unaffected.
	world_environment.environment.ambient_light_energy = 0.6
	world_environment.environment.ambient_light_color = AMBIENT_NIGHT.lerp(AMBIENT_DAY, factor)
	# Drive the custom asset pack's shared day/night shader (assets/custom_pack).
	# day_factor is 1 at noon / 0 at midnight; the shader wants the inverse
	# (0 = full day, 1 = full night). One global uniform feeds every material.
	RenderingServer.global_shader_parameter_set(&"day_night_ratio", 1.0 - factor)
