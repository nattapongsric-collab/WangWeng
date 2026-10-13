extends Node
## ทดสอบ: ซ่อนตู้ตอนผีไล่ตาม แล้วผีหาเจอไหม (วิ่งหลายรอบ)
var level
var runs := 1
var found := 0

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _ready() -> void:
	Engine.time_scale = 4.0
	for r in runs:
		level = load("res://scenes/main.tscn").instantiate()
		add_child(level)
		var g: Ghost = null
		while true:
			await get_tree().process_frame
			g = GameState.ghost
			if g != null and g.nav_ready:
				break
		var p: Player = GameState.player
		await wait(0.3)
		p.controls_locked = false
		var spots := get_tree().get_nodes_in_group("hide_spot")
		var spot: Node3D = null
		for s in spots:
			if s.kind == "wardrobe":
				spot = s
				break
		var front: Vector3 = spot.get_exit_position()
		g.activate(front + Vector3(0, 0, 0), false)
		# ผีอยู่ไกล ๆ แล้วไล่ตาม (ไม่เห็นเราตอนมุด)
		p.global_position = front
		var far_pt := front
		for pt in get_tree().get_nodes_in_group("ghost_patrol"):
			var d: float = (pt as Node3D).global_position.distance_to(front)
			if d > 3.5 and d < 6.0:
				far_pt = (pt as Node3D).global_position
				break
		g.teleport(far_pt)
		g._set_state(Ghost.State.CHASE)
		g.last_seen = far_pt
		g.lost_time = 0.2
		print("ghost dist=", g.global_position.distance_to(front), " front=", front)
		p.enter_hide(spot)
		var caught := false
		var t := 0.0
		while t < 20.0:
			await wait(0.5)
			t += 0.5
			if p.dead:
				caught = true
				break
		print("run ", r, " th=", g.target_hide != null, " caught=", caught, " t=", t, " state=", g.state, " sanity=", GameState.sanity)
		if caught:
			found += 1
		level.queue_free()
		await wait(0.3)
	print("RESULT found ", found, "/", runs)
	get_tree().quit()
