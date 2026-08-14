class_name CharacterVisualUtils

# Shared helpers for dressing up character/creature models used by Villager,
# Enemy, and pack-creature buildings (AnimalPen): a texture-preserving recolor
# tint, and material/animation setup for the custom pack's rigged sk_
# creature meshes (every character/creature in the game is one now).

# Yaws a character root to face a horizontal movement direction. Assumes the
# imported model's rest pose (rotation.y = 0) faces +Z. Every sk_ creature's
# scene has a Model child with a fixed remap transform to guarantee this
# (Blender/glTF authors each mesh facing its own local +X - see
# creature_common.py - the Model transform rotates that to parent-local +Z).
# That remap transform was inverted for every creature scene until this was
# caught: every character walked backwards (showing its back toward its
# direction of travel), only obvious once sk_villager's redesign gave it
# unmistakable big eyes. Verified with an isolated test scene (villager
# forced to face world +X, camera placed on the +X side) before and after -
# confirms this function's own math was always correct; the bug was purely
# in each scene's Model transform sign.
static func face_direction(node: Node3D, direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() > 0.001:
		node.rotation.y = atan2(flat.x, flat.z)

# `material_filter`, when non-empty, restricts tinting to surfaces whose
# material name contains it (case-insensitive) - needed for sk_villager,
# which (unlike every other tint_meshes caller) has its own multi-material
# palette (fur/eyes/horns/outfit, see gen_villager.py) instead of one shared
# single-material mesh. Blanket-tinting every surface there would recolor
# the eyes/fur/horns along with the outfit. Default "" preserves the old
# whole-mesh tint behavior for enemy.gd's pacify flash and wall.gd's age tint.
static func tint_meshes(node: Node, tint: Color, material_filter: String = "") -> void:
	if node is MeshInstance3D:
		if node.material_override != null:
			# A whole-node override (e.g. apply_pack_material's shared pack
			# material) always wins over a per-surface override in Godot's
			# rendering - tinting via set_surface_override_material here
			# would be set but silently never drawn. Tint the override itself.
			var override_mat: Material = node.material_override
			if override_mat is StandardMaterial3D:
				var dup_override: StandardMaterial3D = override_mat.duplicate()
				dup_override.albedo_color = tint
				node.material_override = dup_override
			elif override_mat is ShaderMaterial:
				var dup_shader_override: ShaderMaterial = override_mat.duplicate()
				dup_shader_override.set_shader_parameter("tint_color", tint)
				node.material_override = dup_shader_override
		else:
			for surface_idx in node.mesh.get_surface_count():
				var mat: Material = node.get_active_material(surface_idx)
				if mat == null:
					continue
				if not material_filter.is_empty() and not mat.resource_name.to_lower().contains(material_filter.to_lower()):
					continue
				if mat is StandardMaterial3D:
					var dup: StandardMaterial3D = mat.duplicate()
					dup.albedo_color = tint
					node.set_surface_override_material(surface_idx, dup)
				elif mat is ShaderMaterial:
					var dup_shader: ShaderMaterial = mat.duplicate()
					dup_shader.set_shader_parameter("tint_color", tint)
					node.set_surface_override_material(surface_idx, dup_shader)
	for child in node.get_children():
		tint_meshes(child, tint, material_filter)

# Overrides every MeshInstance3D's material under `node` with `material`
# (shared, not duplicated - matches FarmPlot's crop material pattern since
# the day/night pack materials are stateless aside from the global uniform).
static func apply_pack_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		apply_pack_material(child, material)

# Plays a custom-pack sk_ creature's baked idle animation, looping. Every
# exported glb's AnimationPlayer carries every creature action generated in
# the same asset-pack build run (Blender keeps the actions in one file), but
# only "<creature_name>_armAction" actually deforms that creature's own
# skeleton correctly.
static func play_creature_idle(character_root: Node, creature_name: String) -> void:
	var anim_player := character_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		return
	var anim_name := "%s_armAction" % creature_name
	if not anim_player.has_animation(anim_name):
		return
	anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	anim_player.play(anim_name)

# Translucent build-placement preview tint. Unlike tint_meshes, this always
# gets a material to work with (building a fresh one if the surface has
# none) and forces alpha blending, and also handles Sprite3D-based visuals
# (farm plots, animal pen) via modulate instead of a material override.
static func apply_ghost_tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		for surface_idx in node.mesh.get_surface_count():
			var mat: Material = node.get_active_material(surface_idx)
			var dup: StandardMaterial3D = mat.duplicate() if mat is StandardMaterial3D else StandardMaterial3D.new()
			dup.albedo_color = color
			dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			node.set_surface_override_material(surface_idx, dup)
	elif node is Sprite3D:
		node.modulate = color
	for child in node.get_children():
		apply_ghost_tint(child, color)
