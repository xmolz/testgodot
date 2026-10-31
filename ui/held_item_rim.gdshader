shader_type canvas_item;
// step 2.404: a soft light rim around a held item (characters/rig/held_item.gd), so a dark object still
// reads on a dark backdrop. rim_px is in the item picture's own pixels.
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float rim_px = 7.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float near = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = float(i) * 0.3926991;
		vec2 off = vec2(cos(ang), sin(ang)) * TEXTURE_PIXEL_SIZE * rim_px;
		near = max(near, texture(TEXTURE, UV + off).a);
		near = max(near, texture(TEXTURE, UV + off * 0.5).a);
	}
	vec3 rgb = mix(rim_color.rgb, c.rgb, c.a);
	float a = max(c.a, rim_color.a * near);
	COLOR = vec4(rgb, a) * tint;
}
