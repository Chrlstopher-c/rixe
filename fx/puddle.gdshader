shader_type canvas_item;
render_mode unshaded;
// Flaque : reflet inversé (et étiré) de l'écran au-dessus de sa ligne d'eau, ondulé par la pluie.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float stretch = 5.0;

void fragment() {
	float below = UV.y / max(abs(dFdy(UV.y)), 0.00001);
	float wave = sin(UV.x * 90.0 + TIME * 4.0) * 0.6 + sin(UV.x * 37.0 - TIME * 2.3) * 0.4;
	vec2 uv = SCREEN_UV - vec2(wave * SCREEN_PIXEL_SIZE.x * 1.2, below * (1.0 + stretch) * SCREEN_PIXEL_SIZE.y);
	vec3 refl = texture(screen, uv).rgb * vec3(0.85, 0.95, 1.15) + vec3(0.04, 0.06, 0.1);
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	float shine = step(below, 1.0) * 0.35;
	COLOR = vec4(refl + shine * vec3(0.8, 0.9, 1.2), COLOR.a * edge);
}
