extends Node
## ซ้ำฉาก "ซ่อนตู้ตอนผีไล่อยู่ห่าง 5 ม." หลายรอบ เพื่อดูว่าผีหาเจอด้วยสาเหตุอะไร
var trials := 12
var log := []
func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
func _ready() -> void:
	var level = load("res://scenes/main.tscn").instantiate()
	add_child(level)
	while GameState.ghost == null or not GameState.ghost.nav_ready:
		await get_tree().process_frame
	var g: Ghost = GameState.ghost
	var p: Player = GameState.player
	level.hud.intro_finished.emit()
	await wait(3.0)
	Engine.time_scale = 4.0
	var ward: HideSpot = null
	for h in get_tree().get_nodes_in_group("hide_spot"):
		if h.global_position.distance_to(Vector3(12.0, 0, 5.41)) < 0.5:
			ward = h
	GameState.advance_phase(1)
	g.activate(Vector3(12, 0, 11), false)
	await wait(1.0)
	var found := 0
	var dead := 0
	var gaveup := 0
	for t in trials:
		p.dead = false
		GameState.sanity = 100.0
		g.hide_suspicion = 0.0
		p.controls_locked = false
		if p.is_hidden():
			p.hidden_in = null
			p.col.disabled = false
		p.breath = 100.0
		p.breath_exhausted = 0.0
		p.global_position = ward.get_exit_position() + Vector3(0, 0.05, 0)
		g.teleport(ward.get_exit_position() + Vector3(-1.5, 0, 4.8))
		g.look_at(Vector3(p.global_position.x, g.global_position.y, p.global_position.z), Vector3.UP)
		g._set_state(Ghost.State.PATROL)
		g.suspicion = 0.0
		g.hide_suspicion = 0.0
		g.target_hide = null
		for i in 40:
			await wait(0.1)
			if g.state == Ghost.State.CHASE:
				break
		var chasing := g.state == Ghost.State.CHASE
		var reason := ""
		var noises := []
		var cb := func(pos: Vector3, rad: float, src: String):
			if src == "breath" or src == "gasp":
				noises.append("%s@%.1fm" % [src, g.global_position.distance_to(pos)])
		GameState.noise_made.connect(cb)
		p.enter_hide(ward)
		var holding := false
		var t_found := -1.0
		for i in 150:
			await wait(0.1)
			var gd := g.global_position.distance_to(p.global_position)
			if g.target_hide != null and t_found < 0.0:
				t_found = i * 0.1
			if p.dead:
				break
			if gd < 4.0 and not holding:
				Input.action_press("hold_breath")
				holding = true
			elif gd >= 4.0 and holding:
				Input.action_release("hold_breath")
				holding = false
		Input.action_release("hold_breath")
		GameState.noise_made.disconnect(cb)
		var disc := g.target_hide != null or p.dead
		if disc: found += 1
		if p.dead: dead += 1
		if g.state != Ghost.State.CHASE: gaveup += 1
		print("trial %2d chasing=%s discovered=%s at=%.1fs dead=%s state=%d noises=%s" % [t, chasing, disc, t_found, p.dead, g.state, str(noises.slice(0, 8))])
		p.exit_hide()
		await wait(1.0)
	print("SUMMARY: discovered ", found, "/", trials, " dead ", dead, " gaveup ", gaveup)
	Engine.time_scale = 1.0
	get_tree().quit()
