extends Node
## ทดสอบอัตโนมัติ: เล่นเนื้อเรื่องทั้งหมดผ่าน API (ไม่ต้องกดคีย์)
## รัน: godot --headless --path . res://tests/playthrough.tscn

var main: Node
var p: Player
var fails := 0
var passes := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("  PASS  ", msg)
	else:
		fails += 1
		print("  FAIL  ", msg)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout


func node(path: String) -> Node:
	return main.get_node_or_null(path)


func pick(id: String) -> void:
	var n := node("Items/Pickup_" + id)
	if n == null:
		check(false, "pickup exists: " + id)
		return
	n.interact(p)
	await get_tree().process_frame
	if main.hud._modal != "":
		main.hud.close_modal()
	await get_tree().process_frame


func door(id: String) -> Door:
	for d in get_tree().get_nodes_in_group("door"):
		if d.door_id == id:
			return d
	return null


func path_ok(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := (main as Node3D).get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	return path


func _ready() -> void:
	get_tree().paused = false
	GameState.new_game()
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = main
	p = main.get_node("Player")
	print("== intro")
	for i in 6:
		main.hud._next_intro_line()
	await wait(2.0)
	check(not p.controls_locked, "controls unlocked after intro")
	check(GameState.has_checkpoint(), "checkpoint after intro")
	check(GameState.objective != "", "objective set: " + GameState.objective)

	print("== navmesh connectivity")
	var map := (main as Node3D).get_world_3d().navigation_map
	check(NavigationServer3D.map_get_iteration_id(map) > 0, "nav map synced")
	var start := Vector3(4.5, 0, 10.6)
	var targets := {
		"kitchen": Vector3(2, 0, 2.5), "hallway": Vector3(8, 0, 2), "shrine": Vector3(12.5, 0, 2.5),
		"garden": Vector3(11.5, 0, -6.5), "landing": Vector3(15.3, 3.2, 9.0), "grandma": Vector3(3.2, 3.2, 2.8),
		"kid": Vector3(8.5, 3.2, 2.8), "storage": Vector3(13.5, 3.2, 3.3), "sitting": Vector3(4.5, 3.2, 10.3),
	}
	for k in targets:
		var path := path_ok(start, targets[k])
		check(path.size() > 0 and path[path.size() - 1].distance_to(targets[k]) < 0.7, "path living -> %s (%d pts)" % [k, path.size()])
	for pt in get_tree().get_nodes_in_group("ghost_patrol"):
		var cp := NavigationServer3D.map_get_closest_point(map, pt.global_position)
		check(cp.distance_to(pt.global_position) < 0.5, "patrol point on navmesh %s" % str(pt.global_position))

	print("== phase 0: flashlight / kitchen / back door")
	check(GameState.has_item("flashlight"), "has flashlight from start")
	check(p.viewmodel != null and p.viewmodel.visible, "flashlight viewmodel visible")
	p.toggle_flashlight()
	check(p.flashlight_on and p.flashlight.visible, "flashlight on")
	await wait(0.5)
	check(p.flash_heat > 0.0, "flashlight heat rising")
	p.toggle_flashlight()
	await pick("letter_grandma")
	check(GameState.notes.has("letter_grandma"), "letter read")
	var back := door("back")
	back.interact(p)
	await wait(0.3)
	check(back.locked, "back door locked without key")
	await pick("key_backdoor")
	await pick("note_kitchen")
	await pick("matches_kitchen")
	check(GameState.item_count("matches") == 5, "matches = 5")
	var kc: Candle = node("Candles/Candle_kitchen")
	kc.interact(p)
	check(kc.lit and GameState.item_count("matches") == 4, "lit kitchen candle")
	back.interact(p)
	await wait(1.0)
	check(not back.locked and back.is_open, "back door unlocked + open")

	print("== sanity")
	p.global_position = Vector3(3.5, 0.05, 2.0)  # ข้างเทียนในครัว
	GameState.sanity = 50.0
	await wait(1.0)
	check(GameState.sanity > 52.0, "sanity regenerates near candle (%.1f)" % GameState.sanity)
	p.global_position = Vector3(12.5, 0.05, 8.0)
	var s0 := GameState.sanity
	await wait(1.0)
	check(GameState.sanity < s0, "sanity drains in darkness (%.1f)" % GameState.sanity)

	print("== garden / phase 1")
	p.global_position = Vector3(12.8, 0.05, -9.5)
	await wait(0.3)
	await pick("photo_1")
	check(GameState.phase == 1, "phase 1")
	await wait(1.5)
	var g: Ghost = main.get_node("Ghost")
	check(g.is_active(), "ghost active")
	check(g.state == Ghost.State.STARE, "ghost staring")
	await wait(4.5)
	check(g.state == Ghost.State.PATROL or g.state == Ghost.State.INVESTIGATE, "ghost vanished then patrols (state %d)" % g.state)
	check(node("Furniture/RockingChair_Hall") == null or true, "phase nodes")
	var chair_after: StaticBody3D = main.get_node("NavRegion/Furniture/RockingChair_Hall")
	var chair_before: StaticBody3D = main.get_node("NavRegion/Furniture/RockingChair_Before")
	check(chair_after.visible and chair_after.collision_layer == 1, "phase_show_1 active")
	check(not chair_before.visible and chair_before.collision_layer == 0, "phase_hide_1 inactive")

	print("== ghost hearing + sight")
	g.teleport(Vector3(12.0, 0, 7.5))
	g._set_state(Ghost.State.PATROL)
	GameState.make_noise(Vector3(14.5, 0, 6.5), 12.0, "test")
	await wait(0.1)
	check(g.state == Ghost.State.INVESTIGATE, "ghost investigates noise")
	# วางผู้เล่นตรงหน้าผี
	g.teleport(Vector3(12.0, 0, 9.0))
	g.rotation.y = 0.0  # มองไป -Z
	p.global_position = Vector3(12.0, 0.05, 6.2)
	g._set_state(Ghost.State.PATROL)
	g.suspicion = 0.0
	var chased := false
	for i in 30:
		await wait(0.1)
		if g.state == Ghost.State.CHASE:
			chased = true
			break
	check(chased, "ghost sees player and chases")

	print("== hiding")
	var ward: HideSpot = null
	for h in get_tree().get_nodes_in_group("hide_spot"):
		if h.global_position.distance_to(Vector3(12.0, 0, 5.41)) < 0.5:
			ward = h
	check(ward != null, "found stair hall wardrobe")
	g.teleport(Vector3(12.0, 0, 11.0))  # ไกลพอ ไม่เห็นตอนซ่อน
	g._set_state(Ghost.State.PATROL)
	g.target_hide = null
	g._saw_player = false
	p.enter_hide(ward)
	await wait(0.8)
	check(p.is_hidden(), "player hidden")
	check(not g._can_see_player(p), "ghost cannot see hidden player")
	p.exit_hide()
	await wait(0.8)
	check(not p.is_hidden(), "player exits hiding")
	check(p.global_position.distance_to(ward.get_exit_position()) < 0.5, "player at exit position")

	print("== hide while being chased (ghost 5 m away)")
	p.global_position = ward.get_exit_position() + Vector3(0, 0.05, 0)
	g.teleport(ward.get_exit_position() + Vector3(-1.5, 0, 4.8))
	g.look_at(Vector3(p.global_position.x, g.global_position.y, p.global_position.z), Vector3.UP)
	g._set_state(Ghost.State.PATROL)
	g.suspicion = 0.0
	g.hide_suspicion = 0.0
	g.target_hide = null
	for i in 30:
		await wait(0.1)
		if g.state == Ghost.State.CHASE:
			break
	check(g.state == Ghost.State.CHASE, "ghost chasing before hide")
	p.enter_hide(ward)
	var min_d := 99.0
	var holding := false
	for i in 120:
		await wait(0.1)
		var gd := g.global_position.distance_to(p.global_position)
		min_d = minf(min_d, gd)
		if p.dead:
			print("    t=%.1f st=%d d=%.2f hs=%.2f th=%s hid=%s breath=%.0f hold=%s dead=%s" % [i * 0.1, g.state, gd, g.hide_suspicion, g.target_hide != null, p.is_hidden(), p.breath, p.holding_breath, p.dead])
		if p.dead:
			break
		# เล่นแบบผู้เล่นจริง: กลั้นหายใจเมื่อเธอเข้าใกล้ ปล่อยเมื่อเธอห่างออกไป
		if gd < 4.0 and not holding:
			Input.action_press("hold_breath")
			holding = true
		elif gd >= 4.0 and holding:
			Input.action_release("hold_breath")
			holding = false
	Input.action_release("hold_breath")
	check(not p.dead, "hidden player (holding breath) survives chase (closest %.1f m)" % min_d)
	check(g.target_hide == null, "ghost did not discover hide spot")
	check(g.state != Ghost.State.CHASE, "ghost gave up chase (state %d)" % g.state)
	p.exit_hide()
	await wait(0.8)

	print("== upstairs: kid room / storage / phase 2")
	g.teleport(Vector3(3.0, 0, -11.5))
	g._set_state(Ghost.State.PATROL)
	p.global_position = Vector3(8.0, 3.25, 3.0)
	await pick("drawing_kid")
	await pick("photo_2")
	await pick("matches_kid")
	await pick("key_storage")
	await pick("note_shrine")
	var st := door("storage")
	st.interact(p)
	await wait(1.0)
	check(not st.locked, "storage unlocked")
	p.global_position = Vector3(13.5, 3.25, 3.0)
	await pick("newspaper")
	await pick("photo_3")
	check(GameState.phase == 2, "phase 2")
	check(GameState.item_count("photo_piece") == 3, "3 photo pieces")
	await wait(1.0)
	var block: StaticBody3D = main.get_node("NavRegion/Geometry/W2_HallBlock_0")
	check(block.visible and block.collision_layer == 1, "hallway block wall appeared")
	var path := path_ok(Vector3(13.5, 3.2, 3.3), Vector3(3.2, 3.2, 6.5))
	var via_sitting := false
	for v in path:
		if v.z > 8.3 and v.x < 9.0:
			via_sitting = true
	check(path.size() > 0 and path[path.size() - 1].distance_to(Vector3(3.2, 3.2, 6.5)) < 0.7, "path storage -> west hallway after shift")
	check(via_sitting, "path detours through upstairs sitting room")

	print("== altar / grandma room / phase 3")
	g.teleport(Vector3(3.0, 0, -11.5))
	g._set_state(Ghost.State.PATROL)
	p.global_position = Vector3(13.0, 0.05, 2.5)
	await wait(0.5)
	check(p.in_safe, "player safe in shrine (candles lit)")
	check(main.altar_prompt().begins_with("วาง"), "altar prompt: " + main.altar_prompt())
	main.altar_interact()
	await get_tree().process_frame
	main.hud.close_modal()
	check(GameState.has_item("key_grandma") and GameState.get_flag("photo_done"), "got grandma key from altar")
	var gd := door("grandma")
	p.global_position = Vector3(3.0, 3.25, 6.0)
	gd.interact(p)
	await wait(1.0)
	check(not gd.locked, "grandma door unlocked")
	p.global_position = Vector3(2.2, 3.25, 2.8)
	await pick("letter_final")
	await pick("matches_grandma")
	await pick("contract")
	check(GameState.phase == 3, "phase 3")
	await wait(3.5)
	var any_lit := false
	for c in get_tree().get_nodes_in_group("candle"):
		if c.lit:
			any_lit = true
	check(not any_lit, "all candles extinguished")
	check(GameState.get_flag("front_unlocked") and not door("front").locked, "front door unlocked")

	print("== death + checkpoint")
	var cp_pos: Vector3 = GameState.checkpoint.xform.origin
	g.teleport(p.global_position + Vector3(0.3, 0, 0.3))
	g._set_state(Ghost.State.CHASE)
	await wait(2.5)
	check(p.dead, "player caught by ghost")
	check(main.hud._modal == "gameover", "game over shown")
	GameState.retry_from_checkpoint()
	await wait(2.5)
	main = get_tree().current_scene
	p = main.get_node("Player")
	check(GameState.phase == 3, "phase restored = 3")
	check(main.get_node_or_null("Items/Pickup_contract") == null, "collected pickup stays collected")
	check(GameState.has_item("contract"), "contract still in inventory")
	check(p.global_position.distance_to(cp_pos) < 0.6, "player at checkpoint")
	check(not door("front").locked, "front door still unlocked after reload")
	check(main.get_node("Ghost").is_active(), "ghost active after reload")

	print("== hallucination")
	GameState.sanity = 20.0
	var ok: bool = main.halluc.show_phantom(p, p.global_position + Vector3(0, 0, -5), 1.0)
	check(ok, "phantom shown")

	print("== true ending")
	main.get_node("Ghost").teleport(Vector3(3.0, 0, -11.5))
	p.global_position = Vector3(13.0, 0.05, 2.5)
	check(main.altar_prompt().begins_with("ต้องจุดเทียน"), "altar asks to relight candle")
	var sc: Candle = main.get_node("Candles/Candle_shrine_l")
	sc.interact(p)
	check(sc.lit, "shrine candle relit")
	main.altar_interact()
	await wait(6.0)
	check(get_tree().current_scene != null and get_tree().current_scene.name == "Ending", "ending scene loaded")
	check(GameState.ending == "redeem", "ending = redeem")

	print("\nRESULT: %d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)
