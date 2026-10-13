extends Node
## ทดสอบ: ผีต้องออกมาลาดตระเวนหลังเริ่มเล่นราว 50 วินาที (เร่งเวลา 10 เท่า)
func _ready() -> void:
	var level = load("res://scenes/main.tscn").instantiate()
	add_child(level)
	var g: Ghost = null
	while true:
		await get_tree().process_frame
		g = GameState.ghost
		if g != null and g.nav_ready:
			break
	print("start: phase=", GameState.phase, " ghost active=", g.is_active())
	await get_tree().create_timer(0.5).timeout
	level.hud.intro_finished.emit()
	Engine.time_scale = 10.0
	await get_tree().create_timer(60.0).timeout
	Engine.time_scale = 1.0
	var p: Player = GameState.player
	print("after ~75s: active=", g.is_active(), " visible=", g.visible, " state=", g.state, " dist=", snappedf(g.global_position.distance_to(p.global_position), 0.1), " speeds=", g.patrol_speed, "/", g.chase_speed)
	get_tree().quit()
