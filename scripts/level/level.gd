extends Node3D
class_name Level
## ตัวคุมเนื้อเรื่องของบ้าน "วังเวง"
## - เปิดเรื่อง / checkpoint / ฉากจบ
## - ลำดับปริศนา: ไฟฉาย → กุญแจประตูหลัง → เศษรูป 3 ชิ้น → โต๊ะหมู่ → กุญแจห้องยาย → สัญญา → จบ
## - "บ้านเปลี่ยน" ตามเฟส: โหนดในกลุ่ม phase_show_N / phase_hide_N จะเปิด/ปิดอัตโนมัติ แล้ว bake navmesh ใหม่
##
## เฟส 0 เงียบสงัด → 1 เธอตื่นแล้ว (เก็บเศษรูปที่ศาลพระภูมิ) → 2 บ้านจำได้ (เศษรูปชิ้นที่ 3) → 3 ทวงหนี้ (เอาสัญญา)

# โหนดสำคัญในฉาก: พื้นที่เดินได้ของผี (navmesh), ผู้เล่น, ผี, HUD, ภาพหลอน, สภาพแสง/หมอก, เสียงบรรยากาศในบ้านและกลางคืน
@onready var nav: NavigationRegion3D = $NavRegion
@onready var player: Player = $Player
@onready var ghost: Ghost = $Ghost
@onready var hud: HUD = $HUD
@onready var halluc: Hallucinations = $Hallucinations
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var amb_house: AudioStreamPlayer = $AmbHouse
@onready var amb_night: AudioStreamPlayer = $AmbNight

# ข้อความเปิดเรื่องที่ขึ้นบนจอดำก่อนเริ่มเล่น
const INTRO_LINES := [
	"ยายจากไปเมื่อสัปดาห์ก่อน...",
	"ข้าวฟ่าง หลานสาวที่ยายเลี้ยงมาตั้งแต่เด็ก\nกลับมาที่บ้านเก่าของตระกูลอีกครั้งในรอบสิบห้าปี",
	"เพื่อเก็บของ... และประกาศขายบ้านหลังนี้",
	"ความทรงจำเกี่ยวกับบ้านหลังนี้ เลือนรางเหลือเกิน",
	"แต่บ้านหลังนี้...\nยังจำเธอได้",
]

# ข้อความภารกิจ (objective) ที่แสดงมุมจอในแต่ละขั้นของเรื่อง
const OBJ_START := "ประตูหน้าล็อกตาย — สำรวจบ้านและหาทางออกอื่น (ลองดูในครัว)"
const OBJ_FIND_EXIT := "ประตูหน้าล็อกตาย — หาทางออกทางอื่น (ลองดูในครัว)"
const OBJ_BACKDOOR := "ใช้กุญแจเปิดประตูหลังบ้าน (สุดทางเดินข้างครัว)"
const OBJ_GARDEN := "สำรวจสวนหลังบ้าน — ศาลพระภูมิอยู่ท้ายสวน"
const OBJ_PIECES := "รวบรวมเศษรูปถ่ายให้ครบ 3 ชิ้น (%d/3)\nเบาะแส: บทขอขมาในห้องพระ"
const OBJ_ALTAR := "นำเศษรูปถ่ายทั้ง 3 ชิ้นไปวางบนโต๊ะหมู่ในห้องพระ"
const OBJ_GRANDMA := "ไปที่ห้องของยาย บนชั้นสอง (ปีกซ้ายสุด)"
const OBJ_FINAL := "หนีออกทางประตูหน้าบ้าน!\n— หรือ จุดเทียนบนโต๊ะหมู่ แล้วเผาสัญญาเพื่อขอขมา"

# ตัวแปรภายใน: เริ่มฉากจบแล้วหรือยัง (กันเรียกซ้ำ), เวลารอไหว้พระครั้งถัดไป, สีแสง/หมอกปกติ (เก็บไว้คืนค่าหลังบทที่ 3)
var _ending_started := false
var _pray_cd := 0.0
var _base_ambient: Color
var _base_fog: Color


# เริ่มด่าน: เชื่อมสัญญาณ (เก็บของ / เปลี่ยนบท / ผู้เล่นตาย) กับ GameState
# ถ้าโหลดจากจุดเซฟ: วางผู้เล่นตำแหน่งเดิมและปลุกผีทันที / ถ้าเกมใหม่: เล่นฉากเปิดเรื่อง
func _ready() -> void:
	GameState.level = self
	GameState.item_picked.connect(_on_item_picked)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.player_died.connect(_on_player_died)
	halluc.screen_text.connect(hud.flash_screen_text)
	_base_ambient = world_env.environment.ambient_light_color
	_base_fog = world_env.environment.fog_light_color
	get_tree().paused = false

	var from_cp := GameState.has_checkpoint()
	if from_cp:
		player.global_transform = GameState.checkpoint.xform
		player.apply_look(GameState.checkpoint.look)
		if GameState.has_item("flashlight"):
			pass
	_merge_static_meshes(nav)
	_apply_phase_state(GameState.phase)
	await _rebake()
	if GameState.phase >= 1 or from_cp:
		var spot := _far_patrol_point(player.global_position)
		ghost.activate(spot, false)
	if from_cp:
		hud.set_objective(GameState.objective)
		hud.fade.modulate.a = 1.0
		hud.fade_to(0.0, 1.2)
		GameState.say("(...อีกครั้ง)", 2.0)
	else:
		_intro()


# เสียงบรรยากาศ: ข้างนอกบ้านได้ยินเสียงกลางคืนดัง ข้างในได้ยินเสียงบ้านดัง ค่อย ๆ ปรับเข้าหากัน
func _process(delta: float) -> void:
	_pray_cd = maxf(_pray_cd - delta, 0.0)
	# เสียงบรรยากาศ ข้างใน/ข้างนอก
	var outside := player.global_position.z < 0.2 and player.global_position.y < 1.5
	amb_house.volume_db = move_toward(amb_house.volume_db, -30.0 if outside else -5.0, delta * 20.0)
	amb_night.volume_db = move_toward(amb_night.volume_db, -16.0 if outside else -34.0, delta * 20.0)


# ================================================================== navmesh
# สร้างพื้นที่เดินได้ (navmesh) ใหม่ — ต้องทำทุกครั้งที่บ้านเปลี่ยน ระหว่างนั้นผีหยุดอยู่กับที่
func _rebake() -> void:
	ghost.nav_ready = false
	nav.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	ghost.nav_ready = true


# ================================================================== รวม mesh (ประสิทธิภาพ)
## รวม MeshInstance3D ที่อยู่นิ่งทั้งหมดใต้ NavRegion เป็น mesh ก้อนใหญ่ แยกตาม material + โซน
## ลด draw call จาก ~2500 เหลือราวร้อยกว่า (สำคัญมากสำหรับ Web export)
## โหนดที่อยู่ในกลุ่ม phase_* (บ้านเปลี่ยน) จะไม่ถูกรวม เพราะต้องเปิด/ปิดได้
# (ดูคำอธิบายด้านบน) รวมโมเดลที่อยู่นิ่งให้เหลือก้อนใหญ่ แยกตามวัสดุและโซน เพื่อให้เกมลื่นบนเว็บ
func _merge_static_meshes(root: Node3D) -> void:
	var tools := {}
	var mats := {}
	var shadows := {}
	var removed := 0
	var inv := root.global_transform.affine_inverse()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree() or _in_phase_group(m):
			continue
		var mat: Material = m.material_override
		if mat == null:
			mat = m.get_surface_override_material(0)
		if mat == null:
			mat = m.mesh.surface_get_material(0)
		if mat == null or m.mesh.get_surface_count() != 1:
			continue
		var c := m.global_position
		var cell := Vector3i(int(floor(c.x / 16.0)), 1 if c.y > 3.1 else 0, int(floor(c.z / 8.0)))
		var shadow := m.cast_shadow
		var key := "%d_%s_%d" % [mat.get_instance_id(), cell, shadow]
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
			mats[key] = mat
			shadows[key] = shadow
		(tools[key] as SurfaceTool).append_from(m.mesh, 0, inv * m.global_transform)
		m.mesh = null
		m.visible = false
		removed += 1
	var holder := Node3D.new()
	holder.name = "MergedMeshes"
	root.add_child(holder)
	for key in tools:
		var mesh := (tools[key] as SurfaceTool).commit()
		var nmi := MeshInstance3D.new()
		nmi.mesh = mesh
		nmi.material_override = mats[key]
		nmi.cast_shadow = shadows[key]
		holder.add_child(nmi)
	# โหนดที่เปลี่ยนตามเฟส: รวมภายในตัวเอง (ยังเปิด/ปิดได้)
	for g in ["phase_show_1", "phase_hide_1", "phase_show_2", "phase_hide_2", "phase_show_3", "phase_hide_3"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and root.is_ancestor_of(n):
				MatLib.merge_children(n as Node3D, true)
	print("[Level] merged %d meshes into %d" % [removed, tools.size()])


# ตรวจว่าโหนดนี้ (หรือโหนดแม่) อยู่ในกลุ่ม phase_* ที่ต้องเปิด/ปิดตามบทไหม
func _in_phase_group(n: Node) -> bool:
	while n != null and n != self:
		for g in n.get_groups():
			if String(g).begins_with("phase_"):
				return true
		n = n.get_parent()
	return false


# ================================================================== บ้านเปลี่ยนตามเฟส
# ทำให้บ้านเปลี่ยนตามบท ph: โหนดกลุ่ม phase_show_N จะเปิดเมื่อบท >= N, กลุ่ม phase_hide_N จะปิดเมื่อบท >= N
# บทที่ 3: เปลี่ยนบรรยากาศเป็นสีแดงและปลดล็อกประตูหน้า
func _apply_phase_state(ph: int) -> void:
	for n in range(1, 4):
		for node in get_tree().get_nodes_in_group("phase_show_%d" % n):
			_set_active(node, ph >= n)
		for node in get_tree().get_nodes_in_group("phase_hide_%d" % n):
			_set_active(node, ph < n)
	if ph >= 3:
		_set_hunt_mood(true)
		for d in get_tree().get_nodes_in_group("door"):
			if d.is_exit:
				d.unlock(false)


# เปิด/ปิดโหนด: ซ่อนภาพและปิดการชนด้วย
func _set_active(node: Node, on: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = on
	_set_collision_rec(node, on)


# เปิด/ปิดการชนของโหนดและลูกทั้งหมด (จำค่า layer เดิมไว้เพื่อคืนค่า)
func _set_collision_rec(node: Node, on: bool) -> void:
	if node is CollisionObject3D:
		var co := node as CollisionObject3D
		if not co.has_meta("orig_layer"):
			co.set_meta("orig_layer", co.collision_layer)
		co.collision_layer = int(co.get_meta("orig_layer")) if on else 0
	for c in node.get_children():
		_set_collision_rec(c, on)


# สลับบรรยากาศแสง/หมอกเป็นสีแดงมืด (บทที่ 3 ผีล่า) หรือกลับสีปกติ
func _set_hunt_mood(on: bool) -> void:
	var env := world_env.environment
	if on:
		env.ambient_light_color = Color(0.25, 0.03, 0.03)
		env.fog_light_color = Color(0.12, 0.01, 0.01)
	else:
		env.ambient_light_color = _base_ambient
		env.fog_light_color = _base_fog


# ================================================================== เปิดเรื่อง
# ฉากเปิดเรื่อง: ล็อกการควบคุม เล่นข้อความเปิด ประตูปิดกระแทก แล้วให้เริ่มเล่น + ตั้งผีให้ออกลาดตระเวนหลัง 50 วินาที
func _intro() -> void:
	player.controls_locked = true
	hud.play_intro(INTRO_LINES)
	await hud.intro_finished
	Sfx.play_at("door_slam", Vector3(4.5, 1.2, 12.0), 6.0)
	player.shake = 1.2
	await get_tree().create_timer(1.2).timeout
	GameState.say("ประตู... ล็อกเองเหรอ? ไฟก็ดับ... ยังดีที่มีไฟฉาย  [F] เปิดไฟ", 4.5)
	player.controls_locked = false
	GameState.set_objective(OBJ_START)
	hud.show_help(16.0)
	_checkpoint()
	# เดิมผีไม่ออกมาเลยจนกว่าจะเก็บเศษรูปชิ้นแรก -> ให้ออกลาดตระเวนเบา ๆ หลังเริ่มเล่นราว 50 วินาที
	get_tree().create_timer(50.0).timeout.connect(_early_ghost)


# บันทึกจุดเซฟ (ตำแหน่งผู้เล่น ไอเทม เฟส ฯลฯ) ตายแล้วกลับมาที่นี่
func _checkpoint() -> void:
	GameState.save_checkpoint(player.global_transform, player.get_look())


# ================================================================== เก็บของ
# เมื่อเก็บของ: ตั้งภารกิจถัดไป และเลื่อนบทตามจำนวนเศษรูป
# ชิ้นแรก = บท 1 (เธอตื่นแล้ว), ครบ 3 ชิ้น = บท 2 (บ้านจำได้), เก็บสัญญา = บท 3 (ทวงหนี้)
func _on_item_picked(pickup_id: String, item_id: String) -> void:
	match pickup_id:
		"key_backdoor":
			GameState.set_objective(OBJ_BACKDOOR)
		"key_storage":
			GameState.say("กุญแจห้องเก็บของ... ห้องสุดทางเดินชั้นบน ฝั่งขวา", 3.5)
		"contract":
			GameState.advance_phase(3)
	if item_id == "photo_piece":
		# เก็บเศษรูปชิ้นแรก (ชิ้นไหนก็ได้) = เธอตื่น, ครบ 3 ชิ้น = บ้านเปลี่ยน
		var c := GameState.item_count("photo_piece")
		if c >= 1:
			GameState.advance_phase(1)
		if c >= 3:
			GameState.advance_phase(2)
		if c >= 3:
			GameState.set_objective(OBJ_ALTAR)
		else:
			GameState.set_objective(OBJ_PIECES % c)
	if item_id != "" and item_id != "matches":
		_checkpoint.call_deferred()


# เมื่อเดินเข้าโซนทริกเกอร์: เหตุการณ์ครั้งเดียว เช่น เห็นเงาบนบันได เสียงหัวเราะ ข้อความบอกใบ้
func on_trigger(zone_id: String) -> void:
	match zone_id:
		"stairs_glimpse":
			halluc.show_phantom(player, Vector3(15.2, 3.2, 9.0), 2.2)
			Sfx.play_at("giggle", Vector3(15.2, 4.5, 9.0), 0.0)
		"garden":
			if GameState.phase == 0:
				GameState.say("อากาศข้างนอกเย็นเฉียบ... ศาลพระภูมิตั้งอยู่ท้ายสวน", 3.5)
				GameState.set_objective(OBJ_GARDEN)
		"shrine":
			GameState.say("ห้องพระ... ตราบใดที่เทียนบนโต๊ะหมู่ยังสว่าง ที่นี่ปลอดภัย", 4.0)
		"upstairs":
			if GameState.phase <= 1:
				GameState.say("ห้องของยายอยู่ปีกซ้ายสุด... ห้องตรงกลางคือห้องของเราตอนเด็ก", 4.0)
		"kid_room":
			Sfx.play_at("giggle", Vector3(8.5, 4.2, 1.0), -4.0)
		"hall_after":
			if GameState.phase >= 2:
				GameState.say("ทางเดินนี้... เมื่อกี้มันไม่ได้ถูกปิดแบบนี้", 3.5)


# ================================================================== เหตุการณ์ตามเฟส
# เปลี่ยนบท: เสียงตูม จอสั่น แล้วจัดการแต่ละบท
# 1 เธอตื่นแล้ว: ประตูครัวปิดกระแทก ผีปรากฏตัวแล้วหายวับ
# 2 บ้านจำได้: ทางเดินเปลี่ยน ผีวาร์ปมาใกล้ผู้เล่นและเร็วขึ้น
# 3 ทวงหนี้: เทียนดับทั้งบ้าน บรรยากาศแดง ประตูหน้าปลดล็อก ผีเร็วสุด
func _on_phase_changed(ph: int) -> void:
	Sfx.play("event_boom", 0.0)
	player.shake = 1.0
	hud.hurt_flash(0.35)
	match ph:
		1:
			hud.show_chapter("เธอตื่นแล้ว", "บทที่ ๑")
			_apply_phase_state(1)
			for d in get_tree().get_nodes_in_group("door"):
				if d.door_id == "door_kitchen" and d.is_open:
					d.slam()
			await _rebake()
			_awaken_ghost()
			GameState.set_objective(OBJ_PIECES % GameState.item_count("photo_piece"))
		2:
			hud.show_chapter("บ้านจำได้", "บทที่ ๒")
			_apply_phase_state(2)
			await _rebake()
			if not ghost.is_active():
				_awaken_ghost()
			ghost.apply_phase_stats()
			ghost.teleport($Markers/GhostSpawn2.global_position)
			GameState.say("เสียงไม้ลั่นไปทั้งบ้าน... เหมือนบ้านกำลังขยับตัว", 4.0)
			get_tree().create_timer(9.0).timeout.connect(func():
				if is_instance_valid(player) and not player.dead and not player.is_hidden():
					ghost.investigate(player.global_position))
		3:
			hud.show_chapter("ทวงหนี้", "บทที่ ๓")
			for c in get_tree().get_nodes_in_group("candle"):
				c.extinguish()
				await get_tree().create_timer(0.12).timeout
			_apply_phase_state(3)
			await _rebake()
			_set_hunt_mood(true)
			for d in get_tree().get_nodes_in_group("door"):
				if d.is_exit:
					d.unlock(false)
			GameState.set_flag("front_unlocked")
			Sfx.play_at("unlock", Vector3(4.5, 1.2, 12.0), 8.0)
			ghost.apply_phase_stats()
			ghost.teleport($Markers/GhostSpawn3.global_position)
			GameState.say("เทียนทุกเล่มดับวูบ... เสียงกลอนประตูหน้าบ้านปลดล็อก", 4.5)
			GameState.set_objective(OBJ_FINAL)
	_checkpoint()


# ================================================================== โต๊ะหมู่บูชา
# เทียนบนโต๊ะหมู่ในห้องพระมีเล่มไหนติดอยู่ไหม
func _shrine_lit() -> bool:
	for c in get_tree().get_nodes_in_group("shrine_candle"):
		if c.lit:
			return true
	return false


# ข้อความปุ่มโต้ตอบที่โต๊ะหมู่ เปลี่ยนตามความคืบหน้า (มีสัญญา / เศษรูปครบ / ยังไม่ครบ / ไหว้ธรรมดา)
func altar_prompt() -> String:
	if GameState.has_item("contract"):
		if _shrine_lit():
			return "เผาสัญญาด้วยไฟเทียน และขอขมาแม่หญิง"
		return "ต้องจุดเทียนบนโต๊ะหมู่ก่อน"
	var c := GameState.item_count("photo_piece")
	if c >= 3:
		return "วางรูปถ่ายที่ต่อครบบนโต๊ะหมู่"
	if c > 0:
		return "เศษรูปถ่ายยังไม่ครบ (%d/3)" % c
	return "กราบพระ (ตั้งสติ)"


# กดโต้ตอบที่โต๊ะหมู่
# มีสัญญา + เทียนติด = เผาสัญญา จบแท้ | เศษรูปครบ 3 = วางรูป รับกุญแจห้องยาย | ไม่งั้นกราบไหว้ ฟื้นสติ +20 (พักทุก 25 วินาที)
func altar_interact() -> void:
	if GameState.has_item("contract"):
		if _shrine_lit():
			trigger_ending("redeem")
		else:
			GameState.say("ต้องจุดเทียนบนโต๊ะหมู่ก่อน... ยังมีไม้ขีดไฟอยู่ไหม?", 3.0)
		return
	if GameState.item_count("photo_piece") >= 3 and not GameState.get_flag("photo_done"):
		GameState.set_flag("photo_done")
		GameState.remove_item("photo_piece", 3)
		GameState.add_item("family_photo")
		GameState.add_item("key_grandma")
		GameState.add_note("family_photo")
		Sfx.play("temple_bell", -2.0)
		GameState.set_objective(OBJ_GRANDMA)
		GameState.say("ได้รับ: กุญแจห้องยาย (ซ่อนอยู่ใต้ฐานพระ)", 3.5)
		GameState.note_opened.emit("family_photo")
		_checkpoint()
		return
	if GameState.item_count("photo_piece") > 0:
		GameState.say("ยังขาดอีก %d ชิ้น..." % (3 - GameState.item_count("photo_piece")), 2.5)
		return
	if _pray_cd <= 0.0:
		_pray_cd = 25.0
		Sfx.play("temple_bell", -10.0)
		GameState.sanity = minf(GameState.sanity + 20.0, 100.0)
		GameState.say("(พนมมือไหว้พระ... ใจสงบลง)", 2.5)
	else:
		GameState.say("(ใจสงบลงแล้ว)", 1.5)


# ================================================================== จบเกม
# จบเกม: "redeem" = เผาสัญญา ขอขมา (จบแท้) / อื่น ๆ = หนีออกประตูหน้า — ปิดผี จอค่อย ๆ มืด แล้วไปฉากจบ
func trigger_ending(kind: String) -> void:
	if _ending_started:
		return
	_ending_started = true
	GameState.ending = kind
	player.controls_locked = true
	ghost.set_dormant()
	if kind == "redeem":
		GameState.remove_item("contract")
		Sfx.play("match", 0.0)
		Sfx.play("temple_bell", 0.0)
		GameState.say("เปลวไฟกลืนกินผ้ายันต์... \"ขอขมาแม่หญิง...\"", 4.0)
		_set_hunt_mood(false)
		await get_tree().create_timer(2.5).timeout
	else:
		Sfx.play_at("door_open", player.global_position, 0.0)
		await get_tree().create_timer(0.6).timeout
	await hud.fade_to(1.0, 2.0).finished
	get_tree().change_scene_to_file("res://scenes/ending.tscn")


# ผู้เล่นตาย (ตอนนี้ HUD จัดการหน้าจอตายเอง จึงไม่ต้องทำอะไรที่นี่)
func _on_player_died(_reason: String) -> void:
	pass


# ผีออกลาดตระเวนเบา ๆ ตั้งแต่ก่อนเก็บเศษรูปชิ้นแรก (เรียกหลังเริ่มเล่นราว 50 วินาที) ใช้ความเร็วช่วงเริ่มเกม
func _early_ghost() -> void:
	if not is_instance_valid(player) or player.dead or ghost.is_active() or GameState.phase >= 1:
		return
	ghost.apply_phase_stats()
	ghost.activate(_far_patrol_point(player.global_position), false)
	GameState.say("มีเสียงฝีเท้าแผ่ว ๆ ในบ้าน... ไม่ได้อยู่คนเดียวแล้ว", 4.0)


# ปลุกผีตอนเข้าบท 1: อยู่ในสวน = โผล่ที่บ่อน้ำ / อยู่ในบ้าน = โผล่จุดที่มองเห็นได้ แล้วหายวับไป
func _awaken_ghost() -> void:
	# ถ้าอยู่ในสวน เธอโผล่ที่บ่อน้ำ / ถ้าอยู่ในบ้าน เธอโผล่ในจุดที่มองเห็นได้ แล้วหายวับไป
	var at: Vector3 = $Markers/GhostSpawn1.global_position
	var where := "ดังมาจากบ่อน้ำหลังบ้าน"
	if player.global_position.z > 0.0:
		where = "ดังมาจากที่ไหนสักแห่งในบ้าน"
		var best := Vector3.INF
		for pt in get_tree().get_nodes_in_group("ghost_patrol"):
			var pos: Vector3 = pt.global_position
			var d := pos.distance_to(player.global_position)
			if d > 5.0 and d < 14.0 and absf(pos.y - player.global_position.y) < 1.0:
				best = pos
				if player.can_see_point(pos + Vector3.UP * 1.4):
					break
		at = best if best != Vector3.INF else _far_patrol_point(player.global_position)
	ghost.activate(at, true, true)
	GameState.say("เสียงผู้หญิงครวญเพลงกล่อมเด็ก... " + where, 4.0)


# หาจุดลาดตระเวนที่ไกลที่สุดจากตำแหน่ง from (ใช้ให้ผีเกิดห่างผู้เล่น)
func _far_patrol_point(from: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_d := -1.0
	for pt in get_tree().get_nodes_in_group("ghost_patrol"):
		var d := (pt as Node3D).global_position.distance_to(from)
		if d > best_d:
			best_d = d
			best = (pt as Node3D).global_position
	return best
