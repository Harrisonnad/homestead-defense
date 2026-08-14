shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Shared day/night shader for gray-box landscape primitives (Tree/Rock/
// BerryBush/FishingSpot) - the same idea as assets/terrain/terrain_day_night.gdshader
// (flat color mix, no UV-mapped textures needed since these are primitives,
// not the Blender-generated custom_pack meshes) plus a small flat emissive
// glow at night so landscaping shares the world's fungal bioluminescence
// theme instead of just sitting outside it while everything else (pack
// meshes, terrain, buildings) responds to day/night.
//
// day_color defaults to each primitive's pre-existing albedo_color so the
// daytime look is unchanged; night_color/glow only kick in as day_night_ratio
// rises.

uniform vec4 day_color : source_color = vec4(0.3, 0.45, 0.25, 1.0);
uniform vec4 night_color : source_color = vec4(0.16, 0.2, 0.22, 1.0);
uniform vec4 glow_color : source_color = vec4(0.309804, 0.890196, 0.819608, 1.0); // #4FE3D1, matches the pack's glow_color (§4)
uniform float glow_strength : hint_range(0.0, 1.0) = 0.12;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;

global uniform float day_night_ratio = 0.0; // 0 = full day, 1 = full night

void fragment() {
	ALBEDO = mix(day_color.rgb, night_color.rgb, day_night_ratio);
	ROUGHNESS = roughness_value;
	EMISSION = glow_color.rgb * glow_strength * day_night_ratio;
}
