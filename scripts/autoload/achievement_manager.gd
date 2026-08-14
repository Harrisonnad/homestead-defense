extends Node

# Autoload singleton: local achievement tracking, wired to
# docs/achievements.md's design list. Everything unlocks and persists
# locally (user://achievements.cfg) regardless of Steamworks integration
# status - _report_to_steam() is the single seam a future GodotSteam wiring
# pass hooks into (call the real Steam API there instead of a no-op), so
# nothing else in this file needs to change when that lands.
#
# Speedrunner from the design doc is intentionally NOT implemented here -
# the doc itself flagged it as needing reframing before it's implementable
# as stated (no "time left" concept exists). Iron Curtain and Veteran Guard
# were unblocked once NightReport (scripts/autoload/night_report.gd) landed
# with exactly the per-night damage tally they needed - Veteran Guard's
# per-villager night-survival counter lives on villager.gd itself instead,
# since that state belongs with the specific villager, not here.
#
# Most hooks are a single call added at the exact point docs/achievements.md
# already identified (harvest(), take_damage(), _try_repair(), etc.) - see
# each call site. A few (Economy/Progression/GameState/GameClock/NightReport)
# connect directly here since those are autoloads always present at _ready().

const SAVE_PATH := "user://achievements.cfg"
# buildings/*.tres count (pen, defense x6 - watchtower/ballista/sling_post/
# spike_trap/scarecrow/net_trap, farm, core, storage, wall, utility x1 -
# torch, bridge x1) - update if a new BuildingDef is ever added.
const TOTAL_BUILDING_DEFS := 13
# crops/*.tres count (Pumpkin/Carrot/Tomato/Pea/Corn/Sunflower) - update if a
# new CropDef is ever added.
const TOTAL_CROP_TYPES := 6

const ACHIEVEMENTS := {
	"homesteader": "Homesteader - Complete your first building",
	"green_thumb": "Green Thumb - Harvest your first crop",
	"full_house": "Full House - Build your first House",
	"warm_bodies": "Warm Bodies - Reach your population cap",
	"stockpiled": "Stockpiled - Fill a resource to its storage cap",
	"menagerie": "Menagerie - Build your first Animal Pen",
	"best_friend": "Best Friend - The Dog survives its first full night",
	"ruin_runner": "Ruin Runner - Repair your first ruin",
	"fully_upgraded": "Fully Upgraded - Purchase every unlock board upgrade",
	"jack_of_all_trades": "Jack of All Trades - Place every building type in one playthrough",
	"arsenal": "Arsenal - Fire all four ammo types",
	"splash_zone": "Splash Zone - Hit 3+ enemies with a single Ballista Tower or Spike Trap shot",
	"spray_and_pray": "Spray and Pray - A Sling Post volley hits its full target cap",
	"first_blood": "First Blood - Kill your first enemy",
	"wall_breakers_bane": "Wall Breaker's Bane - Kill a Siege-breaker before it reaches the Homestead",
	"guard_dog": "Guard Dog - The Dog kills an enemy",
	"early_warning": "Early Warning - The chicken alarm fires for the first time",
	"nail_biter": "Nail-Biter - Survive a night with the Homestead below 10% HP",
	"season_survivor": "Season Survivor - Win the season",
	"iron_homestead": "Iron Homestead - Win without the Homestead ever dropping below 50% HP",
	"hard_mode_champion": "Hard Mode Champion - Win the season on Hard difficulty",
	"flawless": "Flawless - Win without losing a single villager",
	"pacifist_farmer": "Pacifist Farmer - Win without building any wall/defense structures",
	"no_turrets_needed": "No Turrets Needed - Win without building any Towers",
	"ruin_hoarder": "Ruin Hoarder - Repair both ruins in one season",
	"custom_cartographer": "Custom Cartographer - Start a New Game with a manually entered seed",
	"iron_curtain": "Iron Curtain - Reinforced walls, and a raid ends with zero Homestead damage",
	"veteran_guard": "Veteran Guard - A Guard villager survives 5 nights after Veteran Training",
	"master_farmer": "Master Farmer - Harvest every crop type in one playthrough",
}

var unlocked: Dictionary = {}

signal achievement_unlocked(id: String)

# Per-season trackers - cleared by reset() (called from GameState.restart()),
# not persisted, since they only matter for "in one playthrough" achievements.
var _placed_categories: Dictionary = {}
var _placed_def_paths: Dictionary = {}
var _any_tower_placed: bool = false
var _ammo_fired: Dictionary = {}
var _ruins_repaired: int = 0
var _crops_harvested: Dictionary = {}
var _any_villager_died: bool = false
var _homestead_min_ratio: float = 1.0

func _ready() -> void:
	_load()
	Economy.resources_changed.connect(_on_resources_changed)
	Progression.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.game_ended.connect(_on_game_ended)
	GameClock.day_started.connect(_on_day_started)
	NightReport.report_ready.connect(_on_night_report_ready)
	_connect_homestead.call_deferred()

func _connect_homestead() -> void:
	var homestead := get_tree().get_first_node_in_group("homestead")
	if homestead == null:
		return
	homestead.health_changed.connect(_on_homestead_health_changed)

func reset() -> void:
	_placed_categories.clear()
	_placed_def_paths.clear()
	_any_tower_placed = false
	_ammo_fired.clear()
	_ruins_repaired = 0
	_crops_harvested.clear()
	_any_villager_died = false
	_homestead_min_ratio = 1.0
	_connect_homestead.call_deferred()

# --- Direct hooks called from gameplay scripts at the point the doc identified ---

func on_building_completed(building: Node) -> void:
	_unlock("homesteader")
	if building is AnimalPen:
		_unlock("menagerie")
	if building is Tower:
		_any_tower_placed = true
	var def_path: String = building.get_meta("building_def_path", "")
	if def_path == "":
		return
	if def_path.ends_with("house.tres"):
		_unlock("full_house")
	_placed_def_paths[def_path] = true
	if _placed_def_paths.size() >= TOTAL_BUILDING_DEFS:
		_unlock("jack_of_all_trades")
	var def: BuildingDef = load(def_path)
	if def:
		_placed_categories[def.category] = true

func on_crop_harvested(crop_name: String = "") -> void:
	_unlock("green_thumb")
	if crop_name != "":
		_crops_harvested[crop_name] = true
		if _crops_harvested.size() >= TOTAL_CROP_TYPES:
			_unlock("master_farmer")

func on_ruin_repaired() -> void:
	_unlock("ruin_runner")
	_ruins_repaired += 1
	if _ruins_repaired >= 2:
		_unlock("ruin_hoarder")

func on_dog_kill() -> void:
	_unlock("guard_dog")

func on_alarm_raised() -> void:
	_unlock("early_warning")

func on_enemy_killed(creature_name: String) -> void:
	_unlock("first_blood")
	if creature_name == "sk_myconid":
		_unlock("wall_breakers_bane")

func on_villager_died() -> void:
	_any_villager_died = true

func on_ammo_fired(ammo_type: String) -> void:
	if ammo_type == "":
		return
	_ammo_fired[ammo_type] = true
	if _ammo_fired.size() >= 4:
		_unlock("arsenal")

func on_splash_hit(targets_hit: int) -> void:
	if targets_hit >= 3:
		_unlock("splash_zone")

func on_spray_hit(targets_hit: int, cap: int) -> void:
	if targets_hit >= cap:
		_unlock("spray_and_pray")

func on_custom_seed_used() -> void:
	_unlock("custom_cartographer")

# villager.gd calls this once its own per-villager guard-night counter
# (only accumulated while Veteran Training is already purchased - see that
# file) reaches the threshold, rather than this file re-deriving per-villager
# state it has no natural ownership of.
func on_veteran_guard_milestone() -> void:
	_unlock("veteran_guard")

# --- Autoload-to-autoload connections ---

func _on_resources_changed(type: String, new_amount: int) -> void:
	if new_amount >= Economy.get_cap(type):
		_unlock("stockpiled")

func _on_upgrade_purchased(_id: String) -> void:
	if Progression.purchased.size() >= Progression.UPGRADES.size():
		_unlock("fully_upgraded")

func _on_day_started(_day_count: int) -> void:
	var homestead := get_tree().get_first_node_in_group("homestead")
	if homestead != null and homestead.max_health > 0 and float(homestead.current_health) / homestead.max_health < 0.1:
		_unlock("nail_biter")
	if get_tree().get_nodes_in_group("dogs").size() > 0:
		_unlock("best_friend")
	if GameState.current_population() >= GameState.population_cap:
		_unlock("warm_bodies")

func _on_night_report_ready(report: Dictionary) -> void:
	if Progression.wall_tier() >= 2 and report["homestead_damage_taken"] == 0:
		_unlock("iron_curtain")

func _on_homestead_health_changed(current: int) -> void:
	# Read max_health live (not bound at connect time) since it can change
	# after an Age advance - a stale bound value would silently corrupt the
	# Iron Homestead ratio the moment the homestead ages up.
	var homestead := get_tree().get_first_node_in_group("homestead")
	if homestead == null or homestead.max_health <= 0:
		return
	_homestead_min_ratio = minf(_homestead_min_ratio, float(current) / homestead.max_health)

func _on_game_ended(won: bool, _day: int) -> void:
	if not won:
		return
	_unlock("season_survivor")
	if GameState.difficulty == "hard":
		_unlock("hard_mode_champion")
	if not _any_villager_died:
		_unlock("flawless")
	if _homestead_min_ratio >= 0.5:
		_unlock("iron_homestead")
	if not (_placed_categories.has("defense") or _placed_categories.has("wall")):
		_unlock("pacifist_farmer")
	if not _any_tower_placed:
		_unlock("no_turrets_needed")

# --- Persistence + Steam seam ---

func _unlock(id: String) -> void:
	if unlocked.has(id) or not ACHIEVEMENTS.has(id):
		return
	unlocked[id] = true
	achievement_unlocked.emit(id)
	NotificationManager.notify("Achievement unlocked: %s" % ACHIEVEMENTS[id])
	_report_to_steam(id)
	_save()

# Replace this body with the real GodotSteam Steam.setAchievement()/
# storeStats() calls once Steamworks is wired in - everything above works
# identically with or without it.
func _report_to_steam(_id: String) -> void:
	pass

func _save() -> void:
	var config := ConfigFile.new()
	for id in unlocked:
		config.set_value("unlocked", id, true)
	config.save(SAVE_PATH)

func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for id in ACHIEVEMENTS:
		if config.get_value("unlocked", id, false):
			unlocked[id] = true
