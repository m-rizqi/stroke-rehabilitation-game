shader_type canvas_item;

uniform vec2 hand_pos_list[2000];
uniform float radius_list[2000];
uniform int circle_count = 0;

void fragment() {
    vec2 uv = FRAGCOORD.xy;
    COLOR = vec4(0.8, 0.8, 0.8, 1.0);  // Default color

    for (int i = 0; i < circle_count; i++) {
        vec2 hand_pos = hand_pos_list[i];
        float radius = radius_list[i];
        float dist = distance(uv, hand_pos);

        if (dist < radius) {
            // Set COLOR to a debug color when a fragment falls within the radius
			discard;
        }
    }
}
