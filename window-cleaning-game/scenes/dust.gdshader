shader_type canvas_item;

uniform vec2 hand_pos_list[1000];  // Array to hold multiple hand positions (max 1000 circles)
uniform int hand_keys_list[1000];  // Array to represent the "keys" or index mapping to positions
uniform int circle_count = 0;      // Number of circles to draw
uniform float radius = 50.0;       // Size of the circle for the erase effect

void fragment() {
    vec2 uv = FRAGCOORD.xy;

    // Loop through the circles and "erase" based on position
    for (int i = 0; i < circle_count; i++) {
        // Access the position using the index from hand_keys_list
        int key = hand_keys_list[i];
        vec2 hand_pos = hand_pos_list[key];
        
        float dist = distance(uv, hand_pos);
        if (dist < radius) {
            discard;  // Make it transparent within the circle
        }
    }

    // Default color of the ColorRect (dust)
    COLOR = vec4(0.8, 0.8, 0.8, 1.0);  // Light gray color for dust
}