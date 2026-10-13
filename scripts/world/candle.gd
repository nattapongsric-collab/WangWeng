@tool
extends Node3D
class_name Candle
## เทียน — จุดด้วยไม้ขีดไฟ, อยู่ใกล้เทียนที่ติดอยู่ = สติฟื้นคืน
## shrine = เทียนบนโต๊ะหมู่ (ทำให้ห้องพระเป็นพื้นที่ปลอดภัย)

# ตั้งค่าได้: รหัสเทียน (ใช้จำสถานะ), ติดอยู่ไหม, รัศมีแสงที่ฟื้นสติ, เป็นเทียนบนโต๊ะหมู่ไหม, สีแดง (บทสุดท้าย)
@export var candle_id := "candle"
@export var lit := true:
	set(v):
		lit = v
		_apply_lit()
@export var radius := 3.8
@export var shrine := false
@export var red := false  # ใช้ตอนเฟสสุดท้าย

# ตัวแปรภายใน: แสง, เปลวไฟ, วัสดุเปลวไฟ, พื้นที่ให้เล็ง, ตัวนับเวลาและความสว่างพื้นฐาน (ใช้ทำเปลวสั่น)
var _light: OmniLight3D
var _flame: MeshInstance3D
var _flame_mat: StandardMaterial3D
var _area: Area3D
var _t := 0.0
var _base_energy := 1.3


# เริ่มต้น: สร้างเทียน ลงทะเบียนเป็นแหล่งแสง (light_source) ถ้าเป็นเทียนโต๊ะหมู่ลงกลุ่ม shrine_candle แล้วกู้สถานะติด/ดับจาก GameState
func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("light_source")
	add_to_group("candle")
	if shrine:
		add_to_group("shrine_candle")
	if GameState.lit_candles.has(candle_id):
		lit = GameState.lit_candles[candle_id]
	_t = randf() * 10.0


# สร้างเทียนด้วยโค้ด: ฐานทองเหลือง แท่งเทียน เปลวไฟเรืองแสง แสงสีส้ม และพื้นที่ให้เล็งกด E
func _build() -> void:
	for c in get_children():
		c.queue_free()
	var brass := MatLib.color(Color(0.55, 0.42, 0.2), 0.35, 0.8)
	MatLib.cyl(self, 0.045, 0.06, 0.02, Vector3(0, 0.01, 0), brass)
	var wax := MatLib.color(Color(0.92, 0.88, 0.75), 0.6)
	if shrine:
		wax = MatLib.color(Color(0.95, 0.75, 0.35), 0.5)
	MatLib.cyl(self, 0.018, 0.02, 0.16, Vector3(0, 0.1, 0), wax, Vector3.ZERO, 10)
	_flame_mat = MatLib.unique_emissive(Color(1.0, 0.65, 0.25), 3.0)
	_flame = MatLib.sphere(self, 0.012, Vector3(0, 0.2, 0), _flame_mat, 2.2)
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.3, 0)
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = radius + 1.2
	_light.omni_attenuation = 1.4
	_light.light_energy = _base_energy
	_light.shadow_enabled = false
	add_child(_light)
	_area = Area3D.new()
	_area.collision_layer = 32
	_area.collision_mask = 0
	_area.monitoring = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.15
	cs.shape = sh
	cs.position = Vector3(0, 0.12, 0)
	_area.add_child(cs)
	add_child(_area)
	_apply_lit()


# แสดง/ซ่อนแสงกับเปลวตามสถานะติด (ถ้าเป็นเทียนแดง เปลี่ยนเป็นสีแดง)
func _apply_lit() -> void:
	if _light == null:
		return
	_light.visible = lit
	_flame.visible = lit
	if red:
		_light.light_color = Color(1.0, 0.15, 0.1)
		_flame_mat.albedo_color = Color(1, 0.2, 0.1)
		_flame_mat.emission = Color(1, 0.2, 0.1)


# เปลวไฟสั่นไหวเป็นธรรมชาติ: รวมคลื่น sin หลายความถี่กับตัวเลขสุ่ม ปรับความสว่างและความสูงของเปลว
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not lit:
		return
	_t += delta
	var f := 0.85 + 0.1 * sin(_t * 11.0) + 0.06 * sin(_t * 23.0 + 1.3) + randf_range(-0.04, 0.04)
	_light.light_energy = _base_energy * f
	_flame.scale = Vector3(1, f, 1)


# ตำแหน่ง pos อยู่ในแสงเทียนไหม (ติดอยู่ ไม่ใช่เทียนแดง ห่างในแนวราบไม่เกิน radius และสูงต่ำไม่เกิน 2.4 ม.) — ผู้เล่นที่อยู่ในแสงสติจะฟื้น
func illuminates(pos: Vector3) -> bool:
	if not lit or red:
		return false
	var d := pos - global_position
	return absf(d.y) < 2.4 and Vector2(d.x, d.z).length() < radius


# กดจุดได้เฉพาะเทียนที่ดับอยู่
func can_interact(_p: Node) -> bool:
	return not lit


# ข้อความบน HUD: จุดเทียน (บอกจำนวนไม้ขีดที่เหลือ) หรือไม่มีไม้ขีด
func get_prompt(_p: Node) -> String:
	if GameState.has_item("matches"):
		return "จุดเทียน (ไม้ขีดไฟเหลือ %d)" % GameState.item_count("matches")
	return "เทียนดับอยู่ (ไม่มีไม้ขีดไฟ)"


# จุดเทียน: ใช้ไม้ขีด 1 อัน มีเสียงขีดไฟ แล้วเทียนติด
func interact(_p: Node) -> void:
	if lit:
		return
	if not GameState.has_item("matches"):
		GameState.say("ไม่มีไม้ขีดไฟเหลือแล้ว", 2.0)
		return
	GameState.remove_item("matches")
	Sfx.play_at("match", global_position, -2.0)
	set_lit(true)
	GameState.say("แสงเทียนทำให้ใจสงบลง...", 2.0)


# ตั้งสถานะติด/ดับ (persist = จำไว้ใน GameState ให้คงอยู่ตอนโหลดเซฟ)
func set_lit(v: bool, persist: bool = true) -> void:
	red = false
	lit = v
	if persist:
		GameState.lit_candles[candle_id] = v


# ดับเทียน (เทียนดับทั้งบ้านตอนเข้าบทที่ 3) มีเสียงดับ
func extinguish() -> void:
	if not lit:
		return
	Sfx.play_at("candle_out", global_position, -4.0)
	set_lit(false)
