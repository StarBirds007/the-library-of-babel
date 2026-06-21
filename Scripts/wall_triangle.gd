extends TextureButton


func _ready() -> void:
    if material:
        material = material.duplicate(true)


func _has_point(point: Vector2) -> bool:
    var s = size
    if s.x <= 0 or s.y <= 0:
        return false
    if point.x < 0.0 or point.x > s.x:
        return false
    if point.y < 0.0 or point.y > s.y:
        return false
    
    var point_right := true
    var mat := material as ShaderMaterial
    if mat:
        point_right = mat.get_shader_parameter("point_right")
    
    var uv_x = point.x / s.x
    var uv_y = point.y / s.y
    
    var tip_x = 1.0 if point_right else 0.0
    var distance_from_tip = abs(uv_x - tip_x)
    var half_height_at_x = 0.5 * distance_from_tip
    
    return abs(uv_y - 0.5) <= half_height_at_x