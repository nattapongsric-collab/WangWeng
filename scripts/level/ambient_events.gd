extends Node
class_name AmbientEvents
## เสียงหลอนสุ่มรอบตัวผู้เล่น (ไม้ลั่นชั้นบน ฝีเท้าบนหัว ประตูเอี๊ยด น้ำหยด เสียงสะอื้น กล่องดนตรี ฯลฯ)
## ยิ่งเฟสสูง / สติต่ำ ยิ่งเกิดถี่ขึ้น

# กลุ่มเสียงที่สุ่ม: ในบ้านปกติ / ในบ้านแบบน่ากลัว (เพิ่มตั้งแต่บท 1) / นอกบ้าน
const INDOOR := ["amb_creak_1", "amb_creak_2", "amb_creak_3", "amb_steps_upstairs", "amb_door_creak", "amb_drip", "amb_thud", "knock", "amb_chime"]
const INDOOR_SCARY := ["amb_sob", "giggle", "music_box", "whisper", "amb_steps_upstairs"]
const OUTDOOR := ["amb_chime", "amb_creak_1", "knock", "giggle", "amb_sob"]

# ตัวนับเวลาก่อนเสียงครั้งถัดไป และเสียงล่าสุด (กันซ้ำติดกัน)
var _t := 9.0
var _last := ""


# ทุกเฟรมนับเวลา ถึงกำหนดแล้วสุ่มเสียงหลอนหนึ่งเสียง
# ช่วงเวลา: 24 วินาที ลดลง 4 วินาทีต่อบท และถี่ขึ้นอีก 30% ถ้าสติต่ำกว่า 50 / สติต่ำกว่า 45 ในบ้านอาจได้ยินเสียงหายใจชิดหู
func _process(delta: float) -> void:
	var p := GameState.player as Player
	if p == null or p.dead or get_tree().paused:
		return
	_t -= delta
	if _t > 0.0:
		return
	var base := 24.0 - GameState.phase * 4.0
	if GameState.sanity < 50.0:
		base *= 0.7
	_t = randf_range(base * 0.45, base)
	var outside := p.global_position.z < 0.2 and p.global_position.y < 1.5
	var pool: Array = []
	if outside:
		pool = OUTDOOR.duplicate()
	else:
		pool = INDOOR.duplicate()
		if GameState.phase >= 1:
			pool.append_array(INDOOR_SCARY)
	if GameState.sanity < 45.0 and not outside:
		pool.append("amb_breath_close")
	pool.erase(_last)
	var snd: String = pool.pick_random()
	_last = snd
	play_event(snd, p)


# เล่นเสียง snd รอบตัวผู้เล่น (ระยะ 5-11 ม. ทิศสุ่ม)
# เสียงพิเศษ: ฝีเท้าบนหัว/ล่างเท้า (มาจากอีกชั้น) | หายใจชิดหู (เสียงอยู่ข้างหลังกล้อง) | กล่องดนตรี (เบา) | เสียงตึง (ดังกว่า)
func play_event(snd: String, p: Player) -> void:
	var ang := randf() * TAU
	var dist := randf_range(5.0, 11.0)
	var pos := p.global_position + Vector3(cos(ang) * dist, 1.2, sin(ang) * dist)
	var vol := randf_range(-6.0, 0.0)
	match snd:
		"amb_steps_upstairs":
			# ถ้าอยู่ชั้นล่าง เสียงมาจากชั้นบน / ถ้าอยู่ชั้นบน เสียงมาจากข้างล่าง
			pos.y = p.global_position.y + (3.3 if p.global_position.y < 2.0 else -2.8)
			pos = p.global_position.lerp(pos, 0.5) + Vector3(0, pos.y - p.global_position.y, 0) * 0.5
			vol = 2.0
		"amb_breath_close":
			var back := p.camera.global_transform.basis.z.normalized()
			pos = p.camera.global_position + back * 0.5
			vol = -4.0
		"music_box":
			vol = -8.0
		"amb_thud":
			vol = -2.0
	Sfx.play_at(snd, pos, vol, randf_range(0.93, 1.05), 30.0)
