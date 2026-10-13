extends Node
## ทดสอบ: เสียงที่ตั้งลูปไว้ (breath) เมื่อเล่นแบบ one-shot ต้องจบเอง ไม่วนไม่หยุด
func _ready() -> void:
	var p := Sfx.play("breath", 0.0, 1.3)
	var loop_player_stream := Sfx.get_stream("breath") as AudioStreamWAV
	print("shared stream loop_mode=", loop_player_stream.loop_mode, " (ลูปเดิมยังต้องเป็น 1 ไว้ให้ลูปหายใจ)")
	print("oneshot stream loop_mode=", (p.stream as AudioStreamWAV).loop_mode)
	await get_tree().create_timer(5.0).timeout
	print("after 5 s one-shot still alive: ", is_instance_valid(p))
	get_tree().quit()
