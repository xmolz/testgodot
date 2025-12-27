shader_type canvas_item;

uniform vec2 hole_position;
uniform float hole_size : hint_range(0.0, 1000.0) = 100.0;
uniform vec4 overlay_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);

void fragment() {
    float distance = distance(FRAGCOORD.xy, hole_position);
    if (distance < hole_size) {
        COLOR.a = 0.0;
    } else {
        COLOR = overlay_color;
    }
}