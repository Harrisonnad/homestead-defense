extends CanvasLayer

# Idle-friendly night resolution (master spec §5.5): "let a well-prepared
# defense auto-resolve a night with a dawn summary report if the player
# can't play live." Night combat is already fully automated (Guards/Towers/
# Traps/Dog/Goat all act without input), so the missing piece was just this
# panel - a non-blocking morning digest of what happened, not a new
# mechanic. Deliberately doesn't pause or dim the screen (Root's
# mouse_filter = IGNORE) so it never gets in the way of a player who wants
# to keep playing through it; it just auto-hides after a few seconds.

const AUTO_HIDE_SECONDS := 8.0
const CREATURE_DISPLAY_NAMES := {
	"sk_sporehound": "Raider",
	"sk_lurker": "Ranged Raider",
	"sk_shambler": "Brute",
	"sk_myconid": "Siege-breaker",
}

@onready var root: Control = $Root
@onready var title_label: Label = $Root/PanelContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $Root/PanelContainer/VBoxContainer/BodyLabel
@onready var dismiss_button: Button = $Root/PanelContainer/VBoxContainer/DismissButton
@onready var auto_hide_timer: Timer = $AutoHideTimer

func _ready() -> void:
	root.visible = false
	NightReport.report_ready.connect(_on_report_ready)
	dismiss_button.pressed.connect(hide_report)
	auto_hide_timer.wait_time = AUTO_HIDE_SECONDS
	auto_hide_timer.timeout.connect(hide_report)

func _on_report_ready(report: Dictionary) -> void:
	title_label.text = "Dawn Report - Day %d" % maxi(GameClock.day_count - 1, 1)
	body_label.text = _build_body(report)
	root.visible = true
	auto_hide_timer.start()

func _build_body(report: Dictionary) -> String:
	var lines: Array[String] = []
	if report["total_kills"] > 0:
		var parts: Array[String] = []
		for creature_name in report["enemies_killed"]:
			var label: String = CREATURE_DISPLAY_NAMES.get(creature_name, creature_name)
			parts.append("%d %s" % [report["enemies_killed"][creature_name], label])
		lines.append("Enemies defeated: %s" % ", ".join(parts))
	else:
		lines.append("No enemies engaged the homestead.")

	if report["homestead_damage_taken"] > 0:
		lines.append("Homestead took %d damage." % report["homestead_damage_taken"])
	else:
		lines.append("The homestead was untouched.")

	if not report["resources_lost"].is_empty():
		var parts: Array[String] = []
		for type in report["resources_lost"]:
			parts.append("%d %s" % [report["resources_lost"][type], String(type).capitalize()])
		lines.append("Lost to raiders: %s" % ", ".join(parts))

	if report["villagers_lost"] > 0:
		lines.append("Villagers lost: %d" % report["villagers_lost"])

	return "\n".join(lines)

func hide_report() -> void:
	root.visible = false
	auto_hide_timer.stop()
