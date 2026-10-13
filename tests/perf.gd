extends Node
func _ready():
	GameState.new_game()
	GameState.inventory["flashlight"] = 1
	GameState.checkpoint = {"phase": 0, "inventory": GameState.inventory.duplicate(), "notes": [], "collected": {}, "unlocked_doors": {}, "lit_candles": {}, "flags": {}, "objective": "", "sanity": 100.0, "xform": Transform3D(Basis(), Vector3(4.5, 0.05, 10.6)), "look": Vector2.ZERO}
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(2.0).timeout
	var p = main.get_node("Player")
	p.toggle_flashlight(true)
	for view in [[Vector3(4.5,0.05,10.6), 10.0], [Vector3(8,0.05,-1), 15.0], [Vector3(15.3,3.25,9.5), 90.0]]:
		p.global_position = view[0]
		p.apply_look(Vector2(deg_to_rad(view[1]), 0))
		await get_tree().create_timer(1.0).timeout
		print("view ", view[0], " draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " fps=", Engine.get_frames_per_second())
	for c in main.get_children():
		var n := 0
		for v in c.find_children("*", "GeometryInstance3D", true, false):
			if v.is_visible_in_tree():
				n += 1
		print(c.name, ": ", n)
	for c in main.get_node("NavRegion").get_children():
		var n := 0
		for v in c.find_children("*", "GeometryInstance3D", true, false):
			if v.is_visible_in_tree():
				n += 1
		print("  nav/", c.name, ": ", n)
	get_tree().quit()
