shader_type canvas_item;

// driven 0 -> 1 by TransitionLayer.play_chapter_portal().
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// dynamic continuous idle rotation/breathing strength
uniform float idle_strength : hint_range(0.0, 1.0) = 0.0;
// keeps the portal circular on a non-square rect. set from gdscript.
uniform vec2 aspect_correction = vec2(1.0, 1.0);
// how hard the image spirals as it collapses inward.
uniform float swirl_strength : hint_range(0.0, 12.0) = 6.0;
// how hard the image is pulled toward the centre.
uniform float pull_strength : hint_range(0.0, 0.95) = 0.55;
// rgb split near the edges. sells the warp cheaply.
uniform float aberration : hint_range(0.0, 0.05) = 0.012;
// the ring of light that closes over the art.
uniform vec4 rim_color : source_color = vec4(0.537255, 0.866667, 1.0, 1.0);
// what the portal ends on. the next phase starts underneath this.
uniform vec4 end_color : source_color = vec4(0.878431, 0.980392, 1.0, 1.0);

void fragment() {
	// squared so the warp accelerates instead of ramping linearly.
	float p = progress * progress;

	vec2 centred = (UV - vec2(0.5)) * aspect_correction;
	float r = length(centred);
	float ang = atan(centred.y, centred.x);

	// spiral harder toward the centre than at the edges.
	ang += p * swirl_strength * (1.0 - clamp(r * 1.4, 0.0, 1.0));

	// continuous idle swirl rotation & breathing drift
	ang += (TIME * 1.2 + sin(TIME * 2.0) * 0.15) * idle_strength * (1.0 - clamp(r * 1.4, 0.0, 1.0));

	// suck the image inward.
	float warped_r = r * (1.0 - p * pull_strength);

	vec2 warped_uv = (vec2(cos(ang), sin(ang)) * warped_r) / aspect_correction + vec2(0.5);
	warped_uv = clamp(warped_uv, vec2(0.0), vec2(1.0));

	// chromatic split, strongest at the edges and late in the transition.
	float split = aberration * p * r;
	vec2 uv_r = clamp(warped_uv + vec2(split, 0.0), vec2(0.0), vec2(1.0));
	vec2 uv_b = clamp(warped_uv - vec2(split, 0.0), vec2(0.0), vec2(1.0));

	vec4 col = texture(TEXTURE, warped_uv);
	col.r = texture(TEXTURE, uv_r).r;
	col.b = texture(TEXTURE, uv_b).b;

	// a ring of light closing in from the edges toward the centre.
	float ring_pos = 0.75 * (1.0 - p);
	float ring = smoothstep(0.16, 0.0, abs(r - ring_pos));
	col.rgb = mix(col.rgb, rim_color.rgb, clamp(ring * p * 1.4, 0.0, 1.0));

	// bloom out to the end colour over the last stretch.
	float flash = smoothstep(0.55, 1.0, progress);
	col.rgb = mix(col.rgb, end_color.rgb, flash);
	col.a = max(col.a, flash);

	COLOR = col;
}
