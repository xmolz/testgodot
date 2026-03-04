shader_type canvas_item;

uniform vec2 hole_position;
uniform vec2 screen_size; // We will pass the Viewport size here
uniform float hole_size : hint_range(0.0, 1000.0) = 100.0;
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);

void fragment() {
    // UV goes from 0.0 to 1.0. Multiplying it by screen_size gives us 
    // the exact Viewport pixel coordinates, matching the UI's global_position!
    vec2 pixel_pos = UV * screen_size;
    
    float dist = distance(pixel_pos, hole_position);
    if (dist < hole_size) {
        COLOR = vec4(0.0); // Transparent hole
    } else {
        COLOR = overlay_color;
    }
}