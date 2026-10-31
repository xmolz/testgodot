shader_type canvas_item;
// step 2.330: for the conversation overlay's background picture (AdvancedConversationOverlay.background_view).
// zoom: frames part of the picture (1 = the whole picture), centred on `center` (0..1 across/down the
// picture; kept inside so no edge shows). blur_px: a soft blur in picture pixels, for depth of field.
// the background's own tint (background_dim, set as self_modulate) still applies.

uniform float zoom = 1.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float blur_px = 0.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	float z = max(zoom, 1.0);
	vec2 c = clamp(center, vec2(0.5 / z), vec2(1.0 - 0.5 / z));
	vec2 uv = c + (UV - vec2(0.5)) / z;
	vec4 col = vec4(0.0);
	if (blur_px <= 0.01) {
		col = texture(TEXTURE, uv);
	} else {
		// 48 taps on a golden-angle spiral, weighted towards the middle
		vec2 step_px = TEXTURE_PIXEL_SIZE * blur_px;
		float total = 0.0;
		for (int i = 0; i < 48; i++) {
			float r = sqrt((float(i) + 0.5) / 48.0);
			float a = float(i) * 2.39996;
			vec2 offset = vec2(cos(a), sin(a)) * r * step_px;
			float w = exp(-2.0 * r * r);
			col += texture(TEXTURE, uv + offset) * w;
			total += w;
		}
		col /= total;
	}
	COLOR = col * tint;
}
