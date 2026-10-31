shader_type canvas_item;
// step 2.343: mood overlays for the conversation overlay (AdvancedConversationOverlay.focus_lines /
// heat_glow), drawn in front of the characters. focus: manga focus lines - thin spikes at the screen
// edges pointing at the centre, redrawn a few times a second like hand-drawn frames. heat: a pink glow
// from the edges, pulsing like a heartbeat. each 0 = off, 1 = full.

uniform float focus : hint_range(0.0, 1.0) = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform vec4 heat_color : source_color = vec4(1.0, 0.42, 0.62, 0.55);
uniform float line_count = 160.0;
// focus lines start beyond this (0 = the centre, 1 = the middle of each screen edge)
uniform float clear_radius = 0.62;
uniform float flicker_fps = 12.0;
uniform float pulse_bpm = 72.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	// -1..1 across and down: an ellipse the shape of the screen
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);

	// heat glow: two quick beats, then a rest
	vec4 glow = vec4(heat_color.rgb, 0.0);
	if (heat > 0.0) {
		float t = fract(TIME * pulse_bpm / 60.0);
		float beat = exp(-pow((t - 0.08) * 18.0, 2.0)) + 0.6 * exp(-pow((t - 0.30) * 18.0, 2.0));
		float edge = smoothstep(0.55, 1.35, r);
		glow.a = heat_color.a * heat * edge * (0.65 + 0.35 * beat);
	}

	// focus lines
	float line_a = 0.0;
	if (focus > 0.0) {
		float u = atan(p.y, p.x) / 6.2831853 + 0.5;
		float cell = floor(u * line_count);
		float across = fract(u * line_count);
		float frame = floor(TIME * flicker_fps);
		float n1 = hash(cell * 12.9898 + frame * 78.233);
		float n2 = hash(cell * 39.346 + frame * 11.135);
		float present = step(0.35, n1);
		float half_w = 0.12 + 0.3 * n2;
		float in_line = 1.0 - smoothstep(half_w * 0.6, half_w, abs(across - 0.5));
		float start = clear_radius + n1 * 0.35;
		float radial = smoothstep(start, start + 0.15, r);
		line_a = line_color.a * focus * present * in_line * radial;
	}

	// lines over the glow
	float out_a = line_a + glow.a * (1.0 - line_a);
	vec3 out_rgb = vec3(0.0);
	if (out_a > 0.0001) {
		out_rgb = (line_color.rgb * line_a + glow.rgb * glow.a * (1.0 - line_a)) / out_a;
	}
	COLOR = vec4(out_rgb, out_a);
}
