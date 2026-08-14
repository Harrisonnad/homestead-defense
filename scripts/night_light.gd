extends OmniLight3D
class_name NightLight

# So players can actually see their base at night (the sun's night-time
# energy is deliberately very low for atmosphere - see day_night_cycle.gd -
# which made the game's most important moment, the night defense, the
# hardest to visually read). A warm lantern/firelight glow that's off
# during the day and fades in as night falls, driven by the same
# GameClock.day_factor() source day_night_cycle.gd already uses rather than
# a new signal. Attached generically to Building-derived structures and the
# Homestead (see building.gd/homestead.gd) - not to Wall/Trap/FarmPlot/
# Fence, since a whole wall perimeter each carrying its own light would be
# visual clutter (and a lot of concurrent real-time lights) for little gain.

const LIGHT_COLOR := Color(1.0, 0.75, 0.45)

@export var night_energy: float = 1.4
@export var light_range: float = 6.0

func _ready() -> void:
	light_color = LIGHT_COLOR
	omni_range = light_range
	shadow_enabled = false # a shadow-casting light per building would add up fast
	light_energy = 0.0

func _process(_delta: float) -> void:
	light_energy = night_energy * (1.0 - GameClock.day_factor())
