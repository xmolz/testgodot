shader_type canvas_item;
render_mode unshaded;

// liquid glass pane for the dialogue box. reads the screen behind the balloon and re-renders it
// through a rounded-rect "lens": the middle stays close to a straight copy so the art underneath
// is still readable, and the bend and the highlight are concentrated in a band around the rim.
// at distortion = 0.0 this is a flat tinted pane with a rim -- still glass, just no refraction.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

// pushed from conversationballoon.gd. BOTH are in viewport (1920x1080) pixels, not window pixels.
uniform vec2 rect_size = vec2(1880.0, 208.0);
uniform vec2 viewport_px = vec2(1920.0, 1080.0);

// shape. the shader draws its own rounded rect, so this replaces the stylebox corner radius.
uniform float corner_radius : hint_range(0.0, 80.0) = 18.0;

// the settings slider drives this one.
uniform float distortion : hint_range(0.0, 1.0) = 0.4;
// how far in from the rim the lens bends. keep it well under half the panel's short side, or the
// two bevels meet in the middle and the bend goes wobbly.
uniform float edge_width : hint_range(2.0, 120.0) = 34.0;
// how far the rim can shift the sample, in pixels, at distortion = 1.0.
uniform float refraction_px : hint_range(0.0, 80.0) = 26.0;

// legibility grade. this is what keeps white text readable over bright art.
uniform float blur_amount : hint_range(0.0, 1.0) = 0.25;
uniform float blur_px : hint_range(0.0, 12.0) = 3.0;
uniform vec4 tint_color : source_color = vec4(0.02, 0.03, 0.06, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.28;
uniform float brightness : hint_range(0.5, 1.5) = 1.04;
uniform float saturation : hint_range(0.0, 2.0) = 1.06;

// rim and inner shadow.
uniform float rim_strength : hint_range(0.0, 2.0) = 0.85;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_px : hint_range(0.5, 8.0) = 2.5;
uniform float inner_shadow : hint_range(0.0, 1.0) = 0.35;
uniform float inner_shadow_px : hint_range(1.0, 60.0) = 18.0;

// signed distance to a rounded box, in panel pixels. negative inside.
float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 half_size = rect_size * 0.5;
	float r = min(corner_radius, min(half_size.x, half_size.y));
	vec2 p = (UV - vec2(0.5)) * rect_size;
	float d = sd_round_box(p, half_size, r);

	// antialiased rounded-rect mask. this is the pane's alpha -- the corners are the shader's job.
	float mask = 1.0 - smoothstep(-1.5, 1.5, d);

	if (mask <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		// outward normal, from the gradient of the distance field.
		vec2 ex = vec2(1.0, 0.0);
		vec2 ey = vec2(0.0, 1.0);
		vec2 grad = vec2(
			sd_round_box(p + ex, half_size, r) - sd_round_box(p - ex, half_size, r),
			sd_round_box(p + ey, half_size, r) - sd_round_box(p - ey, half_size, r)
		);
		grad = grad / max(length(grad), 0.00001);

		// 1 at the rim, 0 by edge_width inside. the power keeps the middle of the pane honest.
		float inset = clamp(-d / max(edge_width, 1.0), 0.0, 1.0);
		float bevel = pow(1.0 - inset, 2.2);

		vec2 offset_px = grad * (bevel * distortion * refraction_px);
		vec2 suv = SCREEN_UV + offset_px / viewport_px;

		vec3 col = texture(screen_tex, suv).rgb;

		// 4 tap softening. explicit taps, not textureLod -- there are no backbuffer mipmaps to
		// lean on under the compatibility renderer.
		if (blur_amount > 0.0) {
			vec2 o = vec2(blur_px) / viewport_px;
			vec3 b = texture(screen_tex, suv + vec2( o.x,  o.y)).rgb;
			b += texture(screen_tex, suv + vec2(-o.x,  o.y)).rgb;
			b += texture(screen_tex, suv + vec2( o.x, -o.y)).rgb;
			b += texture(screen_tex, suv + vec2(-o.x, -o.y)).rgb;
			col = mix(col, b * 0.25, blur_amount);
		}

		// grade.
		col = mix(col, tint_color.rgb, tint_amount);
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(luma), col, saturation);
		col *= brightness;

		// inner shadow, so the pane reads as an object sitting on the art rather than a hole in it.
		float shade = pow(1.0 - clamp(-d / inner_shadow_px, 0.0, 1.0), 2.0);
		col *= 1.0 - shade * inner_shadow;

		// specular rim, brightest where the edge faces the light.
		float border = 1.0 - clamp(-d / rim_px, 0.0, 1.0);
		vec2 light_dir = normalize(vec2(-0.45, -1.0));
		float facing = clamp(dot(grad, light_dir), 0.0, 1.0);
		col += rim_color.rgb * (border * (0.30 + 0.70 * pow(facing, 1.5)) * rim_strength);

		COLOR = vec4(col, mask);
	}
}