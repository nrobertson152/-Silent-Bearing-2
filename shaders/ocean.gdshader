shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, depth_draw_opaque;
// Open-ocean surface. Eight Gerstner wave trains move the near grid; six more
// add per-pixel detail. Waves are evaluated in world space so the grid can
// follow the camera. Ocean.height() in scripts/view/ocean.gd mirrors the big
// waves for floating ships. The surface also drops away with the Earth's
// curvature so distant ships go hull-down over the horizon.

uniform vec4 deep : source_color = vec4(0.012, 0.045, 0.07, 1.0);
uniform vec4 scatter : source_color = vec4(0.04, 0.22, 0.24, 1.0);
uniform vec4 foam_col : source_color = vec4(0.86, 0.9, 0.92, 1.0);
uniform vec4 under : source_color = vec4(0.02, 0.10, 0.13, 1.0);
uniform vec3 sun_dir = vec3(0.3, 0.5, -0.8);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_energy = 1.0;
uniform float amp = 1.0;
uniform float choppy = 1.0;
uniform float t = 0.0;
uniform float flat_far = 0.0;
uniform vec2 wind = vec2(1.0, 0.25);
uniform float foam_amount = 0.5;
uniform float detail = 1.0;
uniform float curve = 1.0;

// Wave table: direction offset (radians from wind), steepness, wavelength.
const int NW = 8;
const vec3 WAVES[8] = vec3[](
	vec3(0.0, 0.16, 96.0), vec3(0.42, 0.13, 61.0), vec3(-0.55, 0.12, 43.0), vec3(0.9, 0.10, 29.0),
	vec3(-0.25, 0.10, 19.0), vec3(1.3, 0.08, 13.0), vec3(-1.1, 0.07, 8.7), vec3(0.6, 0.06, 5.9));
const vec3 FINE[6] = vec3[](
	vec3(0.3, 0.10, 3.7), vec3(-0.8, 0.10, 2.6), vec3(1.4, 0.09, 1.7), vec3(-1.6, 0.09, 1.15),
	vec3(0.1, 0.08, 0.8), vec3(2.2, 0.08, 0.55));

varying vec3 wpos;
varying vec3 wnorm;
varying float crest;
varying float squeeze;
varying float dist_cam;

vec2 rot(vec2 v, float a) { return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a)); }

vec3 gerstner(vec3 w, vec2 p, inout vec3 tan, inout vec3 bin, inout float jac, float scale) {
	float k = 6.28318 / w.z;
	float c = sqrt(9.81 / k);
	vec2 d = normalize(rot(normalize(wind), w.x));
	float f = k * (dot(d, p) - c * t);
	float a = w.y * scale / k;
	float s = w.y * scale;
	float q = choppy;
	tan += vec3(-d.x * d.x * s * q * sin(f), d.x * s * cos(f), -d.x * d.y * s * q * sin(f));
	bin += vec3(-d.x * d.y * s * q * sin(f), d.y * s * cos(f), -d.y * d.y * s * q * sin(f));
	jac -= s * q * sin(f);
	return vec3(d.x * a * q * cos(f), a * sin(f), d.y * a * q * cos(f));
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float d = distance(wp.xz, cam.xz);
	vec3 tan = vec3(1.0, 0.0, 0.0);
	vec3 bin = vec3(0.0, 0.0, 1.0);
	float jac = 1.0;
	vec3 off = vec3(0.0);
	float fade = (1.0 - flat_far) * (1.0 - smoothstep(900.0, 1500.0, d));
	if (fade > 0.0) {
		for (int i = 0; i < NW; i++) {
			off += gerstner(WAVES[i], wp.xz, tan, bin, jac, amp);
		}
	}
	off *= fade;
	VERTEX += off;
	VERTEX.y -= curve * d * d / (2.0 * 6371000.0 * 1.17);
	crest = off.y;
	squeeze = mix(1.0, jac, fade);
	wnorm = normalize(mix(vec3(0.0, 1.0, 0.0), normalize(cross(bin, tan)), fade));
	wpos = wp + off;
	dist_cam = d;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
// Value noise with its analytic gradient (xy) for irregular ripple normals.
vec3 noised(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return vec3(du.x * ((b - a) + (a - b - c + d) * u.y), du.y * ((c - a) + (a - b - c + d) * u.x),
		a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y);
}
vec2 ripples(vec2 p, float time) {
	vec2 g = vec2(0.0);
	float s = 0.55;
	float a = 0.5;
	mat2 m = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		vec2 q = p * s + vec2(time * 0.35, time * 0.21) * (1.0 + float(i) * 0.3);
		g += noised(q).xy * a * s;
		p = m * p;
		s *= 2.1;
		a *= 0.5;
	}
	return g;
}

void fragment() {
	vec3 tan = vec3(1.0, 0.0, 0.0);
	vec3 bin = vec3(0.0, 0.0, 1.0);
	float jac = 0.0;
	float df = (1.0 - smoothstep(60.0, 650.0, dist_cam)) * detail;
	vec3 n = wnorm;
	if (df > 0.001) {
		for (int i = 0; i < 6; i++) {
			gerstner(FINE[i], wpos.xz, tan, bin, jac, 0.6 + amp * 0.4);
		}
		vec3 fn = normalize(cross(bin, tan));
		vec2 rg = ripples(wpos.xz, t);
		n = normalize(wnorm + vec3(fn.x, 0.0, fn.z) * df * 0.45 + vec3(-rg.x, 0.0, -rg.y) * df * 0.16);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 5.0);
	// Light scattered up through thin wave crests.
	vec3 sd = normalize(sun_dir);
	float sss = clamp(crest / max(amp * 5.0, 0.2) + 0.25, 0.0, 1.0);
	sss *= pow(clamp(dot(v, -vec3(sd.x, -0.15, sd.z)), 0.0, 1.0), 3.0) * 0.8 + 0.25;
	vec3 col = deep.rgb + scatter.rgb * sss * (0.25 + 0.75 * max(sd.y, 0.0)) * 0.55;
	// Whitecaps where the surface folds over, broken up with noise.
	float fold = max(smoothstep(0.8, 0.3, squeeze), smoothstep(0.8, 1.3, crest / max(amp * 3.4, 0.05)) * 0.7);
	vec2 wd = normalize(wind);
	vec2 fq = vec2(dot(wpos.xz, wd), dot(wpos.xz, vec2(-wd.y, wd.x)));
	float fnz = noise(fq * vec2(0.25, 0.9) + t * 0.05) * 0.55 + noise(fq * vec2(1.1, 3.2) - t * 0.1) * 0.45;
	float foam = clamp(fold * smoothstep(0.35, 0.75, fnz) * 1.6 * foam_amount, 0.0, 1.0);
	foam *= 1.0 - smoothstep(1500.0, 6000.0, dist_cam);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
		ALBEDO = under.rgb * 0.4;
		EMISSION = under.rgb * 0.5 * sun_energy;
		ROUGHNESS = 0.6;
	} else {
		ALBEDO = mix(col, foam_col.rgb, foam);
		ROUGHNESS = mix(mix(0.035, 0.18, smoothstep(300.0, 6000.0, dist_cam)), 0.85, foam);
		SPECULAR = 0.5;
		METALLIC = 0.0;
		EMISSION = scatter.rgb * sss * max(sd.y, 0.0) * sun_energy * 0.06 * (1.0 - foam);
	}
}
