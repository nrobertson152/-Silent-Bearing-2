shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Weather decks: painted non-skid steel, or teak planking for the old
// battleships and cruisers. Pattern from model-space x/z.

uniform vec3 deck_col : source_color = vec3(0.21, 0.22, 0.23);
uniform vec3 wood_col : source_color = vec3(0.47, 0.41, 0.34);
uniform float wood = 0.0;
uniform float weather = 0.5;

varying vec3 mp;

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
}

void fragment() {
	vec2 q = mp.xz;
	vec3 col;
	float rough;
	float h = 0.0;
	if (wood > 0.5) {
		float pw = 0.15;
		float pi = floor(q.x / pw);
		float pl = 7.3;
		float off = hash(vec2(pi, 3.0)) * pl;
		float ci = floor((q.y + off) / pl);
		float fx = fract(q.x / pw);
		float fz = fract((q.y + off) / pl);
		float grain = noise(vec2(q.x * 60.0, q.y * 2.0)) * 0.5 + noise(vec2(q.x * 140.0, q.y * 5.0)) * 0.5;
		col = wood_col * (0.78 + 0.32 * hash(vec2(pi, ci))) * (0.9 + 0.18 * grain);
		col = mix(col, vec3(dot(col, vec3(0.33))) * vec3(0.95, 0.96, 1.0), 0.35 + fbm(q * 0.3) * weather * 0.5);
		float seam = 1.0 - smoothstep(0.0, 0.06, min(fx, 1.0 - fx));
		float butt = 1.0 - smoothstep(0.0, 0.004, min(fz, 1.0 - fz));
		col = mix(col, vec3(0.05, 0.045, 0.04), max(seam, butt) * 0.85);
		rough = 0.78;
		h = -max(seam, butt) * 0.002;
	} else {
		float speck = hash(floor(q * 90.0));
		float wear = fbm(q * 0.25);
		col = deck_col * (0.9 + 0.08 * fbm(q * 2.1) + 0.06 * speck);
		col = mix(col, col * 1.35, smoothstep(0.62, 0.8, wear) * weather * 0.5);
		float rust = smoothstep(0.78, 0.92, noise(q * 1.7)) * weather;
		col = mix(col, vec3(0.30, 0.17, 0.09), rust * 0.35);
		rough = 0.92 - speck * 0.08;
		h = speck * 0.0008;
	}
	ALBEDO = col;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 n0 = normalize(NORMAL);
	vec3 r1 = cross(dpdy, n0);
	vec3 r2 = cross(n0, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * n0 - grad);
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
