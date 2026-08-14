extends Building
class_name Scarecrow

# Non-lethal path (master spec §5.4): a passive deterrent. Scans a radius
# on a timer (same proven pattern as animal_pen.gd's chicken alarm and
# tower.gd's target scan - Area3D triggers have an unresolved history in
# this codebase) and calls start_fleeing() on anything with
# flee_on_damage == true within range. Only Locust Swarms set that flag
# today, so a Scarecrow only ever deters Locusts - not a universal
# deterrent that would trivialize combat against everything else.

@export var frighten_radius: float = 6.0
@export var scan_interval: float = 1.0

@onready var scan_timer: Timer = $ScanTimer

func _ready() -> void:
	super._ready()
	scan_timer.wait_time = scan_interval
	scan_timer.timeout.connect(_on_scan_timer_timeout)
	scan_timer.start()

func _on_scan_timer_timeout() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or not ("flee_on_damage" in node) or not node.flee_on_damage:
			continue
		if global_position.distance_to(node.global_position) <= frighten_radius:
			node.start_fleeing()
