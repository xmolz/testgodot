shader_type canvas_item;

// driven 0 -> 1 by TransitionLayer's portal tweens.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// cpu-accumulated idle rotation/breathing. never derived from TIME.
uniform float idle_angle = 0.0;
uniform float idle_breathe = 0.0;
uniform float idle_swirl_boost = 0.0;
// cpu-accumulated outward wash, in uv radius units. drains detail off-frame.
uniform float idle_flow = 0.0;
// 0..1 churn ramp, mirrors TransitionLayer._idle_strength.
uniform float idle_strength = 0.0;
// keeps the portal circular on a non-square rect. set from gdscript.
uniform vec2 aspect_correction = vec2(1.0, 1.0);
// how hard the image spirals as it collapses inward.
uniform float swirl_strength : hint_range(0.0, 12.0) = 6.0;
// how hard the image is pulled toward the centre.
uniform float pull_strength : hint_range(0.0, 0.95) = 0.55;
// fraction of the churn spin that survives at the frame edge. MUST stay above 0.0 --
// 0.0 reintroduces the welded outer ring this shader was rewritten to remove.
uniform float idle_edge_spin : hint_range(0.05, 1.0) = 0.55;
// same, for the progress-driven warp. kept low so the grow/warp reads as before.
uniform float warp_edge_spin : hint_range(0.0, 1.0) = 0.15;
// how tight the vortex core is. bigger = spin falls off closer to the centre.
uniform float spin_falloff : hint_range(0.2, 3.0) = 1.0;
// rgb split near the edges. sells the warp cheaply.
uniform float aberration : hint_range(0.0, 0.05) = 0.012;
// the ring of light that closes over the art.
uniform vec4 rim_color : source_color = vec4(0.537255, 0.866667, 1.0, 1.0);
// what the portal ends on. the next phase starts underneath this.
uniform vec4 end_color : source_color = vec4(0.878431, 0.980392, 1.0, 1.0);

// mirror-repeat wrap. identity on [0,1], so behaviour at rest is unchanged. replaces the old
// clamp(), which smeared every out-of-frame sample into the border.
vec2 wrap_mirror(vec2 uv) {
	vec2 m = mod(uv, vec2(2.0));
	return vec2(1.0) - abs(m - vec2(1.0));
}

void fragment() {
	// squared so the warp accelerates instead of ramping linearly.
	float p = progress * progress;

	vec2 centred = (UV - vec2(0.5)) * aspect_correction;
	float r = length(centred);
	float ang = atan(centred.y, centred.x);

	// vortex profile: fast core, slower rim, never zero. this is the pooling fix.
	float edge_t = smoothstep(0.0, 1.0, r * spin_falloff);
	float idle_spin = mix(1.0, idle_edge_spin, edge_t);
	float warp_spin = mix(1.0, warp_edge_spin, edge_t);

	ang += p * swirl_strength * (1.0 + idle_swirl_boost) * warp_spin;
	ang += (idle_angle + idle_breathe) * idle_spin;

	// sampling from a shrinking radius pushes detail outward, so the swirls wash off-screen.
	// may go negative, which folds sampling through the centre. that is intentional and
	// continuous -- do not clamp or max() it to 0.0, that creates a flat disc at the centre.
	float warped_r = (r - idle_flow) * (1.0 - p * pull_strength);

	vec2 warped_uv = (vec2(cos(ang), sin(ang)) * warped_r) / aspect_correction + vec2(0.5);
	warped_uv = wrap_mirror(warped_uv);

	// chromatic split, strongest at the edges and late in the transition.
	float split = aberration * p * r;
	vec2 uv_r = wrap_mirror(warped_uv + vec2(split, 0.0));
	vec2 uv_b = wrap_mirror(warped_uv - vec2(split, 0.0));

	vec4 col = texture(TEXTURE, warped_uv);
	col.r = texture(TEXTURE, uv_r).r;
	col.b = texture(TEXTURE, uv_b).b;

	// a ring of light closing in from the edges toward the centre. dissolved by the churn so it
	// cannot park as a static circle while progress is held.
	float ring_pos = 0.75 * (1.0 - p);
	float ring = smoothstep(0.16, 0.0, abs(r - ring_pos));
	float ring_amount = clamp(ring * p * 1.4 * (1.0 - idle_strength * 0.85), 0.0, 1.0);
	col.rgb = mix(col.rgb, rim_color.rgb, ring_amount);

	// bloom out to the end colour over the last stretch.
	float flash = smoothstep(0.55, 1.0, progress);
	col.rgb = mix(col.rgb, end_color.rgb, flash);
	col.a = max(col.a, flash);

	COLOR = col;
}
