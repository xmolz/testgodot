shader_type canvas_item;

// step 2.232: the dream CG as a faint mental image over the car ride. it swims gently, is
// desaturated and cool-tinted, and fades out towards the frame edges so it never reads as a cut.

uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float swim = 0.004;
uniform float desat : hint_range(0.0, 1.0) = 0.5;
uniform vec4 tint : source_color = vec4(0.78, 0.82, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.5;
	uv += vec2(sin(uv.y * 14.0 + t), cos(uv.x * 11.0 - t * 0.8)) * swim;
	vec4 c = texture(TEXTURE, uv);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l), desat) * tint.rgb;
	float edge = 1.0 - smoothstep(0.25, 0.75, length((UV - vec2(0.5)) * vec2(1.0, 0.9)));
	COLOR = vec4(c.rgb, c.a * opacity * edge);
}
