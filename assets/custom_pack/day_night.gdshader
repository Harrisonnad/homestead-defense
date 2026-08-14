shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// One shared shader for the whole pack (master doc §5) — day/night is a
// single lerp driven by a global uniform, not separate day/night
// materials or meshes.

uniform sampler2D day_albedo : source_color;
uniform sampler2D night_albedo : source_color;
uniform sampler2D emission_mask;
uniform vec4 glow_color : source_color = vec4(0.309804, 0.890196, 0.819608, 1.0); // #4FE3D1 — cyan, environmental/neutral per §4
uniform vec4 glow_core_color : source_color = vec4(0.909804, 1.0, 0.984314, 1.0); // #E8FFFB hot core
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // per-instance multiply, default no-op (e.g. Reinforced Walls)

global uniform float day_night_ratio = 0.0; // 0 = full day, 1 = full night

void fragment() {
	vec3 day_color = texture(day_albedo, UV).rgb;
	vec3 night_color = texture(night_albedo, UV).rgb;
	ALBEDO = mix(day_color, night_color, day_night_ratio) * tint_color.rgb;
	ROUGHNESS = roughness_value;

	// mask encodes distance-from-vein-centerline: high values are the hot
	// core, low values are the saturated-color edge falloff (§5)
	float mask = texture(emission_mask, UV).r;
	vec3 glow = mix(glow_color.rgb, glow_core_color.rgb, pow(mask, 3.0));
	EMISSION = glow * mask * day_night_ratio;
}
