@tool
extends Node3D
class_name Altar
## โต๊ะหมู่บูชา (ห้องพระ) — วางรูปถ่ายที่ต่อครบ / เผาสัญญา (ฉากจบที่แท้จริง)
## ตรรกะเนื้อเรื่องอยู่ที่ level.gd: altar_prompt() / altar_interact()
## หน้าโต๊ะ = แกน +Z ของโหนด


# สร้างโต๊ะหมู่เมื่อเริ่ม
func _ready() -> void:
	_build()


# สร้างโต๊ะหมู่บูชาด้วยโค้ด: โต๊ะ 3 ชั้นสีแดงเคลือบ ขอบทอง, องค์พระ, แจกัน 2 ใบ, กระถางธูปและธูป
# ตัวชนทั้งโต๊ะ และพื้นที่ด้านหน้าให้ผู้เล่นเล็งกด E โต้ตอบได้
func _build() -> void:
	for c in get_children():
		c.queue_free()
	var red_lacquer := MatLib.color(Color(0.35, 0.05, 0.04), 0.35, 0.1)
	var gold := MatLib.color(Color(0.85, 0.65, 0.25), 0.3, 0.95)
	# โต๊ะหมู่ 3 ชั้น
	var tiers := [[Vector3(1.6, 0.7, 0.7), 0.35], [Vector3(1.2, 0.3, 0.5), 0.85], [Vector3(0.7, 0.3, 0.38), 1.15]]
	for t in tiers:
		var size: Vector3 = t[0]
		var y: float = t[1]
		MatLib.box(self, size, Vector3(0, y, -0.1), red_lacquer)
		MatLib.box(self, Vector3(size.x + 0.04, 0.03, size.z + 0.04), Vector3(0, y + size.y / 2, -0.1), gold)
		MatLib.box(self, Vector3(size.x * 0.8, 0.03, 0.01), Vector3(0, y, -0.1 + size.z / 2 + 0.005), gold)
	# องค์พระ (ทรงเรียบง่าย)
	var base_y := 1.3
	MatLib.cyl(self, 0.12, 0.16, 0.08, Vector3(0, base_y + 0.04, -0.15), gold)
	MatLib.sphere(self, 0.13, Vector3(0, base_y + 0.17, -0.15), gold, 0.8)
	MatLib.cyl(self, 0.06, 0.11, 0.22, Vector3(0, base_y + 0.33, -0.15), gold)
	MatLib.sphere(self, 0.065, Vector3(0, base_y + 0.5, -0.15), gold)
	MatLib.cyl(self, 0.0, 0.025, 0.1, Vector3(0, base_y + 0.6, -0.15), gold)
	# แจกัน ดอกไม้ กระถางธูป
	var vase := MatLib.color(Color(0.2, 0.3, 0.5), 0.2, 0.2)
	var flower := MatLib.color(Color(0.9, 0.85, 0.3), 0.8)
	for x in [-0.45, 0.45]:
		MatLib.cyl(self, 0.04, 0.05, 0.16, Vector3(x, 1.08, 0.05), vase)
		MatLib.sphere(self, 0.07, Vector3(x, 1.2, 0.05), flower)
	MatLib.cyl(self, 0.07, 0.06, 0.07, Vector3(0, 0.735, 0.12), MatLib.color(Color(0.4, 0.38, 0.33), 0.8))
	for i in 3:
		MatLib.cyl(self, 0.003, 0.003, 0.2, Vector3(-0.02 + i * 0.02, 0.84, 0.12), MatLib.color(Color(0.6, 0.2, 0.15)), Vector3(0, 0, -6 + i * 6))
	# collision ทั้งโต๊ะ (อยู่ใน nav region)
	MatLib.static_box(self, Vector3(1.6, 1.3, 0.7), Vector3(0, 0.65, -0.1))
	# พื้นที่โต้ตอบด้านหน้า
	var area := Area3D.new()
	area.collision_layer = 32
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.4, 0.6, 0.3)
	cs.shape = sh
	cs.position = Vector3(0, 0.9, 0.3)
	area.add_child(cs)
	add_child(area)


# ข้อความบน HUD ถามจาก level.gd (เปลี่ยนตามความคืบหน้าของเนื้อเรื่อง)
func get_prompt(_p: Node) -> String:
	if GameState.level and GameState.level.has_method("altar_prompt"):
		return GameState.level.altar_prompt()
	return "โต๊ะหมู่บูชา"


# กด E ที่โต๊ะหมู่: ส่งต่อให้ level.gd จัดการ (วางรูป / เผาสัญญา / ไหว้พระ)
func interact(_p: Node) -> void:
	if GameState.level and GameState.level.has_method("altar_interact"):
		GameState.level.altar_interact()
