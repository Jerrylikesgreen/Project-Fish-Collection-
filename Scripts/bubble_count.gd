class_name BubbleCount extends Label

var bubble_count:int = 0

func _ready() -> void:
	Events.bubble_count_changed_signal.connect(_on_bubble_count)


func _on_bubble_count(new_bubble_count:int)->void:
	bubble_count = new_bubble_count
	var new_text = str(bubble_count)
	set_text(new_text)
