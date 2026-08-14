extends Node

# Autoload singleton: the unlock board. Holds the data-driven upgrade list,
# tracks what's been purchased, and answers stat queries from gameplay
# scripts (gather yield, wall tier, trap damage) so tier logic lives in one
# place instead of being scattered across scenes.

const UPGRADES := {
	"sharp_tools": {
		"name": "Sharpened Tools",
		"costs": {"wood": 20, "stone": 10},
		"repeatable": false,
		"description": "Gather twice as much per action",
	},
	"advance_age_2": {
		"name": "Advance to Established Farm",
		"costs": {"wood": 60, "stone": 60, "food": 30},
		"repeatable": false,
		"description": "Ages up the whole homestead: every existing and future Wall/Tower/House/Storehouse/Animal Pen/Trap/Farm Plot gets stronger stats and a visual upgrade. Walls: 120 HP.",
	},
	"advance_age_3": {
		"name": "Advance to Fortified Farmstead",
		"costs": {"wood": 100, "stone": 100, "food": 60},
		"repeatable": false,
		"requires": "advance_age_2",
		"description": "The homestead's final tier: every building reaches its strongest stats and grandest look. Walls: 200 HP.",
	},
	"veteran_training": {
		"name": "Veteran Training",
		"costs": {"food": 40},
		"repeatable": false,
		"description": "Villagers: +15 HP, +6 guard damage, faster work",
	},
	"heavy_traps": {
		"name": "Heavy Traps",
		"costs": {"stone": 20},
		"repeatable": false,
		"description": "Traps deal double damage",
	},
	"recruit_villager": {
		"name": "Recruit Villager",
		"costs": {"food": 30},
		"repeatable": true,
		"description": "A new settler joins the homestead (needs population room - build a House)",
	},
}

var purchased: Dictionary = {}

signal upgrade_purchased(id: String)
signal state_loaded

func is_purchased(id: String) -> bool:
	return purchased.has(id)

func can_purchase(id: String) -> bool:
	if not UPGRADES.has(id):
		return false
	if is_purchased(id) and not UPGRADES[id]["repeatable"]:
		return false
	if id == "recruit_villager" and not GameState.has_population_room():
		return false
	var requires: String = UPGRADES[id].get("requires", "")
	if requires != "" and not is_purchased(requires):
		return false
	return Economy.can_afford_all(UPGRADES[id]["costs"])

func try_purchase(id: String) -> bool:
	if not can_purchase(id):
		return false
	if not Economy.spend_all(UPGRADES[id]["costs"]):
		return false
	purchased[id] = true
	upgrade_purchased.emit(id)
	return true

func gather_multiplier() -> int:
	return 2 if is_purchased("sharp_tools") else 1

# The homestead's overall Age/Era tier (docs/spec_base_builder.md's original
# "Homestead -> Established Farm -> Fortified Farmstead" progression model).
# Every building script reads this - directly, or via a helper like
# wall_tier() below - both at its own _ready() and whenever a new age is
# purchased, so advancing retroactively upgrades buildings already standing,
# not just future construction.
func homestead_age() -> int:
	if is_purchased("advance_age_3"):
		return 3
	if is_purchased("advance_age_2"):
		return 2
	return 1

func wall_tier() -> int:
	return homestead_age()

func trap_damage_multiplier() -> int:
	return 2 if is_purchased("heavy_traps") else 1

func reset() -> void:
	purchased.clear()

func load_state(purchased_ids: Array) -> void:
	purchased.clear()
	for id in purchased_ids:
		purchased[id] = true
	state_loaded.emit()
