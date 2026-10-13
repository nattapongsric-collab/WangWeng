extends Node
## ทดสอบเก็บเศษรูปผิดลำดับ (ชิ้นในห้องเด็กก่อน) → ผีต้องตื่น
func _ready():
	GameState.new_game()
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = main
	for i in 6:
		main.hud._next_intro_line()
	await get_tree().create_timer(2.0).timeout
	var p = main.get_node("Player")
	p.global_position = Vector3(8.0, 3.25, 2.5)
	main.get_node("Items/Pickup_photo_2").interact(p)
	await get_tree().create_timer(2.0).timeout
	var g = main.get_node("Ghost")
	var ok: bool = GameState.phase == 1 and g.is_active()
	print("ORDER TEST: ", "PASS" if ok else "FAIL", " phase=", GameState.phase, " ghost_state=", g.state, " at ", g.global_position)
	get_tree().quit()
