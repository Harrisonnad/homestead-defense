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
	"reinforced_walls": {
		"name": "Reinforced Walls",
		"costs": {"stone": 25},
		"repeatable": false,
		"description": "New walls have 120 HP (cost +6 stone)",
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
		"description": "A new settler joins the homestead",
	},
}

var purchased: Dictionary = {}

signal upgrade_purchased(id: String)

func is_purchased(id: String) -> bool:
	return purchased.has(id)

func can_purchase(id: String) -> bool:
	if not UPGRADES.has(id):
		return false
	if is_purchased(id) and not UPGRADES[id]["repeatable"]:
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

func wall_tier() -> int:
	return 2 if is_purchased("reinforced_walls") else 1

func trap_damage_multiplier() -> int:
	return 2 if is_purchased("heavy_traps") else 1

func reset() -> void:
	purchased.clear()
