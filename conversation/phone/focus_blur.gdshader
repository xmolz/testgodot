// step 2.187: depth-of-field blur for a CanvasGroup (the phone in phone_cg.tscn). Works in the
// Compatibility renderer: no mipmaps, just a 32-tap spiral of samples, turned a little per
// pixel so large blurs read as soft grain instead of streaks. blur is the radius in 1080p
// pixels (it scales with the window), 0 = sharp.
// Note: in the Compatibility renderer only one blurred CanvasGroup per screen works
// reliably, so keep this to the phone.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur : hint_range(0.0, 40.0) = 0.0;

const int TAPS = 32;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (blur > 0.2) {
		vec2 unit = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0) / 1080.0;
		float spin = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853;
		vec4 acc = c;
		float total = 1.0;
		for (int i = 1; i <= TAPS; i++) {
			float t = float(i) / float(TAPS);
			float angle = float(i) * 2.39996323 + spin;
			vec2 offset = vec2(cos(angle), sin(angle)) * sqrt(t) * blur * unit;
			float w = exp(-2.0 * t);
			acc += textureLod(screen_texture, SCREEN_UV + offset, 0.0) * w;
			total += w;
		}
		c = acc / total;
	}
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	COLOR *= c;
}
