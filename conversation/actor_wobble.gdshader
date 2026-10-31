shader_type canvas_item;
// step 2.371: a mild, endless wave on an actor (see actor_wobble in AdvancedConversationOverlay.gd).
// she sways from her base - the top of the picture moves, the bottom stays put - and a slow ripple
// runs up her, so she looks like she's short-circuiting. strength 0 = no effect at all.

uniform float strength : hint_range(0.0, 3.0) = 1.0;
uniform float speed : hint_range(0.0, 4.0) = 1.0;
// how far the top sways side to side, as a fraction of the picture's width
uniform float sway_amount = 0.014;
// the ripple: how far it pushes, how many waves fit top to bottom, how fast they climb
uniform float ripple_amount = 0.0045;
uniform float ripple_waves = 9.0;
uniform float ripple_speed = 3.2;

// the actor's own tint (fades, dimming), passed on from the vertex stage
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = UV;
	// 0 at the bottom of the picture, 1 at the top: the higher up, the more she moves
	float up = pow(clamp(1.0 - uv.y, 0.0, 1.0), 1.3);
	float t = TIME * speed;
	// a slow, slightly uneven swing (two sines, so it never looks like a clean metronome)
	float sway = sin(t * 2.3) * 0.75 + sin(t * 3.7 + 1.3) * 0.25;
	// the ripple travels upward
	float ripple = sin(uv.y * ripple_waves * 6.2832 + t * ripple_speed);
	uv.x += (sway * sway_amount + ripple * ripple_amount) * up * strength;
	vec4 c = texture(TEXTURE, uv);
	// nothing outside the picture
	if (uv.x < 0.0 || uv.x > 1.0) {
		c.a = 0.0;
	}
	COLOR = c * tint;
}
