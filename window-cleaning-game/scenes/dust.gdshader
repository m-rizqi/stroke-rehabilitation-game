shader_type canvas_item;

uniform vec2 hand_pos_list[5000];  // Array to hold multiple hand positions (max 5000 circles at a time)
uniform float radius_list[5000];   // Array to hold individual radius for each circle
uniform int circle_count = 0;      // Number of circles to draw

void fragment() {
    vec2 uv = FRAGCOORD.xy;

    // Default color of the ColorRect (dust)
    COLOR = vec4(0.8, 0.8, 0.8, 1.0);  // Light gray color for dust

    // Loop through the circles and "erase" based on position and radius
    for (int i = 0; i < circle_count; i++) {
        vec2 hand_pos = hand_pos_list[i];
        float radius = radius_list[i];
        
        // Calculate the distance from the current fragment to the hand position
        float dist = distance(uv, hand_pos);
        
        // Erase (discard) if within the radius
        if (dist < radius) {
            discard;  // Make it transparent within the circle
        }
    }
}