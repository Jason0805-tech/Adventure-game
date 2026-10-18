extends Node2D

# Full-resolution painted ground. Source rasters are never reduced to match objects.
var ground_texture: Texture2D
var world_size := Vector2.ZERO
var detail_mesh: ArrayMesh = null
var stroke_count := 0
var vertex_count := 0

func setup(texture: Texture2D, size: Vector2) -> void:
	ground_texture = texture
	world_size = size
	show_behind_parent = true
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(false)
	queue_redraw()

func _draw() -> void:
	if ground_texture != null:
		draw_texture_rect(ground_texture, Rect2(Vector2.ZERO, world_size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, world_size), Color("71927b"))
