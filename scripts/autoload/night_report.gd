extends Node

# Autoload singleton: ephemeral per-night stats, reset at night_started and
# finalized at day_started - the data backing the Dawn Report UI panel
# (idle-friendly night resolution, master spec §5.5: "let a well-prepared
# defense auto-resolve a night with a dawn summary report if the player
# can't play live"). Distinct from AchievementManager, which tracks
# permanent unlocks rather than per-night ephemera - though Iron Curtain and
# Veteran Guard read from here too since the data happens to be exactly
# what they need, rather than inventing a second tracking system.

var enemies_killed: Dictionary = {} # creature_name -> count
var homestead_damage_taken: int = 0
var resources_lost: Dictionary = {} # resource type -> amount
var villagers_lost: int = 0

signal report_ready(report: Dictionary)

func _ready() -> void:
	GameClock.night_started.connect(_on_night_started)
	GameClock.day_started.connect(_on_day_started)

func _on_night_started() -> void:
	reset()

func _on_day_started(_day_count: int) -> void:
	report_ready.emit(build_report())

func build_report() -> Dictionary:
	var total_kills := 0
	for count in enemies_killed.values():
		total_kills += count
	return {
		"enemies_killed": enemies_killed.duplicate(),
		"total_kills": total_kills,
		"homestead_damage_taken": homestead_damage_taken,
		"resources_lost": resources_lost.duplicate(),
		"villagers_lost": villagers_lost,
	}

func on_enemy_killed(creature_name: String) -> void:
	enemies_killed[creature_name] = enemies_killed.get(creature_name, 0) + 1

func on_homestead_damaged(amount: int) -> void:
	homestead_damage_taken += amount

func on_resource_lost(type: String, amount: int) -> void:
	resources_lost[type] = resources_lost.get(type, 0) + amount

func on_villager_lost() -> void:
	villagers_lost += 1

func reset() -> void:
	enemies_killed.clear()
	homestead_damage_taken = 0
	resources_lost.clear()
	villagers_lost = 0
