shader_type canvas_item;
render_mode unshaded;

// eyelids. this node doubles as the blackout: at openness = 0.0 the whole screen is opaque
// lid_color, so an abrupt cut to black and the blink that follows are the same node and need
// no hand-off between them.
//   0.0 = shut (screen fully covered)
//   1.0 = fully open (nothing drawn anywhere, including the frame corners)
uniform float openness : hint_range(0.0, 1.0) = 1.0;

// how much the aperture tapers toward the left and right screen edges. lower = wider almond.
uniform float curve : hint_range(0.05, 2.0) = 0.35;
// softness of the lid edge, in uv units. scales down as the eye closes so a full close is solid.
uniform float lash_softness : hint_range(0.0, 0.1) = 0.022;
uniform vec4 lid_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// almond aperture shape, flattening out to a full-frame opening as the eye reaches 1.0 so
	// there are never leftover black bars down the left and right edges.
	float almond = pow(max(sin(UV.x * 3.14159265), 0.0), curve);
	float aperture = openness * mix(almond, 1.0, openness) * 0.72;

	float d = abs(UV.y - 0.5);
	float s = max(lash_softness * openness, 0.0008);
	float a = smoothstep(aperture - s, aperture + s, d);

	// hard floor near a full close, so "abrupt black" is genuinely solid black. the high
	// exponent keeps it out of the way at every other openness, apart from a slight dimming
	// while the eye is barely cracked -- which is the blurry-waking-vision look.
	a = clamp(a + pow(1.0 - openness, 8.0), 0.0, 1.0);

	COLOR = vec4(lid_color.rgb, a * lid_color.a);
}
