shader_type canvas_item;

// --- SETTINGS ---
// Default to Neon Cyan
uniform vec4 line_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float line_thickness : hint_range(0.001, 0.1) = 0.02;
uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float frequency : hint_range(1.0, 10.0) = 2.0;
uniform float height : hint_range(0.1, 1.0) = 0.5;
uniform float y_offset : hint_range(-0.5, 0.5) = 0.0;

// Helper to draw the line shape
float smooth_bump(float center, float width, float x) {
	float t = abs(x - center);
	if (t > width) return 0.0;
	return 1.0 - smoothstep(0.0, width, t);
}

void fragment() {
	vec2 uv = UV;

	// Scroll X
	float moving_x = uv.x * frequency + (TIME * -speed);
	float x = fract(moving_x);

	// Construct the Heartbeat Shape
	float pulse = 0.0;
	pulse += smooth_bump(0.2, 0.05, x) * 0.1;  // P
	pulse -= smooth_bump(0.28, 0.02, x) * 0.1; // Q
	pulse += smooth_bump(0.3, 0.04, x) * 1.0;  // R (Spike)
	pulse -= smooth_bump(0.34, 0.03, x) * 0.25; // S
	pulse += smooth_bump(0.5, 0.08, x) * 0.15; // T

	pulse *= height;
	float target_y = 0.5 + y_offset - pulse;

	// Calculate Distance to line
	float dist = abs(uv.y - target_y);

	// Calculate Glow/Intensity
	float line_intensity = smoothstep(line_thickness, 0.0, dist);
	float glow = exp(-dist * 20.0) * 0.5; // Neon glow effect

	// Combine intensity
	float total_intensity = line_intensity + glow;

	// Fade edges (Left and Right) so the line doesn't just "pop" into existence
	// This makes it look like it's fading in from the side of the screen
	total_intensity *= smoothstep(0.0, 0.15, uv.x) * smoothstep(1.0, 0.85, uv.x);

	// OUTPUT:
	// We use the 'line_color' for RGB.
	// We use 'total_intensity' for Alpha.
	// If intensity is 0 (background), Alpha is 0, showing your sprite behind it.
	vec3 final_rgb = line_color.rgb;
	float final_alpha = total_intensity * line_color.a;

	COLOR = vec4(final_rgb, final_alpha);
}
