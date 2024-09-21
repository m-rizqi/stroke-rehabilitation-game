shader_type canvas_item;

uniform vec2 hand_pos_list[1000];  // Array to hold multiple hand positions (max 100 clicks)
uniform int circle_count = 0;     // Number of circles to draw
uniform float radius = 40.0;      // Size of the circle for the erase effect

void fragment() {
    vec2 uv = FRAGCOORD.xy;

    for (int i = 0; i < circle_count; i++) {
        float dist = distance(uv, hand_pos_list[i]);
        if (dist < radius) {
            discard;  // Make it transparent within the circle
        }
    }

    // Default color of the ColorRect (dust)
    COLOR = vec4(0.8, 0.8, 0.8, 1.0);  // Light gray color for dust
}
