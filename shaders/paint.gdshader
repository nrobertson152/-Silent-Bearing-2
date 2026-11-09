shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Navy paint on welded steel: plate seams, the dished "hungry horse" look of
// plating between frames, rust streaks, waterline grime and boot-topping.
// Patterns use model-space position, so no UVs are needed.

uniform vec3 paint : source_color = vec3(0.49, 0.52, 0.55);
uniform vec3 boot : source_color = vec3(0.05, 0.05, 0.055);
uniform vec3 bottom : source_color = vec3(0.40, 0.13, 0.09);
uniform vec3 rust_col : source_color = vec3(0.34, 0.19, 0.10);
uniform float hull = 1.0;
uniform float boot_lo = -0.7;
uniform float boot_hi = 0.6;
uniform float weather = 0.5;
uniform float plate_h = 2.4;
uniform float frame_l = 6.0;
uniform float dish = 0.05;
uniform float base_rough = 0.62;
uniform float ports_y = -100.0;
uniform float ports_z0 = 0.0;
uniform float ports_z1 = 0.0;

varying vec3 mp;
varying vec3 mn;

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
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

void vertex() {
	mp = VERTEX;
	mn = NORMAL;
}

void fragment() {
	vec3 an = abs(mn);
	vec2 q;
	float top = 0.0;
	if (an.y > 0.8) { q = mp.xz; top = 1.0; }
	else if (an.x >= an.z) { q = vec2(mp.z, mp.y); }
	else { q = vec2(mp.x, mp.y); }
	vec2 g = vec2(q.x / frame_l, q.y / plate_h);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float side = sign(mp.x + 0.001);
	vec3 col = paint * (0.955 + 0.07 * hash(cell + side * 17.0));
	float blot = fbm(q * 0.11 + vec2(side * 31.0, 0.0));
	col *= 0.93 + 0.12 * blot;
	// Rust weeps from seams and fittings, running down the plating.
	float src = noise(vec2(q.x * 2.3, cell.y * 3.1 + side * 5.0));
	float run = noise(vec2(q.x * 9.0, q.y * 0.35));
	float streak = smoothstep(0.66, 0.95, src) * smoothstep(0.35, 0.9, run) * (1.0 - top);
	streak *= 0.35 + 0.65 * (1.0 - f.y);
	col = mix(col, rust_col, clamp(streak * weather * 0.6, 0.0, 1.0));
	float grime = (1.0 - smoothstep(0.0, 1.8, abs(mp.y - 0.3))) * hull;
	col = mix(col, col * vec3(0.58, 0.6, 0.53), grime * weather * 0.7);
	vec2 e = min(f, 1.0 - f) * vec2(frame_l, plate_h);
	float seam = 1.0 - smoothstep(0.0, 0.03, min(e.x * 0.4, e.y));
	col *= 1.0 - seam * 0.16;
	float wet = 0.0;
	if (hull > 0.5) {
		float wl = mp.y + (noise(vec2(mp.z * 0.7, side)) - 0.5) * 0.05;
		col = mix(col, boot * (0.9 + 0.2 * blot), step(wl, boot_hi));
		col = mix(col, bottom * (0.85 + 0.25 * blot), step(wl, boot_lo));
		wet = 1.0 - smoothstep(0.0, 2.5, mp.y);
	}
	float port = 0.0;
	if (ports_y > -50.0 && an.x >= an.z && mp.z > ports_z0 && mp.z < ports_z1) {
		float dz = (fract(mp.z / 1.7) - 0.5) * 1.7;
		float d = length(vec2(dz, mp.y - ports_y));
		port = 1.0 - smoothstep(0.16, 0.19, d);
		col = mix(col, col * 0.7, (1.0 - smoothstep(0.19, 0.24, d)) * (1.0 - port));
		col = mix(col, vec3(0.03, 0.04, 0.05), port);
	}
	ALBEDO = col;
	// Bump from plate dishing and seams (surface-gradient method, no tangents needed).
	float h = -dish * sin(f.x * PI) * sin(f.y * PI) * (1.0 - top) - seam * 0.004;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 n0 = normalize(NORMAL);
	vec3 r1 = cross(dpdy, n0);
	vec3 r2 = cross(n0, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * n0 - grad);
	ROUGHNESS = clamp(base_rough + 0.18 * blot + streak * 0.2 - wet * 0.3 - port * 0.5, 0.08, 1.0);
	SPECULAR = 0.4;
}
