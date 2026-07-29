shader_type canvas_item;
render_mode unshaded;

// full-screen dream filter. reads the screen underneath and re-renders it swimming, hazy and
// tinted. everything scales off `amount`, and at amount = 0.0 the output is a pixel-exact copy
// of the screen, so this is safe to leave sitting in the tree.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

// master intensity. tweened from gdscript. 0 = off, 1 = full dream.
uniform float amount : hint_range(0.0, 1.0) = 0.0;

// the swimming distortion.
uniform float wobble_amp : hint_range(0.0, 0.03) = 0.006;
uniform float wobble_speed : hint_range(0.0, 3.0) = 0.6;
uniform float swim_scale : hint_range(0.5, 8.0) = 3.0;
// slow in/out "breathing" zoom.
uniform float breathe_amp : hint_range(0.0, 0.06) = 0.014;
// radial colour bleed.
uniform float bleed : hint_range(0.0, 0.02) = 0.004;
// hazy bloom mixed over the top.
uniform float soft : hint_range(0.0, 1.0) = 0.55;
// colour grade.
uniform vec4 tint : source_color = vec4(0.62, 0.72, 1.0, 1.0);
uniform float tint_mix : hint_range(0.0, 1.0) = 0.30;
uniform float desat : hint_range(0.0, 1.0) = 0.35;
uniform float brightness : hint_range(0.5, 2.0) = 1.06;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
uniform float grain : hint_range(0.0, 0.3) = 0.05;

void fragment() {
	vec2 uv = SCREEN_UV;

	// two-octave sine domain warp. NOTE: `amount` scales the AMPLITUDE only -- the phase comes
	// from TIME and is never multiplied by a ramping value. scaling a phase by a ramping value
	// is what caused the portal grow stutter; scaling an amplitude is continuous and safe.
	float t = TIME * wobble_speed;
	vec2 w;
	w.x = sin(uv.y * swim_scale * 6.2831 + t) + 0.5 * sin(uv.y * swim_scale * 11.0 - t * 1.3);
	w.y = cos(uv.x * swim_scale * 6.2831 - t * 0.9) + 0.5 * cos(uv.x * swim_scale * 9.0 + t * 1.7);
	uv += w * wobble_amp * amount;

	// slow breathing zoom about the centre.
	float breathe = sin(TIME * 0.45) * breathe_amp * amount;
	uv = (uv - vec2(0.5)) * (1.0 - breathe) + vec2(0.5);

	// radial chromatic bleed: heavier at the frame edges than the centre.
	vec2 dir = uv - vec2(0.5);
	float b = bleed * amount;
	vec3 col;
	col.r = texture(screen_tex, uv + dir * b).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * b).b;

	// cheap 4-tap soft bloom for the hazy glow.
	float o = 0.0015 + 0.0025 * amount;
	vec3 blur = texture(screen_tex, uv + vec2( o,  o)).rgb;
	blur += texture(screen_tex, uv + vec2(-o,  o)).rgb;
	blur += texture(screen_tex, uv + vec2( o, -o)).rgb;
	blur += texture(screen_tex, uv + vec2(-o, -o)).rgb;
	blur *= 0.25;
	col = mix(col, max(col, blur), soft * amount);

	// desaturate, then tint.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desat * amount);
	col = mix(col, col * tint.rgb, tint_mix * amount);
	col *= mix(1.0, brightness, amount);

	// vignette, measured on the true screen position so the wobble cannot make it slide.
	float v = 1.0 - smoothstep(0.35, 0.95,
		length((SCREEN_UV - vec2(0.5)) * vec2(1.0, 0.85)) * 1.15);
	col *= mix(1.0, mix(1.0 - vignette, 1.0, v), amount);

	// grain.
	float n = fract(sin(dot(SCREEN_UV * vec2(1024.0, 768.0) + vec2(TIME),
		vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain * amount;

	COLOR = vec4(col, 1.0);
}
