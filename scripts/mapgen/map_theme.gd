extends Resource
class_name MapTheme

## Data-driven theme definition. Create one .tres per theme
## (river_valley.tres, highland_terraces.tres, coastal_marsh.tres, etc.)
## The generator never hardcodes theme logic — it just reads this.

@export var theme_name: String = "Unnamed Theme"

## --- Terrain noise ---
@export var noise_frequency: float = 0.02
@export var noise_octaves: int = 4
@export var elevation_amplitude: Vector2 = Vector2(0.0, 10.0) # min/max height
@export var moisture_frequency: float = 0.015

## --- Biome weighting ---
## Keys are biome ids, values are relative weights within this theme.
## Weights are interpreted as target area shares: water claims the lowest
## elevation band proportional to its share, rock the highest, and dirt
## claims the most-moist share of the remaining land (grass gets the rest).
## Thresholding elevation/moisture noise (rather than rolling per tile)
## keeps features contiguous — rivers and ridges, not scattered tiles.
@export var biome_weights: Dictionary = {
	"grass": 1.0,
	"dirt": 0.4,
	"water": 0.3,
	"rock": 0.2,
}

## --- Resource & crop plots ---
@export var resource_node_density: Vector2 = Vector2(0.02, 0.05) # per-tile probability range
@export var crop_plot_density: Vector2 = Vector2(0.05, 0.1)
@export var min_buildable_core_tiles: int = 150

## --- Defense features ---
@export_range(0.0, 1.0) var chokepoint_bias: float = 0.5
@export var min_chokepoints: int = 1

## --- Props ---
@export var prop_scenes: Array[PackedScene] = []
@export var prop_density: float = 0.03

## --- Validation retry behavior ---
@export var max_regen_attempts: int = 5

## Pre-verified seed known to pass validation for this theme; used as the
## last-resort map when max_regen_attempts is exhausted.
@export var fallback_seed: int = 1
