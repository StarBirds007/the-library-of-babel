shader_type canvas_item;

uniform float skew_amount : hint_range(-1.0, 1.0) = 0.3;
// 1.0 is normal size. Values higher than 1.0 will squish it vertically.
uniform float vertical_squish : hint_range(1.0, 5.0) = 1.5; 

void fragment() {
    vec2 uv = UV;
    
    // Skew: as x goes from 0 (left) to 1 (right), shift y sampling
    uv.y += (uv.x - 0.5) * skew_amount;

	// Code to squish it towards the center on y axis
	uv.y = (uv.y - 0.5) * vertical_squish + 0.5;

    if (uv.y < 0.0 || uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    } else {
        COLOR = texture(TEXTURE, uv);
    }
}
