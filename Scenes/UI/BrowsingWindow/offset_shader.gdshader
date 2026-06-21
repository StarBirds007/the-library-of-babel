shader_type canvas_item;

// These values stay perfectly still until you change them via code
uniform float offset_x = 0.0;
uniform float offset_y = 0.0;

void vertex() {
    // Moves the object's visual mesh by the specified X and Y amounts once
    VERTEX.x += offset_x;
    VERTEX.y += offset_y;
}
