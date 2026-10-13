extends Node
## ถ่ายภาพหน้าจอจากมุมต่าง ๆ (ใช้ตรวจภาพ) — รันแบบมีหน้าจอ (ไม่ใช่ headless)

const OUT := "user://shots/"
var main: Node
var p: Player


func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(OUT + name + ".png")
	print("shot ", name)


func place(pos: Vector3, yaw_deg: float, pitch_deg: float = 0.0, flash: bool = false) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.apply_look(Vector2(deg_to_rad(yaw_deg), deg_to_rad(pitch_deg)))
	p.toggle_flashlight(flash)
	p.flash_heat = 0.0
	GameState.sanity = 100.0


func _ready() -> void:
	var which := OS.get_environment("SHOTS")
	if which == "menu":
		get_tree().root.add_child.call_deferred(load("res://scenes/main_menu.tscn").instantiate())
		await get_tree().create_timer(1.5).timeout
		await shot("00_menu")
		get_tree().quit()
		return
	if which == "ending":
		GameState.ending = "redeem"
		GameState.play_time = 1234.0
		get_tree().root.add_child.call_deferred(load("res://scenes/ending.tscn").instantiate())
		await get_tree().create_timer(14.0).timeout
		await shot("16_ending")
		get_tree().quit()
		return
	if which == "intro":
		GameState.new_game()
		get_tree().root.add_child.call_deferred(load("res://scenes/main.tscn").instantiate())
		await get_tree().create_timer(3.0).timeout
		var lv = get_tree().root.get_node("Main")
		print("intro text=", lv.hud.intro_label.text, " ratio=", lv.hud.intro_label.visible_ratio, " vis=", lv.hud.intro_label.is_visible_in_tree(), " size=", lv.hud.intro_label.size, " pos=", lv.hud.intro_label.global_position, " modal=", lv.hud._modal)
		await shot("17_intro")
		get_tree().quit()
		return
	GameState.new_game()
	GameState.inventory["flashlight"] = 1
	GameState.checkpoint = {"phase": 0, "inventory": GameState.inventory.duplicate(), "notes": [], "collected": {"flashlight": true}, "unlocked_doors": {"back": true},
		"lit_candles": {}, "flags": {}, "objective": "สำรวจบ้าน — หาอะไรสักอย่างไว้ส่องทาง", "sanity": 100.0,
		"xform": Transform3D(Basis(), Vector3(4.5, 0.05, 10.6)), "look": Vector2.ZERO}
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(2.0).timeout
	get_tree().current_scene = main
	p = main.get_node("Player")
	p.controls_locked = true
	main.hud.fade.modulate.a = 0.0

	place(Vector3(4.5, 0.05, 10.6), 10, -12, true)
	await shot("01_living_flash")
	place(Vector3(4.5, 0.05, 10.6), 30, -5, false)
	await shot("02_living_dark")
	place(Vector3(3.5, 0.05, 4.4), 0, -15, true)
	await shot("03_kitchen")
	place(Vector3(10.2, 0.05, 2.5), -90, -5, false)
	await shot("04_shrine")
	place(Vector3(9.4, 0.05, 9.2), -115, 18, true)
	await shot("05_stairs")
	place(Vector3(15.3, 3.25, 9.5), 90, 0, true)
	await shot("06_upper_hall")
	place(Vector3(8.0, 0.05, -1.0), 15, 0, false)
	await shot("07_garden")
	place(Vector3(13.5, 0.05, -12.8), 200, 10, false)
	await shot("08_house_exterior")
	# ผีระยะใกล้
	var g: Ghost = main.get_node("Ghost")
	GameState.phase = 1
	g.activate(Vector3(5.0, 0, 7.0), false)
	g.nav_ready = false
	g.global_position = Vector3(4.6, 0, 7.4)
	g.rotation.y = PI
	place(Vector3(4.5, 0.05, 10.6), 0, 5, true)
	await shot("09_ghost")
	g.global_position = Vector3(4.5, 0, 9.3)
	place(Vector3(4.5, 0.05, 10.6), 0, 2, true)
	await shot("09b_ghost_close")
	g.global_position = Vector3(3.0, 0, 7.0)
	place(Vector3(4.5, 0.05, 10.6), 20, 0, false)
	await shot("10_ghost_dark")
	g.global_position = Vector3(12.5, 0, 7.5)
	place(Vector3(9.6, 0.05, 8.0), -90, 0, true)
	g._set_state(Ghost.State.CHASE)
	await get_tree().create_timer(0.1).timeout
	await shot("10b_ghost_chase")
	g.set_dormant()
	main.hud.show_jumpscare()
	await get_tree().create_timer(0.15).timeout
	await shot("18_jumpscare")
	await get_tree().create_timer(1.5).timeout
	# ซ่อนในตู้
	var ward: HideSpot
	for h in get_tree().get_nodes_in_group("hide_spot"):
		if h.global_position.distance_to(Vector3(12.0, 0, 5.41)) < 0.5:
			ward = h
	p.controls_locked = false
	p.enter_hide(ward)
	await get_tree().create_timer(0.8).timeout
	await shot("11_hiding")
	p.exit_hide()
	await get_tree().create_timer(0.8).timeout
	# จดหมาย UI
	main.hud.open_note("letter_grandma")
	await shot("12_note")
	main.hud.close_modal()
	main.hud.open_journal()
	await shot("13_journal")
	main.hud.close_modal()
	# สติต่ำ
	place(Vector3(2.0, 3.25, 10.5), 120, 0, true)
	GameState.sanity = 15.0
	p.controls_locked = true
	await get_tree().create_timer(0.3).timeout
	await shot("14_low_sanity")
	# เฟส 3 บรรยากาศแดง
	main._set_hunt_mood(true)
	GameState.phase = 3
	place(Vector3(4.5, 0.05, 10.6), 10, -5, true)
	await shot("15_phase3")
	get_tree().quit()
