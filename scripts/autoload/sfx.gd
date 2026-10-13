extends Node
## Sfx (Autoload) — เล่นเสียงแบบ one-shot ทั้ง 2D และ 3D
## ใช้: Sfx.play("pickup")  หรือ  Sfx.play_at("door_open", global_position)

# โฟลเดอร์ไฟล์เสียง (.wav ทั้งหมด) / แคชเสียงที่โหลดแล้ว / แคชเสียงลูปที่ถูกทำสำเนาเป็นแบบเล่นรอบเดียว
const DIR := "res://assets/audio/"
var _cache := {}
var _oneshot := {}


# ทำงานต่อแม้เกมหยุดชั่วคราว (เมนู Esc ยังมีเสียงปุ่ม)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# โหลดไฟล์เสียงตามชื่อ (เช่น "door_open" → assets/audio/door_open.wav) แล้วจำไว้ ไม่เจอไฟล์ = เตือนใน log
func get_stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var path := DIR + sound_name + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("Sfx: ไม่พบไฟล์เสียง " + path)
		return null
	var s: AudioStream = load(path)
	_cache[sound_name] = s
	return s


## เสียงที่ตั้งลูปไว้ (เช่น breath, whisper) ถ้าเล่นแบบ one-shot ต้องไม่วน ไม่งั้นดังไม่หยุด
# (ดูคำอธิบายด้านบน) กันเสียงที่ตั้งลูปไว้ไม่ให้วนไม่หยุดเมื่อเล่นแบบรอบเดียว
func _oneshot_stream(sound_name: String, s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
		if not _oneshot.has(sound_name):
			var d := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
			d.loop_mode = AudioStreamWAV.LOOP_DISABLED
			_oneshot[sound_name] = d
		return _oneshot[sound_name]
	return s


# เล่นเสียง 2D (ไม่มีทิศทาง) เช่น เสียงตกใจ เสียงหัวใจ — เล่นจบแล้วลบตัวเล่นทิ้งเอง
func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> AudioStreamPlayer:
	var s := get_stream(sound_name)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = _oneshot_stream(sound_name, s)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


# เล่นเสียง 3D ที่ตำแหน่ง pos (ดังตามระยะ ได้ยินจากทิศทางนั้น) เช่น เสียงฝีเท้า เสียงประตู max_dist = ไกลสุดที่ได้ยิน
func play_at(sound_name: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_dist: float = 30.0) -> AudioStreamPlayer3D:
	var s := get_stream(sound_name)
	if s == null:
		return null
	var scene := get_tree().current_scene
	if scene == null or not (scene is Node3D):
		play(sound_name, volume_db, pitch)
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = _oneshot_stream(sound_name, s)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = "SFX"
	p.unit_size = 4.0
	p.max_distance = max_dist
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


# สุ่มระดับเสียงเพี้ยนเล็กน้อย (±spread) ให้เสียงซ้ำ ๆ ไม่เหมือนเป๊ะทุกครั้ง
func random_pitch(spread: float = 0.08) -> float:
	return 1.0 + randf_range(-spread, spread)
