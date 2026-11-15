// ABOUTME: Full-screen paper overlay: grain, long paper fibers, and a soft warm vignette.
// ABOUTME: It multiplies the screen, so white areas of the overlay change nothing.
shader_type canvas_item;
render_mode blend_mul;

#include "res://shaders/noise.gdshaderinc"

uniform float grain_strength = 0.09;
uniform float fiber_strength = 0.05;
uniform float vignette_strength = 0.1;
uniform vec4 paper_tint : source_color = vec4(1.0, 0.975, 0.93, 1.0);

void fragment() {
	vec2 pixel = FRAGCOORD.xy;
	float grain = ab_noise(pixel * 0.8) * 0.6 + ab_noise(pixel * 0.23) * 0.4;
	float fiber = ab_noise(vec2(pixel.x * 0.015, pixel.y * 0.55));
	float vignette = smoothstep(0.35, 0.85, length(SCREEN_UV - 0.5));
	vec3 paper = paper_tint.rgb;
	paper *= 1.0 - grain_strength * grain - fiber_strength * fiber;
	paper *= 1.0 - vignette_strength * vignette;
	COLOR = vec4(paper, 1.0);
}
