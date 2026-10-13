@tool
extends Node3D
class_name HideSpot
## ที่ซ่อน: ตู้เสื้อผ้า / ใต้เตียง
## ด้านหน้าตู้ = แกน +Z ของโหนด, ด้านข้างเตียงที่มุดเข้า = แกน +X ของโหนด
## ตอนซ่อน: ผีมองไม่เห็น แต่ถ้าผีเห็นตอนเรามุดเข้า หรือได้ยินเสียงหายใจ → โดนลากออกมา

# ชนิดที่ซ่อน: ตู้เสื้อผ้า / เตียงผู้ใหญ่ / เตียงเด็ก — เปลี่ยนแล้วสร้างโมเดลใหม่ทันที
@export_enum("wardrobe", "bed", "kid_bed") var kind := "wardrobe":
	set(v):
		kind = v
		if is_inside_tree():
			_build()


# เริ่มต้น: สร้างโมเดล และลงทะเบียนในกลุ่ม hide_spot (ไม่ลงทะเบียนตอนอยู่ในตัวแก้ไข)
func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("hide_spot")


# สร้างโมเดลตู้/เตียงด้วยโค้ดจากกล่องไม้ (ไม่ใช้ไฟล์โมเดล) พร้อมตัวชน "Body"
func _build() -> void:
	for c in get_children():
		c.queue_free()
	var wood := MatLib.textured("wood_dark", 1.0)
	match kind:
		# ตู้เสื้อผ้า: โครงตู้ 5 ด้าน บานคู่แบบมีซี่ระบายอากาศ (ผู้เล่นมองลอดออกมาได้) ผ้าแขวนในตู้
		"wardrobe":
			var w := 1.1
			var h := 2.05
			var d := 0.62
			MatLib.box(self, Vector3(w, h, 0.04), Vector3(0, h / 2, -d / 2 + 0.02), wood)
			MatLib.box(self, Vector3(0.04, h, d), Vector3(-w / 2 + 0.02, h / 2, 0), wood)
			MatLib.box(self, Vector3(0.04, h, d), Vector3(w / 2 - 0.02, h / 2, 0), wood)
			MatLib.box(self, Vector3(w, 0.06, d), Vector3(0, h - 0.03, 0), wood)
			MatLib.box(self, Vector3(w, 0.1, d), Vector3(0, 0.05, 0), wood)
			MatLib.box(self, Vector3(w + 0.06, 0.08, d + 0.06), Vector3(0, h + 0.04, 0), wood)
			# บานตู้แบบมีช่องระบายอากาศ (ซี่) — มองลอดออกมาได้
			for side in [-1.0, 1.0]:
				var door := Node3D.new()
				door.position = Vector3(side * w / 4, 0, d / 2 - 0.015)
				add_child(door)
				MatLib.box(door, Vector3(w / 2 - 0.02, 0.1, 0.025), Vector3(0, 0.15, 0), wood)
				MatLib.box(door, Vector3(w / 2 - 0.02, 0.1, 0.025), Vector3(0, h - 0.12, 0), wood)
				MatLib.box(door, Vector3(0.05, h - 0.2, 0.025), Vector3(-side * (w / 4 - 0.035), h / 2, 0), wood)
				MatLib.box(door, Vector3(0.05, h - 0.2, 0.025), Vector3(side * (w / 4 - 0.035), h / 2, 0), wood)
				var y := 0.25
				while y < h - 0.2:
					MatLib.box(door, Vector3(w / 2 - 0.08, 0.035, 0.012), Vector3(0, y, 0), wood, Vector3(35, 0, 0))
					y += 0.065
				MatLib.sphere(door, 0.02, Vector3(-side * 0.04, 1.05, 0.03), MatLib.color(Color(0.6, 0.5, 0.3), 0.3, 0.8))
			# ผ้าแขวนในตู้
			var cloth := MatLib.textured("cloth_white", 1.0, Color(0.7, 0.68, 0.62))
			MatLib.box(self, Vector3(0.25, 0.9, 0.03), Vector3(-0.3, 1.3, -0.12), cloth, Vector3(0, 20, 0))
			var col := MatLib.static_box(self, Vector3(w, h, d), Vector3(0, h / 2, 0))
			col.name = "Body"
		# เตียง: ขา 4 ต้น แผ่นเตียง ที่นอน หมอน และผ้าห่มห้อยข้างเตียง (บังการมองใต้เตียง) ตัวชนเฉพาะส่วนพื้นเตียง
		"bed", "kid_bed":
			var w := 1.4 if kind == "bed" else 1.0
			var l := 2.05 if kind == "bed" else 1.7
			var leg_h := 0.32
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					MatLib.box(self, Vector3(0.07, leg_h, 0.07), Vector3(x * (w / 2 - 0.05), leg_h / 2, z * (l / 2 - 0.05)), wood)
			MatLib.box(self, Vector3(w, 0.08, l), Vector3(0, leg_h + 0.04, 0), wood)
			MatLib.box(self, Vector3(w, 0.85, 0.07), Vector3(0, 0.42, -l / 2 + 0.035), wood)
			var cloth := MatLib.textured("cloth_white", 1.2)
			MatLib.box(self, Vector3(w - 0.06, 0.16, l - 0.12), Vector3(0, leg_h + 0.16, 0.03), cloth)
			MatLib.box(self, Vector3(w * 0.6, 0.1, 0.35), Vector3(0, leg_h + 0.29, -l / 2 + 0.3), cloth)
			# ผ้าห่มห้อยลงข้างเตียง (บังการมองเห็นใต้เตียงบางส่วน)
			var blanket := MatLib.textured("fabric", 1.3)
			MatLib.box(self, Vector3(w + 0.04, 0.05, l * 0.55), Vector3(0, leg_h + 0.25, l * 0.18), blanket)
			MatLib.box(self, Vector3(0.03, 0.3, l * 0.55), Vector3(-w / 2 - 0.02, leg_h + 0.1, l * 0.18), blanket)
			# collision เฉพาะส่วนพื้นเตียง (ด้านล่างโล่ง แต่ผู้เล่นมุดเองไม่ได้ต้องกด E)
			var col := MatLib.static_box(self, Vector3(w, 0.62, l), Vector3(0, 0.31, 0))
			col.name = "Body"


# เป็นเตียงไหม (ไม่ใช่ตู้)
func _is_bed() -> bool:
	return kind != "wardrobe"


# ตำแหน่งกล้องของผู้เล่นตอนซ่อนอยู่ในที่ซ่อนนี้ (ในตู้ = ระดับสายตา / ใต้เตียง = ระดับพื้น)
func get_view_position() -> Vector3:
	if _is_bed():
		return to_global(Vector3(0.1, 0.17, 0.0))
	return to_global(Vector3(0, 1.5, -0.02))


# ความสูงของหัวผู้เล่นตอนซ่อน
func get_view_height() -> float:
	return 0.17 if _is_bed() else 1.5


# ทิศที่ผู้เล่นหันหน้าตอนซ่อน (ในตู้หันออกหน้าตู้ / ใต้เตียงหันออกข้างเตียง)
func get_view_yaw() -> float:
	if _is_bed():
		return global_rotation.y - PI / 2.0
	return global_rotation.y + PI


# ตำแหน่งที่ผู้เล่นออกมายืนเมื่อออกจากที่ซ่อน (ผีก็ใช้ตำแหน่งนี้ตอนมายืนรอจับ)
func get_exit_position() -> Vector3:
	if _is_bed():
		var w := 1.4 if kind == "bed" else 1.0
		return to_global(Vector3(w / 2 + 0.55, 0.05, 0.0))
	return to_global(Vector3(0, 0.05, 0.95))


# ข้อความบน HUD: ซ่อนอยู่ = ออกจากที่ซ่อน / ไม่ได้ซ่อน = ซ่อนในตู้ หรือ มุดใต้เตียง
func get_prompt(p: Node) -> String:
	if p.get("hidden_in") == self:
		return "ออกจากที่ซ่อน   [Space ค้าง] กลั้นหายใจ"
	return "มุดใต้เตียง" if _is_bed() else "ซ่อนในตู้"


# กด E: ซ่อนอยู่แล้ว = ออก / ยังไม่ซ่อน = มุดเข้า (มีเสียงเปิด/ปิดตู้หรือเสียงเตียง)
func interact(p: Node) -> void:
	if p.get("hidden_in") == self:
		p.exit_hide()
		Sfx.play_at("door_open" if not _is_bed() else "step_wood_2", global_position, -12.0, 1.4)
	else:
		p.enter_hide(self)
		Sfx.play_at("door_close" if not _is_bed() else "step_wood_1", global_position, -10.0, 1.2)
