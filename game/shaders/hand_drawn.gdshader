// ABOUTME: Hand-drawn look for world art: stepped line boil, colored pencil grain, and the sketch-to-color fill.
// ABOUTME: fill 0 shows a lavender pencil sketch; fill 1 shows full color. The fill grows out from fill_origin in world space.
shader_type canvas_item;

#include "res://shaders/noise.gdshaderinc"

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec2 fill_origin = vec2(0.0, 0.0);
uniform float fill_radius = 400.0;
uniform float fill_edge = 50.0;
uniform float boil_strength = 1.2;
uniform float boil_fps = 8.0;
uniform float boil_scale = 0.05;
uniform float grain_strength = 0.14;
uniform vec4 paper : source_color = vec4(0.953, 0.902, 0.784, 1.0);
uniform vec4 graphite : source_color = vec4(0.42, 0.39, 0.45, 1.0);
uniform vec4 sleep_tint : source_color = vec4(0.663, 0.608, 0.769, 1.0);
uniform float sleep_tint_amount : hint_range(0.0, 1.0) = 0.35;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// Line boil: the shape moves a little, but only on whole boil frames, like a redrawn cel.
	float frame = floor(TIME * boil_fps);
	vec2 seed = world_pos * boil_scale + vec2(frame * 7.13, frame * 3.71);
	vec2 wobble = vec2(ab_noise(seed), ab_noise(seed + 19.3)) - 0.5;
	VERTEX += wobble * 2.0 * boil_strength;
}

void fragment() {
	vec4 base = COLOR;
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	// The sketch: dark values become graphite on paper, then a lavender wash goes over all.
	vec3 sketch = mix(paper.rgb, graphite.rgb, smoothstep(0.85, 0.2, lum));
	sketch = mix(sketch, sleep_tint.rgb, sleep_tint_amount);
	// The wake front: a ragged circle that grows from the origin.
	float ragged = ab_noise(world_pos * 0.035) * fill_edge;
	float reach = fill * (fill_radius + fill_edge * 2.0);
	float dist = distance(world_pos, fill_origin) + ragged;
	float awake = 1.0 - smoothstep(reach - fill_edge, reach, dist);
	awake = fill >= 1.0 ? 1.0 : awake;
	vec3 rgb = mix(sketch, base.rgb, awake);
	// Uneven pigment: the paper tooth shows through every flat color.
	float tooth = ab_noise(FRAGCOORD.xy * 0.9) * ab_noise(FRAGCOORD.xy * 0.21 + 3.1);
	rgb *= 1.0 - grain_strength * tooth;
	COLOR = vec4(rgb, base.a);
}
