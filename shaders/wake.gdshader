shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;
// Ship wake foam: turbulent propeller wash down the middle and the Kelvin
// bow-wave crests along the edges. Rides the same Gerstner waves as the ocean.
// UV.x: -1..1 across the wake, UV.y: age 0 (new) .. 1 (old), COLOR.a: strength.

uniform float amp = 1.0;
uniform float choppy = 1.0;
uniform float t = 0.0;
uniform vec2 wind = vec2(1.0, 0.25);

const vec3 WAVES[8] = vec3[](
	vec3(0.0, 0.16, 96.0), vec3(0.42, 0.13, 61.0), vec3(-0.55, 0.12, 43.0), vec3(0.9, 0.10, 29.0),
	vec3(-0.25, 0.10, 19.0), vec3(1.3, 0.08, 13.0), vec3(-1.1, 0.07, 8.7), vec3(0.6, 0.06, 5.9));

varying float vx;
varying float vage;
varying float vint;
varying vec3 wpos;

vec2 rot(vec2 v, float a) { return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a)); }

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float d = distance(p.xz, cam.xz);
	float fade = 1.0 - smoothstep(900.0, 1500.0, d);
	vec3 off = vec3(0.0);
	vec3 tan = vec3(1.0, 0.0, 0.0);
	vec3 bin = vec3(0.0, 0.0, 1.0);
	for (int i = 0; i < 8; i++) {
		vec3 w = WAVES[i];
		float k = 6.28318 / w.z;
		float c = sqrt(9.81 / k);
		vec2 dd = normalize(rot(normalize(wind), w.x));
		float f = k * (dot(dd, p.xz) - c * t);
		float a = w.y * amp / k;
		float s = w.y * amp;
		off += vec3(dd.x * a * choppy * cos(f), a * sin(f), dd.y * a * choppy * cos(f));
		tan += vec3(-dd.x * dd.x * s * choppy * sin(f), dd.x * s * cos(f), -dd.x * dd.y * s * choppy * sin(f));
		bin += vec3(-dd.x * dd.y * s * choppy * sin(f), dd.y * s * cos(f), -dd.y * dd.y * s * choppy * sin(f));
	}
	VERTEX += off * fade + vec3(0.0, 0.1, 0.0);
	VERTEX.y -= d * d / (2.0 * 6371000.0 * 1.17);
	NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), normalize(cross(bin, tan)), fade));
	vx = UV.x;
	vage = UV.y;
	vint = COLOR.a;
	wpos = p;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float across = abs(vx);
	float n = noise(wpos.xz * 0.18 + t * 0.03) * 0.6 + noise(wpos.xz * 0.9 - t * 0.05) * 0.4;
	float n2 = noise(wpos.xz * 2.2 + t * 0.2);
	float center = exp(-pow(across / 0.3, 2.0)) * pow(1.0 - vage, 1.4) * smoothstep(0.0, 0.01, vage);
	float edge = exp(-pow((across - 0.88) / 0.14, 2.0)) * pow(1.0 - vage, 2.2) * 0.35 * smoothstep(0.35, 0.75, n);
	float bow = exp(-vage * 45.0) * smoothstep(1.0, 0.3, across) * 0.7;
	float foam = clamp((center * (0.35 + n * 0.75) * (0.5 + n2 * 0.7) * 0.8 + edge + bow * (0.4 + n2 * 0.6)) * vint, 0.0, 0.8);
	ALBEDO = vec3(0.9, 0.93, 0.95);
	ALPHA = foam;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
}
