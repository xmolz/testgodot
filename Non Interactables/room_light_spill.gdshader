shader_type canvas_item;
render_mode blend_add;

uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform float peak_alpha : hint_range(0.0, 1.0) = 0.8;
uniform float falloff : hint_range(0.2, 6.0) = 2.2;
uniform bool from_left = true;
uniform float vertical_softness : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float ux = from_left ? UV.x : 1.0 - UV.x;
	float horiz = pow(clamp(1.0 - ux, 0.0, 1.0), falloff);
	float vs = max(vertical_softness, 0.0001);
	float vert = smoothstep(0.0, vs, UV.y) * smoothstep(0.0, vs, 1.0 - UV.y);
	float a = peak_alpha * horiz * vert;
	COLOR = vec4(light_color.rgb, light_color.a * a);
}
