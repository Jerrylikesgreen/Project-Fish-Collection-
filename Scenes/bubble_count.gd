class_name BubbleCount extends Label


func _ready() -> void:
	Events.bubble_count_changed_signal.connect(_on_bubble_count)
	set_text("Bubble Count: ")


func _on_bubble_count(bubble_count:int)->void:
	var new_text = str(bubble_count)
	set_text(new_text)
	pass
