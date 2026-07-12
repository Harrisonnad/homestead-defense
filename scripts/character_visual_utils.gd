class_name CharacterVisualUtils

# Shared helpers for dressing up KayKit character models used by Villager and
# Enemy: a cheap static idle pose (avoids an awkward T-pose without wiring a
# full animation state machine) and a texture-preserving recolor tint.

const IDLE_ANIMATIONS_PATH := "res://docs/assets/KayKit/KayKit_Adventurers_2.0_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb"
const IDLE_ANIMATION_NAME := "Idle_A"
const IDLE_POSE_TIME := 0.3

static func apply_idle_pose(character_root: Node3D) -> void:
	var rig_medium := character_root.get_node_or_null("Rig_Medium")
	if rig_medium == null:
		return

	var anim_player := AnimationPlayer.new()
	character_root.add_child(anim_player)

	var lib_scene: PackedScene = load(IDLE_ANIMATIONS_PATH)
	var lib_inst: Node = lib_scene.instantiate()
	var source_player: AnimationPlayer = lib_inst.get_node("AnimationPlayer")
	for lib_name in source_player.get_animation_library_list():
		anim_player.add_animation_library(lib_name, source_player.get_animation_library(lib_name))
	lib_inst.free()

	if anim_player.has_animation(IDLE_ANIMATION_NAME):
		anim_player.play(IDLE_ANIMATION_NAME)
		anim_player.advance(IDLE_POSE_TIME)
		anim_player.pause()

static func tint_meshes(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		for surface_idx in node.mesh.get_surface_count():
			var mat: Material = node.get_active_material(surface_idx)
			if mat is StandardMaterial3D:
				var dup: StandardMaterial3D = mat.duplicate()
				dup.albedo_color = tint
				node.set_surface_override_material(surface_idx, dup)
	for child in node.get_children():
		tint_meshes(child, tint)
