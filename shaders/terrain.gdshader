shader_type spatial;
render_mode cull_back;
// Coastal terrain: grass or tundra on gentle slopes, bare rock on steep ones,
// beaches at the waterline and snow above the snow line. Drops away with the
// Earth's curvature like the ocean.

uniform vec3 grass : source_color = vec3(0.28, 0.27, 0.18);
uniform vec3 rock : source_color = vec3(0.24, 0.23, 0.22);
uniform vec3 sand : source_color = vec3(0.45, 0.42, 0.34);
uniform vec3 snow_col : source_color = vec3(0.86, 0.88, 0.92);
uniform float snow_line = 60.0;
uniform float snow = 0.0;

varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float d = distance(wp.xz, cam.xz);
	VERTEX.y -= d * d / (2.0 * 6371000.0 * 1.17);
	wn = NORMAL;
}

void fragment() {
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float n = fbm(wp.xz * 0.004);
	float n2 = fbm(wp.xz * 0.05);
	vec3 col = mix(grass * (0.8 + 0.4 * n2), rock * (0.85 + 0.3 * n2), smoothstep(0.18, 0.42, slope + (n - 0.5) * 0.3));
	col = mix(sand * (0.9 + 0.2 * n2), col, smoothstep(2.0, 9.0, wp.y + n * 4.0));
	float sn = smoothstep(snow_line - 25.0, snow_line + 25.0, wp.y + (n - 0.5) * 60.0) * (1.0 - smoothstep(0.35, 0.65, slope)) * snow;
	col = mix(col, snow_col * (0.92 + 0.08 * n2), clamp(sn, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.7, sn);
	SPECULAR = 0.2;
}
