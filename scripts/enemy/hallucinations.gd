extends Node3D
class_name Hallucinations
## ภาพหลอนเมื่อสติต่ำ (Sanity)
## < 60 : เสียงกระซิบ (จัดการใน player)
## < 45 : เห็นเงาผู้หญิงยืนอยู่ไกล ๆ — หันไปมองตรง ๆ แล้วหายไป, เสียงเคาะ, เสียงเด็กหัวเราะ, ไฟฉายดับวูบ
## < 25 : เกิดถี่ขึ้น + ข้อความหลอนบนจอ

# สัญญาณส่งข้อความหลอนให้ HUD แสดงเต็มจอ
signal screen_text(text: String)

# ตัวแปรภายใน: ตัวนับเวลาก่อนเกิดภาพหลอนครั้งถัดไป, เงาผู้หญิง (phantom) และโมเดล, อายุของเงา, เวลาที่ผู้เล่นมองเงาอยู่
var _timer := 12.0
var _phantom: Node3D
var _phantom_model: GhostSprite
var _phantom_life := 0.0
var _phantom_seen := 0.0

# ข้อความหลอนที่ขึ้นบนจอเมื่อสติต่ำมาก (< 25)
const SCREEN_LINES := ["กลับมาแล้ว...", "ใช้หนี้", "หนูต้องกลับมาหาพี่นะ", "อย่าหนี", "ยายไม่อยู่แล้ว", "พี่รออยู่"]


# สร้างโหนดเงาผู้หญิง (ใช้โมเดลผีโหมด echo = จางเบลอ) ซ่อนไว้ก่อน
func _ready() -> void:
	_phantom = Node3D.new()
	_phantom.name = "Phantom"
	add_child(_phantom)
	_phantom_model = GhostSprite.new()
	_phantom_model.echo = true
	_phantom.add_child(_phantom_model)
	_phantom.visible = false


# ทุกเฟรม: อัปเดตเงา แล้วถ้าสติต่ำกว่า 45 นับเวลาสุ่มภาพหลอน (สติ < 25 ถี่ขึ้น)
# ผลที่สุ่มได้: เงาผู้หญิง 40% | เสียงเคาะ 15% | เสียงหัวเราะเด็ก 15% | ฝีเท้า 12% | ไฟฉายดับวูบ 8% | ข้อความหลอนบนจอ (สติ < 25) หรือเงา
func _process(delta: float) -> void:
	var p := GameState.player as Player
	if p == null or p.dead:
		_phantom.visible = false
		return
	_update_phantom(delta, p)
	var s := GameState.sanity
	if s >= 45.0:
		_timer = minf(_timer, 14.0)
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(6.0, 14.0) if s > 25.0 else randf_range(3.5, 8.0)
	var roll := randf()
	if roll < 0.4:
		show_phantom(p)
	elif roll < 0.55:
		_sound_near(p, "knock")
	elif roll < 0.7:
		_sound_near(p, "giggle")
	elif roll < 0.82:
		_sound_near(p, "step_wood_%d" % randi_range(1, 4), 2.0)
	elif roll < 0.9 and p.flashlight_on:
		p.flashlight.light_energy = 0.0
		Sfx.play("click", -10.0, 0.7)
	else:
		if s < 25.0:
			screen_text.emit(SCREEN_LINES.pick_random())
			Sfx.play("sting", -10.0, randf_range(0.7, 1.2))
		else:
			show_phantom(p)


# เล่นเสียงหลอนรอบตัวผู้เล่นที่ระยะ 3-6 ม. ทิศสุ่ม
func _sound_near(p: Player, snd: String, vol: float = -2.0) -> void:
	var ang := randf() * TAU
	var pos := p.global_position + Vector3(cos(ang), 0.5, sin(ang)) * randf_range(3.0, 6.0)
	Sfx.play_at(snd, pos, vol, Sfx.random_pitch(0.1))


# แสดงเงาผู้หญิงที่จุด at (ไม่ระบุ = หาจุดมุมตาให้เอง) หันหน้าเข้าหาผู้เล่น อยู่นาน life วินาที คืน false ถ้าไม่ได้แสดง
func show_phantom(p: Player, at: Vector3 = Vector3.INF, life: float = 4.0) -> bool:
	if _phantom.visible:
		return false
	var pos := at
	if pos == Vector3.INF:
		pos = _find_spot(p)
		if pos == Vector3.INF:
			return false
	_phantom.global_position = pos
	var look := p.global_position
	look.y = pos.y
	if look.distance_to(pos) > 0.1:
		_phantom.look_at(look, Vector3.UP)
	_phantom.visible = true
	_phantom_model.set_fade(0.0)
	_phantom_life = life
	_phantom_seen = 0.0
	return true


# หาจุดให้เงาปรากฏ: ด้านข้างหางตาของผู้เล่น (25-70° จากทิศที่มอง) ห่าง 5-10 ม. ชั้นเดียวกันและผู้เล่นมองเห็นได้
func _find_spot(p: Player) -> Vector3:
	var cam := p.camera
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var map := get_world_3d().navigation_map
	for i in 12:
		# มุมด้านข้าง/หางตา
		var ang := randf_range(25.0, 70.0) * (1.0 if randf() < 0.5 else -1.0)
		var dir := fwd.rotated(Vector3.UP, deg_to_rad(ang))
		var cand := p.global_position + dir * randf_range(5.0, 10.0)
		cand = NavigationServer3D.map_get_closest_point(map, cand)
		if absf(cand.y - p.global_position.y) > 1.0:
			continue
		if cand.distance_to(p.global_position) < 4.0:
			continue
		if p.can_see_point(cand + Vector3.UP * 1.3):
			return cand
	return Vector3.INF


# เงาค่อย ๆ ชัดขึ้น ถ้าผู้เล่นหันมามองตรง ๆ (ภายใน 10°) ประมาณ 0.25 วินาที หรือผู้เล่นเดินเข้าใกล้ 3 ม. หรือหมดเวลา เงาจะหายไป
# ถ้าเห็นตรง ๆ: เสียงตกใจ และสติลด 4
func _update_phantom(delta: float, p: Player) -> void:
	if not _phantom.visible:
		return
	_phantom_life -= delta
	_phantom_model.set_fade(minf(_phantom_model.get_fade() + delta * 1.5, 0.9))
	var head := _phantom.global_position + Vector3.UP * 1.5
	var to := (head - p.camera.global_position).normalized()
	var fwd := -p.camera.global_transform.basis.z
	var looking := fwd.angle_to(to) < deg_to_rad(10.0)
	if looking:
		_phantom_seen += delta
	if _phantom_seen > 0.25 or _phantom_life <= 0.0 or p.global_position.distance_to(_phantom.global_position) < 3.0:
		_phantom.visible = false
		if _phantom_seen > 0.0:
			Sfx.play("sting", -6.0, randf_range(0.8, 1.2))
			GameState.sanity = maxf(GameState.sanity - 4.0, 0.0)
