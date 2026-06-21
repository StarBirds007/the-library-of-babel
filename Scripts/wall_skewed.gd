extends TextureButton


func _ready() -> void:
    if material:
        material = material.duplicate(true)


func _has_point(point: Vector2) -> bool:
    var mat := material as ShaderMaterial
    if not mat:
        return point.x >= 0 and point.x <= size.x and point.y >= 0 and point.y <= size.y
    
    var skew_amount: float = mat.get_shader_parameter("skew_amount")
    var vertical_squish: float = mat.get_shader_parameter("vertical_squish")
    
    var s = size
    if s.x <= 0 or s.y <= 0:
        return false
    if point.x < 0.0 or point.x > s.x:
        return false
    if point.y < 0.0 or point.y > s.y:
        return false
    
    var uv_x = point.x / s.x
    var start_y = point.y / s.y
    
    var skewed_y = start_y + (uv_x - 0.5) * skew_amount
    var final_y = (skewed_y - 0.5) * vertical_squish + 0.5
    
    return final_y >= 0.0 and final_y <= 1.0