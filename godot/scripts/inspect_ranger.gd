extends SceneTree
func _initialize() -> void:
	var scene=load("res://assets/ranger.glb").instantiate()
	root.add_child(scene)
	for node in scene.find_children("*","AnimationPlayer",true,false):print("IMPORTED_ANIMATIONS ",node.get_animation_list())
	quit()
