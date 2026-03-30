shader_type canvas_item;

// This exact name matches the code already in your interactable.gd script!
uniform bool enable_outline = false; 

// The color of the glow (Defaults to Cyan)
uniform vec4 outline_color : source_color = vec4(0.2, 0.85, 1.0, 1.0); 

// How thick the outline is
uniform float outline_width : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);
	
	if (enable_outline) {
		float alpha = 0.0;
		vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
		
		// Sample pixels in 8 directions around the current pixel to create the outline
		alpha += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
		alpha += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
		alpha += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
		
		// Ensure alpha doesn't go above 1.0
		alpha = min(alpha, 1.0);
		
		// Mix the cyan outline color with the actual sprite
		vec4 final_color = mix(vec4(outline_color.rgb, outline_color.a * alpha), original_color, original_color.a);
		COLOR = final_color;
	} else {
		// Just draw the normal sprite
		COLOR = original_color;
	}
}