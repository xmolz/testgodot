shader_type canvas_item;
render_mode unshaded;

// liquid glass pane for the dialogue box, v2. reads the screen behind the balloon and re-renders
// it as a piece of glass with thickness: magnified, frosted, bent at the rim, and scrimmed by
// however bright the thing behind it happens to be.
//
// the knobs worth touching are grouped below. they all live here on purpose -- gdscript only ever
// sets rect_size, viewport_px and distortion, so everything else can be tuned by editing this file
// and relaunching, with no script changes.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

// pushed from conversationballoon.gd. BOTH are in viewport (1920x1080) pixels, not window pixels.
uniform vec2 rect_size = vec2(1880.0, 208.0);
uniform vec2 viewport_px = vec2(1920.0, 1080.0);

uniform float corner_radius : hint_range(0.0, 80.0) = 22.0;

// ---- refraction. the settings slider drives `distortion`; the rest shape what it does. ----
uniform float distortion : hint_range(0.0, 1.0) = 0.4;
uniform float edge_width : hint_range(2.0, 120.0) = 44.0;
uniform float refraction_px : hint_range(0.0, 80.0) = 30.0;
uniform float chroma_px : hint_range(0.0, 12.0) = 4.0;
// glass has thickness, so it magnifies. 1.0 = a flat filter, which is what v1 looked like.
uniform float zoom : hint_range(1.0, 1.3) = 1.06;

// ---- frost ----
uniform float blur_amount : hint_range(0.0, 1.0) = 0.85;
uniform float blur_px : hint_range(0.0, 24.0) = 7.0;

// ---- adaptive scrim. this is the legibility fix: `need` rises with the backdrop's luminance, so
// a white room gets pushed down to scrim_max and a night scene barely past scrim_min. ----
uniform vec4 scrim_color : source_color = vec4(0.03, 0.05, 0.08, 1.0);
uniform float scrim_min : hint_range(0.0, 1.0) = 0.22;
uniform float scrim_max : hint_range(0.0, 1.0) = 0.66;
uniform float scrim_lo : hint_range(0.0, 1.0) = 0.22;
uniform float scrim_hi : hint_range(0.0, 1.0) = 0.78;
uniform float saturation : hint_range(0.0, 2.0) = 1.10;

// ---- boundary. the dark hairline is what gives the pane an edge on a bright background, where a
// white rim on its own vanishes. the bright rim does the same job on a dark one. ----
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_px : hint_range(0.0, 6.0) = 1.6;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.75;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_px : hint_range(0.5, 8.0) = 2.2;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.75;
uniform float inner_glow : hint_range(0.0, 0.5) = 0.10;
uniform float inner_shadow : hint_range(0.0, 1.0) = 0.16;
uniform float top_sheen : hint_range(0.0, 0.3) = 0.07;

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

		float edge_d = -d;
		float bevel = pow(1.0 - clamp(edge_d / max(edge_width, 1.0), 0.0, 1.0), 2.2);

		// sample a magnified copy of what is behind the pane, then bend it harder toward the rim.
		vec2 center_suv = SCREEN_UV - p / viewport_px;
		vec2 suv = center_suv + (p / max(zoom, 0.001)) / viewport_px;
		suv += (grad * (bevel * distortion * refraction_px)) / viewport_px;

		vec3 sharp = texture(screen_tex, suv).rgb;

		// 13 tap frost, two hex rings. explicit taps, not textureLod -- there are no backbuffer
		// mipmaps to lean on under the compatibility renderer.
		vec2 ra = vec2(blur_px * 0.5) / viewport_px;
		vec2 rb = vec2(blur_px) / viewport_px;
		vec3 frost = sharp * 0.16;
		frost += texture(screen_tex, suv + vec2( 1.000,  0.000) * ra).rgb * 0.08;
		frost += texture(screen_tex, suv + vec2( 0.500,  0.866) * ra).rgb * 0.08;
		frost += texture(screen_tex, suv + vec2(-0.500,  0.866) * ra).rgb * 0.08;
		frost += texture(screen_tex, suv + vec2(-1.000,  0.000) * ra).rgb * 0.08;
		frost += texture(screen_tex, suv + vec2(-0.500, -0.866) * ra).rgb * 0.08;
		frost += texture(screen_tex, suv + vec2( 0.500, -0.866) * ra).rgb * 0.08;
		frost += texture(screen_tex, suv + vec2( 0.866,  0.500) * rb).rgb * 0.06;
		frost += texture(screen_tex, suv + vec2( 0.000,  1.000) * rb).rgb * 0.06;
		frost += texture(screen_tex, suv + vec2(-0.866,  0.500) * rb).rgb * 0.06;
		frost += texture(screen_tex, suv + vec2(-0.866, -0.500) * rb).rgb * 0.06;
		frost += texture(screen_tex, suv + vec2( 0.000, -1.000) * rb).rgb * 0.06;
		frost += texture(screen_tex, suv + vec2( 0.866, -0.500) * rb).rgb * 0.06;

		vec3 col = mix(sharp, frost, blur_amount);

		// chromatic split, rim only. weighted by bevel so the middle of the pane keeps its frost --
		// unweighted, these two taps re-sharpen the whole panel and fringe it.
		float cw = clamp(bevel * distortion, 0.0, 1.0);
		if (chroma_px > 0.0 && cw > 0.0) {
			vec2 ca = (grad * (bevel * distortion * chroma_px)) / viewport_px;
			col.r = mix(col.r, texture(screen_tex, suv + ca).r, cw * 0.6);
			col.b = mix(col.b, texture(screen_tex, suv - ca).b, cw * 0.6);
		}

		// adaptive scrim. a fixed tint is what made v1 unreadable in the hospital room.
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		float need = smoothstep(scrim_lo, scrim_hi, luma);
		col = mix(col, scrim_color.rgb, mix(scrim_min, scrim_max, need));

		float l2 = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(l2), col, saturation);

		// broad sheen across the top, soft glow just inside the rim, mild shadow deeper in.
		col += vec3(pow(1.0 - clamp(UV.y / 0.35, 0.0, 1.0), 2.0) * top_sheen);
		col += vec3(pow(1.0 - clamp(edge_d / 26.0, 0.0, 1.0), 3.0) * inner_glow);
		col *= 1.0 - pow(1.0 - clamp(edge_d / 22.0, 0.0, 1.0), 2.0) * inner_shadow;

		vec2 light_dir = normalize(vec2(-0.45, -1.0));
		float facing = clamp(dot(grad, light_dir), 0.0, 1.0);

		// dark hairline at the extreme edge.
		float dark_line = 1.0 - smoothstep(outline_px - 0.75, outline_px + 0.75, edge_d);
		col = mix(col, outline_color.rgb, dark_line * outline_strength);

		// bright rim immediately inside it. together the two read on any backdrop.
		float rim = smoothstep(outline_px - 0.75, outline_px + 0.75, edge_d)
			* (1.0 - smoothstep(outline_px + rim_px - 0.75, outline_px + rim_px + 0.75, edge_d));
		col += rim_color.rgb * (rim * (0.35 + 0.65 * facing) * rim_strength);

		COLOR = vec4(col, mask);
	}
}