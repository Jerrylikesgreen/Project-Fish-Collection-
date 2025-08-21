class DebugCross:
	extends Node2D

	func _draw() -> void:
		draw_line(Vector2(-12, 0), Vector2(12, 0), Color.RED, 2.0)
		draw_line(Vector2(0, -12), Vector2(0, 12), Color.RED, 2.0)
		draw_circle(Vector2.ZERO, 6.0, Color.YELLOW)

	func _ready() -> void:
		z_index = 9999
		z_as_relative = false
		update()
