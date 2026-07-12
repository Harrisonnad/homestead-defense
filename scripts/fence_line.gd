extends Node3D

# Spawns a straight run of fence segments at runtime so the perimeter
# doesn't need dozens of hand-authored transforms in Main.tscn. The first
# segment sits at this node's origin; each next one is `spacing` further
# along `direction`. `texture_override` swaps in a directional Kenney
# render (e.g. fenceLow_E for north-south runs).

@export var fence_scene: PackedScene
@export var count: int = 5
@export var spacing: float = 2.0
@export var direction: Vector3 = Vector3.RIGHT
@export var texture_override: Texture2D

func _ready() -> void:
	for i in count:
		var segment := fence_scene.instantiate()
		add_child(segment)
		segment.position = direction.normalized() * spacing * i
		if texture_override:
			segment.get_node("Sprite3D").texture = texture_override
