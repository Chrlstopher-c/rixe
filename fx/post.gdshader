shader_type canvas_item;
// Post-traitement plein écran : ondes de choc, flou de mouvement caméra, flou radial, aberration chromatique,
// vignette, grain.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 blur = vec2(0.0);
uniform float zoom_blur = 0.0;
uniform float aberration = 0.0;
uniform vec4 waves[4];
uniform float aspect = 1.7777;
uniform float grain = 0.006;
uniform float vignette = 0.4;
uniform float hurt = 0.0;

vec2 wave_offset(vec2 uv) {
	vec2 off = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		vec4 w = waves[i];
		if (w.w <= 0.0) { continue; }
		vec2 d = uv - w.xy;
		d.x *= aspect;
		float dist = length(d);
		float ring = 1.0 - smoothstep(0.0, 0.035, abs(dist - w.z));
		off -= normalize(d + vec2(1e-5)) * ring * w.w * 0.025 * vec2(1.0 / aspect, 1.0);
	}
	return off;
}

vec3 tap(vec2 uv, float ca) {
	vec2 dir = (uv - vec2(0.5)) * ca;
	return vec3(texture(screen_tex, uv + dir).r, texture(screen_tex, uv).g, texture(screen_tex, uv - dir).b);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV + wave_offset(SCREEN_UV);
	float ca = min(aberration, 1.0) * 0.007;
	vec3 col = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float t = float(i) / 7.0 - 0.5;
		col += tap(uv + blur * t + (uv - 0.5) * zoom_blur * t, ca);
	}
	col /= 8.0;
	vec2 c = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	float edge = smoothstep(0.35, 1.05, length(c));
	col *= 1.0 - vignette * edge;
	col = mix(col, vec3(0.5, 0.0, 0.03), hurt * edge * (0.75 + 0.25 * sin(TIME * 9.0)));
	col += (hash(SCREEN_UV * 731.0 + TIME) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
