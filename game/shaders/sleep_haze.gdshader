// ABOUTME: Sleep zone haze: the screen inside the zone loses color, goes pale, and drifts in lavender.
// ABOUTME: Put it on a square rect over the zone. strength 0 switches the haze off; it is never dark.
shader_type canvas_item;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec4 haze : source_color = vec4(0.663, 0.608, 0.769, 1.0);
uniform float desaturate : hint_range(0.0, 1.0) = 0.85;
uniform float lift : hint_range(0.0, 1.0) = 0.15;
uniform float haze_amount : hint_range(0.0, 1.0) = 0.6;
uniform float drift_speed = 0.08;
// The size of the haze rect in pixels. The rect UV is not set on every
// renderer, so the shader makes its own 0..1 coordinates from the vertex.
uniform vec2 rect_size = vec2(512.0, 512.0);

varying vec2 zone_uv;

void vertex() {
	zone_uv = VERTEX / rect_size;
}

void fragment() {
	vec2 centered = zone_uv - 0.5;
	float drift = ab_noise(zone_uv * 4.0 + TIME * drift_speed * vec2(1.0, 0.6));
	float edge = length(centered) + (drift - 0.5) * 0.12;
	float inside = (1.0 - smoothstep(0.26, 0.5, edge)) * strength;
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	float lum = dot(scene, vec3(0.299, 0.587, 0.114));
	vec3 washed = mix(scene, vec3(lum), desaturate);
	washed = mix(washed, vec3(1.0), lift);
	washed = mix(washed, haze.rgb, haze_amount + 0.15 * drift);
	COLOR = vec4(mix(scene, washed, inside), 1.0);
}
