@tool
extends Node3D
class_name Door
## ประตูบานพับ — ตั้งตำแหน่งโหนดนี้ที่ "บานพับ" บานประตูจะยื่นไปทางแกน +X ของโหนด
## locked + key_id = ต้องมีกุญแจ, is_exit = ประตูหน้าบ้าน (ฉากจบหนีออก)
## ผีลอยทะลุประตูได้ (ประตูอยู่นอก NavigationRegion3D จึงไม่ถูกนับเป็นสิ่งกีดขวาง)

# ตั้งค่าได้จาก Inspector: รหัสประตู ขนาด ล็อกไหม ต้องใช้กุญแจรหัสอะไร ข้อความตอนล็อก เป็นประตูหน้าบ้าน (ฉากจบ) ไหม มุมที่เปิด และสีไม้
@export var door_id := "door"
@export var width := 1.0
@export var height := 2.2
@export var locked := false
@export var key_id := ""
@export_multiline var locked_text := "ล็อกอยู่"
@export var is_exit := false
@export var open_angle := 100.0
@export var tint := Color(0.55, 0.42, 0.32)

# ตัวแปรภายใน: เปิดอยู่ไหม, บานประตู, ตัวทำแอนิเมชัน, กำลังเคลื่อนไหวอยู่ไหม (กันกดซ้ำ)
var is_open := false
var _leaf: AnimatableBody3D
var _tween: Tween
var _busy := false


# เริ่มต้น: สร้างประตู ลงทะเบียนในกลุ่ม door และถ้าเคยปลดล็อกไว้แล้ว (โหลดจากจุดเซฟ) ให้ปลดล็อกเลย
func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("door")
	if GameState.unlocked_doors.has(door_id):
		locked = false


# สร้างบานประตูด้วยโค้ด: ตัวชน ไม้ ลายแผงลูกฟักแบบไทย ลูกบิดทองเหลือง (ประตูหน้ามีสายสิญจน์พาด)
func _build() -> void:
	for c in get_children():
		c.queue_free()
	_leaf = AnimatableBody3D.new()
	_leaf.name = "Leaf"
	_leaf.collision_layer = 8
	_leaf.collision_mask = 0
	_leaf.sync_to_physics = true
	add_child(_leaf)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(width - 0.02, height - 0.02, 0.07)
	cs.shape = sh
	cs.position = Vector3(width * 0.5, height * 0.5, 0)
	_leaf.add_child(cs)
	var wood := MatLib.textured("wood_dark", 0.8, tint)
	MatLib.box(_leaf, Vector3(width - 0.02, height - 0.02, 0.06), Vector3(width * 0.5, height * 0.5, 0), wood)
	# ลวดลายบานประตูไม้แบบไทย (แผงลูกฟัก)
	var panel := MatLib.textured("wood_dark", 1.3, tint.darkened(0.25))
	for z in [-0.035, 0.035]:
		MatLib.box(_leaf, Vector3(width * 0.62, height * 0.32, 0.012), Vector3(width * 0.5, height * 0.72, z), panel)
		MatLib.box(_leaf, Vector3(width * 0.62, height * 0.32, 0.012), Vector3(width * 0.5, height * 0.3, z), panel)
	var brass := MatLib.color(Color(0.7, 0.55, 0.25), 0.3, 0.9)
	for z in [-0.05, 0.05]:
		MatLib.sphere(_leaf, 0.03, Vector3(width - 0.12, 1.0, z), brass)
	if not Engine.is_editor_hint():
		MatLib.merge_children(_leaf)
	if is_exit:
		# สายสิญจน์พาดประตู
		var thread := MatLib.color(Color(0.9, 0.88, 0.8), 0.9)
		MatLib.box(self, Vector3(width * 1.15, 0.012, 0.012), Vector3(width * 0.5, 1.5, 0.08), thread, Vector3(0, 0, 18))
		MatLib.box(self, Vector3(width * 1.15, 0.012, 0.012), Vector3(width * 0.5, 1.5, 0.08), thread, Vector3(0, 0, -18))


# โต้ตอบได้เมื่อประตูไม่ได้กำลังขยับอยู่
func can_interact(_p: Node) -> bool:
	return not _busy


# ข้อความที่แสดงบน HUD ตามสถานะ: ล็อก / ปลดล็อกด้วยกุญแจ / หนีออกไป / เปิด-ปิด
func get_prompt(_p: Node) -> String:
	if locked:
		if key_id != "" and GameState.has_item(key_id):
			return "ปลดล็อกด้วย " + GameState.item_name(key_id)
		return "ประตูล็อกอยู่"
	if is_exit:
		return "หนีออกไป!"
	return "ปิดประตู" if is_open else "เปิดประตู"


# กด E ที่ประตู
# ล็อก: มีกุญแจ = ปลดล็อกแล้วเปิด / ไม่มี = เสียงล็อก ข้อความบอก และมีเสียงดังรัศมี 3 ม.
# ประตูหน้าบ้าน = จบเกมแบบหนี | ปกติ = สลับเปิด/ปิด
func interact(p: Node) -> void:
	if _busy:
		return
	if locked:
		if key_id != "" and GameState.has_item(key_id):
			unlock(true)
			GameState.say("ปลดล็อกด้วย " + GameState.item_name(key_id), 2.0)
			_open_from(p)
		else:
			Sfx.play_at("door_locked", global_position + Vector3(width * 0.5, 1, 0), 0.0)
			GameState.make_noise(global_position, 3.0, "door")
			GameState.say(locked_text, 2.5)
		return
	if is_exit:
		if GameState.level and GameState.level.has_method("trigger_ending"):
			GameState.level.trigger_ending("escape")
		return
	if is_open:
		close()
	else:
		_open_from(p)


# ปลดล็อกประตู และจำไว้ใน GameState (ไม่ล็อกอีกแม้โหลดเซฟ)
func unlock(play_sound: bool = true) -> void:
	locked = false
	GameState.unlocked_doors[door_id] = true
	if play_sound:
		Sfx.play_at("unlock", global_position + Vector3(width * 0.5, 1, 0), 0.0)


# เปิดประตูให้เปิดออกไปทางด้านตรงข้ามผู้เล่น — เสียงเปิดดังรัศมี 4 ม. ผีได้ยิน
func _open_from(p: Node) -> void:
	var side := 1.0
	if p is Node3D:
		var local := to_local((p as Node3D).global_position)
		side = 1.0 if local.z > 0.0 else -1.0
	_swing(deg_to_rad(open_angle) * side, 0.7)
	is_open = true
	Sfx.play_at("door_open", global_position + Vector3(width * 0.5, 1, 0), -6.0, Sfx.random_pitch(0.1))
	GameState.make_noise(global_position, 4.0, "door")


# ปิดประตู มีเสียงปิดและเสียงดังรัศมี 4 ม.
func close() -> void:
	_swing(0.0, 0.5)
	is_open = false
	get_tree().create_timer(0.45).timeout.connect(func(): Sfx.play_at("door_close", global_position + Vector3(width * 0.5, 1, 0), -4.0))
	GameState.make_noise(global_position, 4.0, "door")


# ประตูปิดกระแทกเร็ว ๆ (ใช้ในเหตุการณ์ในเรื่อง เช่น ประตูครัวตอนเข้าบทที่ 1)
func slam() -> void:
	_swing(0.0, 0.15)
	is_open = false
	Sfx.play_at("door_slam", global_position + Vector3(width * 0.5, 1, 0), 4.0)


# หมุนบานประตูไปที่มุม angle ใน dur วินาที (ระหว่างนั้นกดซ้ำไม่ได้)
func _swing(angle: float, dur: float) -> void:
	if _tween:
		_tween.kill()
	_busy = true
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_leaf, "rotation:y", angle, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _busy = false)
