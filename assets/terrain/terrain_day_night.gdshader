shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Hand-authored terrain shader (not part of the Blender-generated
// assets/custom_pack pipeline) - the same day/night-shift idea as
// assets/custom_pack/day_night.gdshader, but flat per-biome colors instead
// of textures, since terrain tiles are untextured low-poly boxes.

uniform vec4 day_color : source_color = vec4(0.3, 0.45, 0.25, 1.0);
uniform vec4 night_color : source_color = vec4(0.1, 0.13, 0.17, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;

global uniform float day_night_ratio = 0.0; // 0 = full day, 1 = full night

void fragment() {
	ALBEDO = mix(day_color.rgb, night_color.rgb, day_night_ratio);
	ROUGHNESS = roughness_value;
}
