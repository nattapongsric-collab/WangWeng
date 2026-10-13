extends Node
## ทดสอบบันได: ขึ้นแล้วลงได้ไหม
func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
func walk(p: Player, yaw: float, secs: float) -> void:
	p.rotation.y = yaw
	Input.action_press("move_forward")
	await wait(secs)
	Input.action_release("move_forward")
func _ready() -> void:
	var level = load("res://scenes/main.tscn").instantiate()
	add_child(level)
	while GameState.ghost == null or not GameState.ghost.nav_ready:
		await get_tree().process_frame
	var p: Player = GameState.player
	level.hud.intro_finished.emit()
	await wait(4.0)
	p.controls_locked = false
	# เริ่มที่ปลายล่างของบันได หันไป +x (ขึ้น)
	p.global_position = Vector3(9.2, 0.05, 11.05)
	await wait(0.4)
	await walk(p, -PI / 2.0, 4.0)
	print("UP:   pos=", p.global_position)
	# เดินต่อไปบนพื้นชั้น 2 แล้วหันกลับลง
	await walk(p, -PI / 2.0, 0.6)
	print("TOP:  pos=", p.global_position)
	await walk(p, PI / 2.0, 5.0)
	var sp := p.get_world_3d().direct_space_state
	var xs := [13.0, 13.8, 14.2, 14.4, 14.5, 14.6, 14.7, 14.8, 15.0, 15.3]
	var line := "ground heights z=11.05: "
	for x in xs:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 6.0, 11.05), Vector3(x, -1.0, 11.05), 1)
		var r := sp.intersect_ray(q)
		line += "x=%.1f->%s  " % [x, ("%.2f" % r.position.y) if not r.is_empty() else "none"]
	print(line)
	for i in p.get_slide_collision_count():
		var c := p.get_slide_collision(i)
		print("slide hit: ", (c.get_collider() as Node).get_path(), " normal=", c.get_normal(), " pos=", c.get_position())
	# ยิงรังสีแนวนอนไปทาง -x ที่ความสูงเท้า/เอว หาตัวบล็อก
	for h in [0.1, 0.4, 0.9, 1.5]:
		var q2 := PhysicsRayQueryParameters3D.create(Vector3(15.0, 3.2 + h, 11.05), Vector3(13.5, 3.2 + h, 11.05), 1)
		var r2 := sp.intersect_ray(q2)
		print("horizontal ray h=", h, " -> ", ("%s at x=%.2f" % [(r2.collider as Node).get_path(), r2.position.x]) if not r2.is_empty() else "clear")
	print("DOWN: pos=", p.global_position, " (ควรกลับมาที่ x<11, y~0)")
	get_tree().quit()
