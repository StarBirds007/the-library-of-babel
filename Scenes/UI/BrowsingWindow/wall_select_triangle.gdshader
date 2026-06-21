shader_type canvas_item;

// True = Points Right (>). False = Points Left (<).
uniform bool point_right = true;

// These values stay perfectly still until you change them via code
uniform float offset_x = 0.0;
uniform float offset_y = 0.0;

void vertex() {
    // Moves the object's visual mesh by the specified X and Y amounts once
    VERTEX.x += offset_x;
    VERTEX.y += offset_y;
}

void fragment() {
    vec2 uv = UV;

    // Determine the x coordinate of the triangle's tip based on direction
    float tip_x = point_right ? 1.0 : 0.0;

    // Calculate how far away the current pixel is from the tip horizontally
    float distance_from_tip = abs(uv.x - tip_x);

    // Calculate the allowed vertical bounds at this horizontal position.
    // Near the base, it allows the full height (0.5 max distance from center).
    // Near the tip, it narrows down to 0.
    float half_height_at_x = 0.5 * distance_from_tip;

    // Check if the current pixel's Y coordinate falls outside the triangular boundary
    // (uv.y - 0.5 finds the vertical center point)
    if (abs(uv.y - 0.5) > half_height_at_x) {
        // Discard the pixel entirely (makes it transparent)
        COLOR = vec4(0.0);
    } else {
        // Render the underlying GradientTexture2D safely inside the triangle
        COLOR = texture(TEXTURE, uv);
    }
}
