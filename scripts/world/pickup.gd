@tool
extends Node3D
class_name Pickup
## ไอเทม/จดหมายที่เก็บได้  — ตั้ง pickup_id ให้ไม่ซ้ำกัน (ใช้จำว่าเก็บไปแล้วตอนโหลด checkpoint)
## เรื่องราวที่เกิดหลังเก็บ (เปลี่ยนภารกิจ / เปลี่ยนเฟส) จัดการใน level.gd → _on_item_picked()

# ตั้งค่าได้: pickup_id = รหัสที่ไม่ซ้ำ (จำว่าเก็บแล้ว) / item_id = ไอเทมที่ได้ / amount = จำนวน / note_id = จดหมายที่ได้ / visual = รูปร่างที่แสดง
@export var pickup_id := "pickup"
@export var item_id := ""
@export var amount := 1
@export var note_id := ""
@export_enum("key", "letter", "photo", "matches", "flashlight", "contract", "drawing", "newspaper") var visual := "key":
	set(v):
		visual = v
		if is_inside_tree():
			_build()

# ตัวแปรภายใน: วัสดุประกายแวววาว, ตัวนับเวลา, โหนดรูปร่าง
var _glint: StandardMaterial3D
var _t := 0.0
var _vis_root: Node3D


# เริ่มต้น: สร้างรูปร่าง และถ้าเคยเก็บไปแล้ว (โหลดจากจุดเซฟ) ให้หายไปเลย
func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("pickup")
	if GameState.collected.has(pickup_id):
		queue_free()


# สร้างรูปร่างของที่เก็บได้ด้วยโค้ดตามชนิด visual (กุญแจ จดหมาย หนังสือพิมพ์ ภาพวาด รูปถ่าย ไม้ขีด ไฟฉาย สัญญาผ้ายันต์)
# บนสุดมีประกายเล็ก ๆ ช่วยให้หาเจอในที่มืด และพื้นที่ให้ผู้เล่นเล็งกดเก็บ
func _build() -> void:
	if _vis_root:
		_vis_root.queue_free()
	_vis_root = Node3D.new()
	_vis_root.name = "Visual"
	add_child(_vis_root)
	_glint = MatLib.unique_emissive(Color(1.0, 0.85, 0.5), 0.0)
	_glint.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var v := _vis_root
	match visual:
		"key":
			var brass := MatLib.color(Color(0.75, 0.58, 0.25), 0.35, 0.9)
			var tm := TorusMesh.new()
			tm.inner_radius = 0.018
			tm.outer_radius = 0.035
			var ring := MeshInstance3D.new()
			ring.mesh = tm
			ring.material_override = brass
			ring.position = Vector3(-0.06, 0.006, 0)
			v.add_child(ring)
			MatLib.box(v, Vector3(0.1, 0.012, 0.014), Vector3(0.02, 0.006, 0), brass)
			MatLib.box(v, Vector3(0.012, 0.012, 0.03), Vector3(0.06, 0.006, 0.018), brass)
			MatLib.box(v, Vector3(0.012, 0.012, 0.02), Vector3(0.045, 0.006, 0.014), brass)
			MatLib.box(v, Vector3(0.006, 0.004, 0.08), Vector3(-0.09, 0.003, 0.03), MatLib.color(Color(0.7, 0.05, 0.05)), Vector3(0, 30, 0))
		"letter":
			MatLib.box(v, Vector3(0.21, 0.006, 0.15), Vector3(0, 0.003, 0), MatLib.textured("paper", 1.0, Color.WHITE, false), Vector3(0, 12, 0))
		"newspaper":
			MatLib.box(v, Vector3(0.3, 0.006, 0.22), Vector3(0, 0.003, 0), MatLib.color(Color(0.6, 0.58, 0.5), 0.95), Vector3(0, -8, 0))
		"drawing":
			MatLib.box(v, Vector3(0.24, 0.005, 0.24), Vector3(0, 0.003, 0), MatLib.textured("kid_drawing", 1.0, Color.WHITE, false), Vector3(0, 20, 0))
		"photo":
			MatLib.box(v, Vector3(0.1, 0.004, 0.075), Vector3(0, 0.002, 0), MatLib.textured("family_photo", 1.0, Color.WHITE, false), Vector3(0, 35, 0))
		"matches":
			MatLib.box(v, Vector3(0.06, 0.018, 0.04), Vector3(0, 0.009, 0), MatLib.color(Color(0.65, 0.12, 0.08)))
			MatLib.box(v, Vector3(0.062, 0.006, 0.02), Vector3(0, 0.012, 0), MatLib.color(Color(0.9, 0.75, 0.2)))
		"flashlight":
			var black := MatLib.color(Color(0.08, 0.08, 0.09), 0.4, 0.5)
			MatLib.cyl(v, 0.022, 0.022, 0.2, Vector3(0, 0.025, 0), black, Vector3(0, 0, 90))
			MatLib.cyl(v, 0.035, 0.026, 0.05, Vector3(0.12, 0.035, 0), black, Vector3(0, 0, 90))
			MatLib.cyl(v, 0.03, 0.03, 0.005, Vector3(0.147, 0.035, 0), MatLib.color(Color(0.9, 0.9, 0.8), 0.1), Vector3(0, 0, 90))
		"contract":
			MatLib.box(v, Vector3(0.22, 0.02, 0.16), Vector3(0, 0.01, 0), MatLib.textured("yant_cloth", 1.0, Color.WHITE, false))
			MatLib.cyl(v, 0.02, 0.02, 0.18, Vector3(0, 0.035, 0), MatLib.textured("paper", 1.0, Color(0.9, 0.85, 0.7), false), Vector3(0, 0, 90))
	for c in v.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not Engine.is_editor_hint():
		MatLib.merge_children(v)
	# จุดประกายให้หาเจอในความมืด
	var glow := MatLib.sphere(v, 0.012, Vector3(0, 0.05, 0), _glint)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# พื้นที่ให้ raycast ของผู้เล่นชน
	var area := Area3D.new()
	area.collision_layer = 32
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.28
	cs.shape = sh
	cs.position = Vector3(0, 0.08, 0)
	area.add_child(cs)
	v.add_child(area)


# ประกายกะพริบเป็นจังหวะ (ฟังก์ชัน sin ยกกำลัง ทำให้แวบสว่างแล้วจางเร็ว)
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _glint == null:
		return
	_t += delta
	_glint.emission_energy_multiplier = 0.6 + 2.2 * pow(maxf(sin(_t * 2.4), 0.0), 6.0)


# ข้อความบน HUD: "อ่าน: ชื่อบันทึก" หรือ "เก็บ: ชื่อไอเทม"
func get_prompt(_p: Node) -> String:
	if note_id != "" and item_id == "":
		return "อ่าน: " + GameState.NOTES.get(note_id, {}).get("title", "บันทึก")
	var n := GameState.item_name(item_id)
	if amount > 1:
		n += " x%d" % amount
	return "เก็บ: " + n


# กดเก็บ: บันทึกว่าเก็บแล้ว เพิ่มไอเทม/จดหมาย เล่นเสียง แสดงข้อความ
# แล้วส่งสัญญาณ item_picked ให้ level.gd จัดการเนื้อเรื่องต่อ (เปลี่ยนภารกิจ/บท) จากนั้นลบตัวเองทิ้ง
func interact(_p: Node) -> void:
	GameState.collected[pickup_id] = true
	if item_id != "":
		GameState.add_item(item_id, amount)
		Sfx.play("pickup", -6.0)
		var n := GameState.item_name(item_id)
		if amount > 1:
			n += " x%d" % amount
		GameState.say("ได้รับ: " + n, 2.2)
	if note_id != "":
		GameState.add_note(note_id)
		Sfx.play("page", -3.0)
		GameState.note_opened.emit(note_id)
	GameState.item_picked.emit(pickup_id, item_id)
	queue_free()
