extends Resource
class_name BuildingDef

# Data-driven building definition, one .tres per building type (mirrors the
# MapTheme pattern). The build menu and BuildManager read this generically -
# adding a building means adding a resource file, not new code.

@export var building_name: String = "Unnamed Building"
@export var category: String = "wall" # wall, defense, farm, core, storage, pen
@export var footprint_size: Vector2i = Vector2i(1, 1)
@export var resource_cost: Dictionary = {}
@export var build_time_seconds: float = 3.0
@export var scene: PackedScene
@export var construction_scene: PackedScene
@export var max_health: int = 50
@export var population_cap_bonus: int = 0
@export var storage_cap_bonus: int = 0
@export var defense_stats: Dictionary = {} # {"damage": int, "range": float, "interval": float}
@export var passive_resource_output: Dictionary = {} # resource id -> amount per dawn
@export var description: String = ""
