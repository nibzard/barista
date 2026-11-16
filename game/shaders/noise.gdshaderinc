// ABOUTME: Shared value noise for the hand-drawn shaders: paper grain, line boil, and haze drift.
// ABOUTME: Include it with #include; it holds functions only, no uniforms.

float ab_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ab_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 curve = local * local * (3.0 - 2.0 * local);
	float bottom = mix(ab_hash(cell), ab_hash(cell + vec2(1.0, 0.0)), curve.x);
	float top = mix(ab_hash(cell + vec2(0.0, 1.0)), ab_hash(cell + vec2(1.0, 1.0)), curve.x);
	return mix(bottom, top, curve.y);
}
