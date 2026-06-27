shader_type canvas_item;

// These values stay perfectly still until you change them via code
uniform float offset_x = 0.0;
uniform float offset_y = 0.0;
global uniform vec4 global_secondary_color;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = vec4(global_secondary_color.rgb, tex_color.a * COLOR.a);
}

void vertex() {
    // Moves the object's visual mesh by the specified X and Y amounts once
    VERTEX.x += offset_x;
    VERTEX.y += offset_y;
}
