@tool
extends RigidBody3D
class_name NoisyProp
## ของที่ชนแล้วมีเสียงดัง (ขวด หม้อ ถัง เก้าอี้) — เสียงดังดึงดูดแม่หญิง
## ผู้เล่นเดินชนจะผลักให้ล้ม/กลิ้ง ถ้ากระแทกแรงพอ = เสียงดัง รัศมี noise_radius

# ชนิดของ: ขวด / หม้อ / ถัง / โอ่ง / เก้าอี้ (ต่างกันที่รูปร่างและน้ำหนัก)
@export_enum("bottle", "pot", "bucket", "jar", "chair") var kind := "bottle":
	set(v):
		kind = v
		if is_inside_tree():
			_build()
# รัศมีเสียงสูงสุดที่ผีได้ยินเมื่อกระแทกแรง
@export var noise_radius := 9.0

# เวลาหน่วงกันเสียงรัวถี่เกินไป (เริ่มที่ 1.5 วินาทีกันเสียงตอนของตกลงพื้นตอนเริ่มเกม)
var _cooldown := 1.5


# เริ่มต้น: สร้างโมเดล ตั้งเป็นวัตถุฟิสิกส์ (ชนกับโลก ผู้เล่น ประตู และของอื่น) และเปิดตรวจการชน
func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	MatLib.merge_children(self)
	collision_layer = 16
	collision_mask = 1 | 2 | 8 | 16
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


# สร้างโมเดลและรูปทรงชนตามชนิดของ พร้อมตั้งน้ำหนัก (ขวดเบาสุด เก้าอี้หนักสุด)
func _build() -> void:
	for c in get_children():
		c.queue_free()
	var cs := CollisionShape3D.new()
	add_child(cs)
	match kind:
		"bottle":
			mass = 0.4
			var glass := MatLib.color(Color(0.2, 0.35, 0.25, 1.0), 0.15, 0.1)
			MatLib.cyl(self, 0.035, 0.035, 0.2, Vector3(0, 0.1, 0), glass, Vector3.ZERO, 10)
			MatLib.cyl(self, 0.012, 0.03, 0.08, Vector3(0, 0.24, 0), glass, Vector3.ZERO, 8)
			var sh := CylinderShape3D.new()
			sh.radius = 0.035
			sh.height = 0.28
			cs.shape = sh
			cs.position = Vector3(0, 0.14, 0)
		"pot":
			mass = 1.2
			var metal := MatLib.color(Color(0.45, 0.45, 0.42), 0.4, 0.8)
			MatLib.cyl(self, 0.13, 0.11, 0.14, Vector3(0, 0.07, 0), metal)
			MatLib.box(self, Vector3(0.1, 0.015, 0.025), Vector3(0.17, 0.12, 0), MatLib.color(Color(0.1, 0.08, 0.06)))
			var sh := CylinderShape3D.new()
			sh.radius = 0.13
			sh.height = 0.14
			cs.shape = sh
			cs.position = Vector3(0, 0.07, 0)
		"bucket":
			mass = 1.0
			var plastic := MatLib.color(Color(0.25, 0.3, 0.45), 0.6)
			MatLib.cyl(self, 0.16, 0.12, 0.3, Vector3(0, 0.15, 0), plastic)
			var sh := CylinderShape3D.new()
			sh.radius = 0.15
			sh.height = 0.3
			cs.shape = sh
			cs.position = Vector3(0, 0.15, 0)
		"jar":
			mass = 2.0
			var clay := MatLib.color(Color(0.35, 0.22, 0.14), 0.7)
			MatLib.sphere(self, 0.16, Vector3(0, 0.17, 0), clay, 1.1)
			MatLib.cyl(self, 0.08, 0.1, 0.06, Vector3(0, 0.34, 0), clay)
			var sh := SphereShape3D.new()
			sh.radius = 0.16
			cs.shape = sh
			cs.position = Vector3(0, 0.17, 0)
		"chair":
			mass = 4.0
			var wood := MatLib.textured("wood_dark", 1.0)
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					MatLib.box(self, Vector3(0.04, 0.45, 0.04), Vector3(x * 0.19, 0.225, z * 0.19), wood)
			MatLib.box(self, Vector3(0.44, 0.04, 0.44), Vector3(0, 0.47, 0), wood)
			MatLib.box(self, Vector3(0.44, 0.45, 0.04), Vector3(0, 0.72, 0.2), wood)
			var sh := BoxShape3D.new()
			sh.size = Vector3(0.44, 0.5, 0.44)
			cs.shape = sh
			cs.position = Vector3(0, 0.25, 0)
			var cs2 := CollisionShape3D.new()
			var sh2 := BoxShape3D.new()
			sh2.size = Vector3(0.44, 0.45, 0.05)
			cs2.shape = sh2
			cs2.position = Vector3(0, 0.72, 0.2)
			add_child(cs2)


# ลดตัวหน่วงเวลาลงทุกเฟรม
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_cooldown = maxf(_cooldown - delta, 0.0)


# เมื่อชนอะไร: ถ้าความเร็วต่ำกว่า 1 ไม่นับ
# เล่นเสียงกระแทก (แรงกว่า = ดังกว่า) และส่งเสียงให้ผีได้ยิน รัศมีตามความแรง — ผู้เล่นเดินไปชนแล้วของล้มจึงดึงดูดผีได้
func _on_body_entered(_body: Node) -> void:
	if _cooldown > 0.0:
		return
	var v := linear_velocity.length()
	if v < 1.0:
		return
	_cooldown = 0.6
	var vol := clampf(-12.0 + v * 4.0, -12.0, 4.0)
	Sfx.play_at("bump", global_position, vol, Sfx.random_pitch(0.2) * (1.3 if kind == "bottle" else 1.0))
	GameState.make_noise(global_position, noise_radius * clampf(v / 2.5, 0.5, 1.2), "bump")
