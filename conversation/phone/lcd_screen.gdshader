// step 2.185: LCD look for the dumbphone screen (phone_cg.tscn > Frame/Rig/Screen).
// The sprite shows the 194 x 262 ScreenViewport scaled up 5x. Each LCD pixel is sampled at
// its centre (crisp at any window size), then gets a thin dark gap (the pixel grid), a soft
// glow from its neighbours, a vignette, and the backlight level.
shader_type canvas_item;

uniform float backlight : hint_range(0.0, 1.0) = 1.0;
// how much of the image is still visible with the backlight fully off
uniform float unlit_level : hint_range(0.0, 1.0) = 0.12;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.22;
uniform float grid_width : hint_range(0.0, 0.5) = 0.14;
uniform float glow : hint_range(0.0, 1.0) = 0.35;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
uniform vec4 glow_tint : source_color = vec4(0.72, 0.84, 1.0, 1.0);

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 cell = UV / px;
	vec3 base = texture(TEXTURE, (floor(cell) + 0.5) * px).rgb;

	vec3 blur = texture(TEXTURE, UV + vec2(px.x * 1.5, 0.0)).rgb
		+ texture(TEXTURE, UV - vec2(px.x * 1.5, 0.0)).rgb
		+ texture(TEXTURE, UV + vec2(0.0, px.y * 1.5)).rgb
		+ texture(TEXTURE, UV - vec2(0.0, px.y * 1.5)).rgb;
	blur *= 0.25;

	vec2 f = fract(cell);
	vec2 fw = fwidth(cell);
	vec2 open = smoothstep(vec2(grid_width) - fw, vec2(grid_width) + fw, f);
	// fade the grid out if an LCD pixel gets smaller than ~1.5 screen pixels
	float grid_fade = clamp(1.5 - max(fw.x, fw.y) * 1.5, 0.0, 1.0);
	float grid = 1.0 - grid_strength * grid_fade * (1.0 - open.x * open.y);

	vec3 col = base * grid;
	col = mix(col, max(col, blur * glow_tint.rgb), glow);

	vec2 d = UV - 0.5;
	col *= 1.0 - vignette * dot(d, d) * 1.6;

	col *= mix(unlit_level, 1.0, backlight);
	COLOR = vec4(col, 1.0);
}
