shader_type sky;
render_mode use_debanding;
// Analytic sky: Rayleigh-like gradient that reddens near the horizon as the sun
// sets, a Mie halo around the sun, an HDR sun disc for bloom, a lit cloud deck,
// stars, moon and aurora for Arctic nights.

uniform vec3 sun_dir = vec3(0.3, 0.5, -0.8);
uniform vec3 moon_dir = vec3(-0.4, 0.3, 0.8);
uniform float t = 0.0;
uniform float cloud_cover = 0.4;
uniform float cloud_dark = 0.0;
uniform float haze = 0.3;
uniform float aurora = 0.0;
uniform vec3 ground_col : source_color = vec3(0.02, 0.05, 0.07);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p, int oct) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < oct; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; }
	return v;
}

vec3 atmosphere(vec3 d, vec3 s) {
	float sy = s.y;
	float day = smoothstep(-0.12, 0.25, sy);
	float dusk = (1.0 - smoothstep(0.0, 0.35, abs(sy + 0.02))) ;
	vec3 zen_day = vec3(0.16, 0.34, 0.66);
	vec3 hor_day = vec3(0.62, 0.74, 0.86);
	vec3 zen_night = vec3(0.004, 0.007, 0.018);
	vec3 hor_night = vec3(0.018, 0.026, 0.045);
	vec3 zen = mix(zen_night, zen_day, day);
	vec3 hor = mix(hor_night, hor_day, day);
	hor = mix(hor, hor * vec3(1.0, 0.92, 0.85) + vec3(0.06), haze * day);
	float h = max(d.y, 0.0);
	vec3 col = mix(hor, zen, pow(h, 0.42));
	// Sunset band: warm light low on the sky toward the sun.
	float toward = pow(max(dot(normalize(d.xz + 1e-4), normalize(s.xz + 1e-4)), 0.0), 3.0);
	vec3 warm = vec3(1.05, 0.48, 0.18);
	col = mix(col, warm * (0.45 + 0.4 * day), dusk * toward * exp(-h * 6.0) * 0.85);
	col += vec3(0.22, 0.10, 0.12) * dusk * exp(-h * 3.0) * 0.25;
	// Mie scattering halo around the sun.
	float mu = max(dot(d, s), 0.0);
	vec3 sun_tint = mix(vec3(1.0, 0.5, 0.2), vec3(1.0, 0.93, 0.82), smoothstep(0.0, 0.4, sy));
	col += sun_tint * (pow(mu, 8.0) * 0.22 + pow(mu, 64.0) * 0.5) * smoothstep(-0.1, 0.05, sy) * (0.6 + haze);
	return col;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 s = normalize(sun_dir);
	vec3 col = atmosphere(d, s);
	float day = smoothstep(-0.12, 0.25, s.y);
	float night = 1.0 - smoothstep(-0.2, 0.0, s.y);
	if (d.y < 0.0) {
		col = mix(col, ground_col * (0.2 + day), clamp(-d.y * 4.0, 0.0, 1.0));
	}
	// Sun disc (HDR so it blooms).
	float mu = dot(d, s);
	vec3 sun_tint = mix(vec3(1.0, 0.45, 0.15), vec3(1.0, 0.95, 0.88), smoothstep(0.0, 0.3, s.y));
	col += sun_tint * smoothstep(0.99985, 0.99993, mu) * 40.0 * smoothstep(-0.03, 0.02, s.y);
	if (night > 0.0 && d.y > 0.0) {
		vec3 q = floor(d * 420.0);
		float r = fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		float tw = 0.7 + 0.3 * sin(t * 3.0 + r * 50.0);
		col += vec3(0.9, 0.92, 1.0) * step(0.9984, r) * night * smoothstep(0.0, 0.25, d.y) * tw * 1.5 * (1.0 - cloud_cover);
		float m = dot(d, normalize(moon_dir));
		col += vec3(0.95, 0.94, 0.88) * smoothstep(0.99955, 0.99972, m) * 3.0 * night;
		col += vec3(0.08, 0.10, 0.14) * pow(max(m, 0.0), 24.0) * night;
		if (aurora > 0.0) {
			float ax = atan(d.x, -d.z);
			float band = sin(ax * 3.0 + t * 0.05 + fbm(vec2(ax * 2.0, t * 0.03), 3) * 4.0);
			float curtain = smoothstep(0.75, 1.0, band) * smoothstep(0.08, 0.3, d.y) * (1.0 - smoothstep(0.35, 0.8, d.y));
			float rays = fbm(vec2(ax * 40.0, d.y * 3.0 - t * 0.2), 3);
			col += vec3(0.1, 0.9, 0.45) * curtain * rays * aurora * night * 0.6;
			col += vec3(0.5, 0.1, 0.6) * curtain * smoothstep(0.25, 0.5, d.y) * aurora * night * 0.25;
		}
	}
	// Cloud deck projected onto a plane overhead.
	if (d.y > 0.0 && cloud_cover > 0.01) {
		vec2 uv = d.xz / (d.y + 0.06) * 0.9 + vec2(t * 0.0025, t * 0.0011);
		int oct = AT_CUBEMAP_PASS ? 4 : 6;
		vec2 warp = vec2(fbm(uv * 0.6, 3), fbm(uv * 0.6 + 5.2, 3)) * 0.8;
		float c = fbm(uv + warp, oct);
		float cov = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, c);
		float thick = smoothstep(1.0 - cloud_cover, 1.05, c);
		// Light from the sun side, darker cores and undersides.
		float lit = clamp(0.55 + 0.45 * dot(normalize(vec3(d.x, 0.3, d.z)), s), 0.0, 1.0);
		vec3 sun_c = mix(vec3(1.0, 0.55, 0.3), vec3(1.0, 0.98, 0.95), smoothstep(0.0, 0.35, s.y));
		vec3 cc = mix(vec3(0.42, 0.45, 0.5), vec3(0.95, 0.96, 0.98) * sun_c, lit * (1.0 - thick * 0.55));
		cc = mix(cc, vec3(0.22, 0.24, 0.27), cloud_dark);
		cc *= mix(0.03, 1.0, day);
		float silver = pow(max(mu, 0.0), 12.0) * (1.0 - thick) * 1.5 * day;
		cc += sun_c * silver;
		float fade = smoothstep(0.0, 0.12, d.y);
		col = mix(col, cc, cov * fade * 0.96);
	}
	COLOR = col;
}
