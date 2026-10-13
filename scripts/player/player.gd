extends CharacterBody3D
class_name Player
## ข้าวฟ่าง — ผู้เล่นมุมมองบุคคลที่หนึ่ง
## ระบบ: เดิน/วิ่ง/ย่อ (เสียงดังต่างกัน), ไฟฉาย (ความร้อน = ดึงดูดผี), สติ (Sanity), ซ่อนตัว + กลั้นหายใจ

# ความเร็วเดิน/วิ่ง/ย่อ (เมตร/วินาที) ความเร่ง และแรงโน้มถ่วง — ปรับได้จาก Inspector
@export var walk_speed := 2.6
@export var sprint_speed := 4.8
@export var crouch_speed := 1.3
@export var acceleration := 10.0
@export var gravity := 14.0

# ความสูงหัวกล้องและขนาดแคปซูลชนตอนยืน/ย่อ
const STAND_HEAD := 1.6
const CROUCH_HEAD := 0.95
const STAND_COL := 1.7
const CROUCH_COL := 1.05

# รัศมีเสียงฝีเท้า (เมตร) — ศัตรูได้ยินถ้าอยู่ในระยะนี้
const NOISE_SPRINT := 12.0
const NOISE_WALK := 3.5
const NOISE_CROUCH := 0.0

# ไฟฉาย
const FLASH_HEAT_UP := 7.0  # ต่อวินาทีตอนเปิด (≈14 วิ เต็ม)
const FLASH_HEAT_DOWN := 12.0
const FLASH_ENERGY := 4.6

# โหนดลูก: หัว (หมุนก้ม-เงย), กล้อง, ไฟฉาย, ลำแสงตรวจของที่โต้ตอบได้, ตัวชนของผู้เล่น
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var flashlight: SpotLight3D = $Head/Camera/Flashlight
@onready var ray: RayCast3D = $Head/Camera/InteractRay
@onready var col: CollisionShape3D = $Collision

# มุมก้ม-เงยของกล้อง
var pitch := 0.0
# แรงวิ่ง (0-100) ลดตอนวิ่ง ฟื้นตอนพัก
var stamina := 100.0
var stamina_delay := 0.0
# สถานะท่าทาง: ย่อ, วิ่ง, เปิดไฟฉาย
var crouching := false
var sprinting := false
var flashlight_on := false
# ความร้อนของไฟฉาย (0-100) เปิดนานจนเต็มจะดึงดูดผี
var flash_heat := 0.0
# ระดับเสียงที่ผู้เล่นทำอยู่ตอนนี้ (ใช้แสดงในตัวบอกเสียงบน HUD)
var noise_level := 0.0
# ตัวนับก้าวเดินและเฟสการโยกกล้อง (bob) ใช้จับจังหวะเสียงฝีเท้าให้ตรงกับภาพ
var step_dist := 0.0
var step_index := 0
var bob_t := 0.0
# ที่ซ่อนที่ผู้เล่นอยู่ (ตู้/เตียง) — null = ไม่ได้ซ่อน
var hidden_in: Node3D = null
var hide_yaw_center := 0.0
# ลมหายใจ (0-100) ใช้ตอนกลั้นหายใจเวลาซ่อน, holding_breath = กำลังกลั้น, breath_exhausted = เวลาที่หอบอยู่หลังหมดลม
var breath := 100.0
var holding_breath := false
var breath_exhausted := 0.0
var breath_timer := 0.0
# ตายแล้ว / ถูกล็อกการควบคุม (ตอนอ่านจดหมาย เปิดฉาก ฯลฯ)
var dead := false
var controls_locked := false
# วัตถุที่เล็งอยู่และกด E โต้ตอบได้
var current_interactable: Node = null
# อยู่ในแสง (เทียน) / อยู่ในเขตปลอดภัย (ห้องพระ) / ผู้เล่นกำลังเห็นผีอยู่
var in_light := false
var in_safe := false
var ghost_visible := false
# แรงสั่นของกล้อง (ตกใจ/สติต่ำ)
var shake := 0.0
var _flash_warned := false
var _hide_tween: Tween

# ตัวเล่นเสียงลูป: เสียงหัวใจเต้น, ลมหายใจ, เสียงกระซิบ — ปรับความดังตามสถานการณ์ใน _update_audio
var heart_player: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var whisper_player: AudioStreamPlayer

# โมเดลไฟฉายในมือ (มุมมองบุคคลที่หนึ่ง)
# โมเดลไฟฉายและมือที่เห็นตอนเล่นมุมมองบุคคลที่หนึ่ง
var viewmodel: Node3D
var _vm_base := Vector3(0.22, -0.24, -0.42)
var _vm_sway := Vector2.ZERO
var _lens_mat: StandardMaterial3D
var _fill_light: OmniLight3D


# เริ่มต้น: ลงทะเบียนผู้เล่นกับ GameState, สร้างตัวเล่นเสียงลูป, สร้างโมเดลไฟฉาย, ล็อกเมาส์เข้าหน้าจอ
func _ready() -> void:
	GameState.player = self
	add_to_group("player")
	heart_player = _make_loop("heartbeat")
	breath_player = _make_loop("breath")
	whisper_player = _make_loop("whisper")
	flashlight.visible = false
	flashlight.light_energy = FLASH_ENERGY
	_build_viewmodel()
	if not GameState.has_item("flashlight"):
		flashlight_on = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# สร้างโมเดลไฟฉาย + มือ + แขน ด้วยโค้ด (ไม่ใช้ไฟล์โมเดล) และตั้งแสงไฟฉายให้ออกจากหน้าเลนส์
func _build_viewmodel() -> void:
	viewmodel = Node3D.new()
	viewmodel.name = "FlashlightModel"
	viewmodel.position = _vm_base
	viewmodel.rotation_degrees = Vector3(2, 4, 0)
	camera.add_child(viewmodel)
	var body_m := MatLib.color(Color(0.07, 0.07, 0.08), 0.35, 0.6)
	var grip_m := MatLib.color(Color(0.12, 0.11, 0.1), 0.9)
	var chrome := MatLib.color(Color(0.55, 0.55, 0.55), 0.2, 1.0)
	var skin := MatLib.color(Color(0.5, 0.36, 0.29), 0.8)
	# ตัวไฟฉาย (ชี้ไปทาง -Z)
	MatLib.cyl(viewmodel, 0.022, 0.022, 0.2, Vector3(0, 0, 0.02), body_m, Vector3(90, 0, 0), 14)
	MatLib.cyl(viewmodel, 0.024, 0.024, 0.08, Vector3(0, 0, 0.06), grip_m, Vector3(90, 0, 0), 14)
	MatLib.cyl(viewmodel, 0.036, 0.024, 0.06, Vector3(0, 0, -0.105), body_m, Vector3(90, 0, 0), 16)
	MatLib.cyl(viewmodel, 0.037, 0.037, 0.008, Vector3(0, 0, -0.136), chrome, Vector3(90, 0, 0), 16)
	MatLib.box(viewmodel, Vector3(0.012, 0.01, 0.025), Vector3(0, 0.024, -0.02), MatLib.color(Color(0.5, 0.1, 0.08), 0.5))
	_lens_mat = MatLib.unique_emissive(Color(1.0, 0.95, 0.8), 0.0)
	_lens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_lens_mat.albedo_color = Color(0.25, 0.25, 0.22)
	MatLib.cyl(viewmodel, 0.031, 0.031, 0.004, Vector3(0, 0, -0.139), _lens_mat, Vector3(90, 0, 0), 16)
	# มือที่กำไฟฉาย + แขน (ข้าวฟ่างใส่เสื้อแขนสั้น)
	var hand := Node3D.new()
	hand.position = Vector3(0.0, -0.004, 0.035)
	viewmodel.add_child(hand)
	var palm := CapsuleMesh.new()
	palm.radius = 0.03
	palm.height = 0.1
	var pm := MeshInstance3D.new()
	pm.mesh = palm
	pm.material_override = skin
	pm.rotation_degrees = Vector3(90, 0, 0)
	pm.position = Vector3(0.018, -0.006, 0.0)
	hand.add_child(pm)
	for i in 4:
		var f := CapsuleMesh.new()
		f.radius = 0.0105
		f.height = 0.06
		var fm := MeshInstance3D.new()
		fm.mesh = f
		fm.material_override = skin
		fm.rotation_degrees = Vector3(0, 0, 70)
		fm.position = Vector3(-0.012, 0.012, -0.03 + 0.02 * i)
		hand.add_child(fm)
	var thumb := CapsuleMesh.new()
	thumb.radius = 0.011
	thumb.height = 0.07
	var tm := MeshInstance3D.new()
	tm.mesh = thumb
	tm.material_override = skin
	tm.rotation_degrees = Vector3(80, 0, -20)
	tm.position = Vector3(-0.006, 0.026, -0.035)
	hand.add_child(tm)
	var arm := MatLib.cyl(viewmodel, 0.027, 0.034, 0.32, Vector3(0.045, -0.06, 0.21), skin, Vector3(72, 0, -10), 12)
	arm.name = "Forearm"
	for c in viewmodel.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(c as VisualInstance3D).layers = 2  # ไม่ให้ไฟฉาย/แสงสะท้อนส่องโดนมือตัวเองจนขาวโพลน
	# แสงไฟฉายออกจากหน้าเลนส์
	flashlight.reparent(viewmodel, false)
	flashlight.position = Vector3(0, 0, -0.16)
	flashlight.rotation = Vector3.ZERO
	flashlight.light_cull_mask = 0xFFFFF & ~2
	# แสงสะท้อนรอบตัว (bounce) ให้รอบ ๆ ไม่มืดสนิทตอนเปิดไฟฉาย
	_fill_light = OmniLight3D.new()
	_fill_light.light_color = Color(1.0, 0.92, 0.8)
	_fill_light.light_energy = 0.22
	_fill_light.omni_range = 4.0
	_fill_light.omni_attenuation = 1.8
	_fill_light.shadow_enabled = false
	_fill_light.visible = false
	_fill_light.position = Vector3(0, 0, -0.6)
	_fill_light.light_cull_mask = 0xFFFFF & ~2
	camera.add_child(_fill_light)


# แอนิเมชันไฟฉายในมือ: โยกตามการเดิน แกว่งตามเมาส์ ยกตอนย่อ และเลนส์สว่างตามไฟฉาย
func _update_viewmodel(delta: float) -> void:
	if viewmodel == null:
		return
	viewmodel.visible = not hidden_in and not dead
	_vm_sway = _vm_sway.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	var hv := Vector2(velocity.x, velocity.z).length()
	var amp := clampf(hv / 4.0, 0.0, 1.0)
	var bob := Vector3(sin(bob_t * 0.5) * 0.012, -absf(cos(bob_t * 0.5)) * 0.01, 0) * amp
	var target := _vm_base + bob + Vector3(_vm_sway.x, _vm_sway.y, 0)
	if crouching:
		target += Vector3(-0.02, 0.02, 0.02)
	viewmodel.position = viewmodel.position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))
	viewmodel.rotation_degrees.z = lerpf(viewmodel.rotation_degrees.z, -_vm_sway.x * 120.0, clampf(delta * 8.0, 0.0, 1.0))
	var e := flashlight.light_energy / FLASH_ENERGY if flashlight_on else 0.0
	_lens_mat.emission_energy_multiplier = 4.0 * e
	_fill_light.visible = flashlight_on
	_fill_light.light_energy = 0.22 * e


# สร้างตัวเล่นเสียงแบบลูปเริ่มที่เงียบ (-80 dB) แล้วปรับดังขึ้นตามสถานการณ์
func _make_loop(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.get_stream(sound)
	p.bus = "SFX"
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


# ------------------------------------------------------------------ input
# รับ input: เมาส์หมุนมุมมอง (ตอนซ่อนจำกัดมุมที่หันได้), ปุ่มไฟฉาย, ปุ่มโต้ตอบ
func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not controls_locked:
		var s := GameState.mouse_sensitivity
		var inv := -1.0 if GameState.invert_y else 1.0
		rotate_y(-event.relative.x * s)
		_vm_sway += Vector2(event.relative.x, -event.relative.y * inv) * s * 0.06
		_vm_sway = _vm_sway.limit_length(0.035)
		pitch = clampf(pitch - event.relative.y * s * inv, -1.45, 1.45)
		if hidden_in:
			rotation.y = hide_yaw_center + clampf(wrapf(rotation.y - hide_yaw_center, -PI, PI), -0.9, 0.9)
			pitch = clampf(pitch, -0.5, 0.5)
		head.rotation.x = pitch
	if controls_locked:
		return
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("interact"):
		_do_interact()


# เปิด/ปิดไฟฉาย (force = บังคับเปิด/ปิด) ถ้ายังไม่มีไฟฉายหรือกำลังซ่อนอยู่เปิดไม่ได้
func toggle_flashlight(force: Variant = null) -> void:
	if not GameState.has_item("flashlight"):
		if force == null:
			GameState.say("(มืดเกินไป... ต้องหาอะไรส่องทาง)", 2.0)
		return
	var target: bool = (not flashlight_on) if force == null else bool(force)
	if hidden_in and target:
		GameState.say("(เปิดไฟตอนซ่อนอยู่ไม่ได้ เธอจะเห็น)", 2.0)
		return
	if target == flashlight_on:
		return
	flashlight_on = target
	flashlight.visible = flashlight_on
	Sfx.play("click", -6.0)


# ------------------------------------------------------------------ physics
# การเคลื่อนที่ ทำงานทุกเฟรมฟิสิกส์ (ตอนซ่อนใช้ _hidden_process แทน)
func _physics_process(delta: float) -> void:
	if dead:
		return
	if hidden_in:
		_hidden_process(delta)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Vector2.ZERO
	if not controls_locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# ย่อตัว: กดค้างจึงย่อ ปล่อยแล้วลุกได้ต่อเมื่อเพดานไม่เตี้ยเกินไป
	var want_crouch := Input.is_action_pressed("crouch") and not controls_locked
	if want_crouch:
		crouching = true
	elif crouching and not _ceiling_blocked():
		crouching = false

	var moving := input_dir.length() > 0.1
	# วิ่ง: ต้องเดินอยู่ ไม่ย่อ และมีแรง — วิ่งแล้วแรงลด 22/วินาที พักครู่หนึ่งแล้วฟื้น 15/วินาที
	sprinting = Input.is_action_pressed("sprint") and moving and not crouching and stamina > 1.0 and not controls_locked
	if sprinting:
		stamina = maxf(stamina - 22.0 * delta, 0.0)
		stamina_delay = 1.0
	else:
		stamina_delay -= delta
		if stamina_delay <= 0.0:
			stamina = minf(stamina + 15.0 * delta, 100.0)

	# เลือกความเร็วตามท่าทาง แล้วค่อย ๆ เร่ง/ชะลอเข้าหาความเร็วเป้าหมาย
	var speed := walk_speed
	if crouching:
		speed = crouch_speed
	elif sprinting:
		speed = sprint_speed
	var target_v := dir * speed
	velocity.x = move_toward(velocity.x, target_v.x, acceleration * delta * speed)
	velocity.z = move_toward(velocity.z, target_v.z, acceleration * delta * speed)
	move_and_slide()
	_push_props()

	# ฝีเท้า + เสียง
	# ฝีเท้า + เสียง
	var hv := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hv > 0.4:
		# เสียงก้าวตรงกับจังหวะโยกของกล้อง (1 ก้าว = ครึ่งรอบของ bob) เดินปกติประมาณ 2 ก้าว/วินาที
		# เดิมใช้ระยะก้าว 0.75 ม. ที่ความเร็ว 2.6 ม./วิ = 3.5 ก้าว/วินาที (เร็วเหมือนวิ่งเหยาะ) และไม่ตรงกับภาพ
		var prev_step := floori(bob_t / PI)
		bob_t += delta * hv * 2.4
		if floori(bob_t / PI) != prev_step:
			_footstep()
	else:
		bob_t = lerpf(bob_t, roundf(bob_t / PI) * PI, delta * 4.0)

	# ความสูงกล้อง + collider ตอนย่อ
	# ความสูงกล้องและตัวชนตอนย่อ/ยืน พร้อมโยกกล้องตามจังหวะก้าว (วิ่งโยกแรงกว่า)
	var head_h := CROUCH_HEAD if crouching else STAND_HEAD
	var bob_amt := 0.05 if sprinting else 0.025
	head.position.y = lerpf(head.position.y, head_h + sin(bob_t) * bob_amt, delta * 10.0)
	var cap := col.shape as CapsuleShape3D
	var col_h := CROUCH_COL if crouching else STAND_COL
	if not is_equal_approx(cap.height, col_h):
		cap.height = col_h
		col.position.y = col_h * 0.5

	# ตกหลุดโลก: วาร์ปกลับจุดเซฟ
	if global_position.y < -15.0:
		_rescue_fall()


# เพดานเตี้ยเกินกว่าจะลุกยืนไหม
func _ceiling_blocked() -> bool:
	return test_move(global_transform, Vector3(0, STAND_COL - CROUCH_COL + 0.05, 0))


# ดันของที่เป็น RigidBody (ขวด เก้าอี้ ฯลฯ) เมื่อเดินชน
func _push_props() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider()
		if body is RigidBody3D:
			var push_dir := -c.get_normal()
			push_dir.y = 0.0
			var hv := Vector2(velocity.x, velocity.z).length()
			(body as RigidBody3D).apply_central_impulse(push_dir.normalized() * hv * 0.35)


# เล่นเสียงก้าวเดิน เลือกเสียงตามพื้น (หญ้าข้างนอก / พื้นไม้ข้างใน) และท่าทาง
# ท่าทางกำหนดทั้งความดังและ "รัศมีเสียงที่ผีได้ยิน": วิ่ง 12 ม. เดิน 3.5 ม. ย่อ 0 (ผีไม่ได้ยิน)
func _footstep() -> void:
	var outside := global_position.z < 0.0 and global_position.y < 1.0
	step_index += 1
	var snd := ""
	if outside:
		snd = "step_grass_%d" % (randi() % 5 + 1)
	elif sprinting:
		snd = "step_wood_run_%d" % (randi() % 4 + 1)
	else:
		snd = "step_wood_%d" % (randi() % 6 + 1)
	var vol := -6.0
	var radius := NOISE_WALK
	noise_level = 0.35
	if sprinting:
		vol = 0.0
		radius = NOISE_SPRINT
		noise_level = 1.0
	elif crouching:
		vol = -19.0
		radius = NOISE_CROUCH
		noise_level = 0.05
	# เสียงเท้ามาจากพื้นใต้ตัว ไม่ใช่กลางลำตัว
	# สลับเท้าซ้าย/ขวา (ระดับเสียงและโทนต่างกันเล็กน้อย) + ความดังไม่เท่ากันทุกก้าว
	var left_foot := step_index % 2 == 0
	var pitch := Sfx.random_pitch(0.05) * (1.0 if left_foot else 0.95)
	Sfx.play_at(snd, global_position + Vector3(0, 0.05, 0), vol + randf_range(-2.5, 1.0), pitch, 25.0)
	if radius > 0.0:
		GameState.make_noise(global_position, radius, "footstep")


# กู้ผู้เล่นที่ตกหลุดแมพ: กลับไปจุดเซฟล่าสุด
func _rescue_fall() -> void:
	velocity = Vector3.ZERO
	if GameState.has_checkpoint():
		global_transform = GameState.checkpoint.xform
	else:
		global_position = Vector3(3, 0.2, 9)


# ------------------------------------------------------------------ ต่อเฟรม
# ทำงานทุกเฟรมภาพ: โต้ตอบ, แสง/สติ, ไฟฉาย, เสียง, โมเดลไฟฉาย, ความสั่นของกล้อง
func _process(delta: float) -> void:
	if dead:
		_update_audio(delta)
		return
	_update_interact()
	_update_light_and_sanity(delta)
	_update_flashlight(delta)
	_update_audio(delta)
	_update_viewmodel(delta)
	noise_level = maxf(noise_level - delta * 0.8, 0.0)
	# สั่นกล้อง
	shake = maxf(shake - delta * 1.5, 0.0)
	var sh := shake + (0.0 if GameState.sanity > 25.0 else (25.0 - GameState.sanity) / 25.0 * 0.15)
	camera.h_offset = randf_range(-1, 1) * sh * 0.03
	camera.v_offset = randf_range(-1, 1) * sh * 0.03


# ตรวจสิ่งที่เล็งอยู่ว่าโต้ตอบได้ไหม (ตอนซ่อนอยู่ โต้ตอบได้เฉพาะที่ซ่อน = ออกจากที่ซ่อน)
func _update_interact() -> void:
	current_interactable = null
	if controls_locked:
		return
	if hidden_in:
		current_interactable = hidden_in
		return
	if ray.is_colliding():
		var n := find_interactable(ray.get_collider())
		if n != null and (not n.has_method("can_interact") or n.can_interact(self)):
			current_interactable = n


# หาโหนดที่มีเมธอด interact() โดยไล่ขึ้นไปหาโหนดแม่ (สูงสุด 5 ชั้น)
static func find_interactable(node: Object) -> Node:
	var n := node as Node
	var depth := 0
	while n != null and depth < 5:
		if n.has_method("interact"):
			return n
		n = n.get_parent()
		depth += 1
	return null


# ข้อความบอกปุ่มที่แสดงบน HUD เช่น "[E] เปิดประตู"
func get_prompt() -> String:
	if current_interactable == null:
		return ""
	if current_interactable.has_method("get_prompt"):
		return current_interactable.get_prompt(self)
	return "โต้ตอบ"


# กด E: สั่งวัตถุที่เล็งอยู่ทำงาน
func _do_interact() -> void:
	if current_interactable != null:
		current_interactable.interact(self)


# คำนวณสติ (Sanity 0-100) ทุกเฟรม
# อยู่ใกล้แสงเทียน +7/วินาที | เปิดไฟฉายลดช้า | อยู่ในที่มืดลด (บท 1+ ลดเร็วขึ้น) | ซ่อนอยู่ลดช้าลง
# เห็นผีในระยะ 10 ม. สติลดแรง (ซ่อนอยู่ลดน้อยกว่า) | สติถึง 0 = ตาย
func _update_light_and_sanity(delta: float) -> void:
	in_light = false
	for l in get_tree().get_nodes_in_group("light_source"):
		if l.has_method("illuminates") and l.illuminates(global_position):
			in_light = true
			break
	in_safe = false
	for z in get_tree().get_nodes_in_group("safe_zone"):
		if z.has_method("contains") and z.contains(global_position):
			in_safe = true
			break

	var rate := 0.0
	if in_light:
		rate = 7.0
	elif flashlight_on:
		rate = -0.3
	else:
		rate = -0.9 if GameState.phase == 0 else -1.6
	if hidden_in and not in_light:
		rate *= 0.6

	ghost_visible = false
	var g := GameState.ghost
	if g != null and g.is_active():
		var gp: Vector3 = g.global_position + Vector3.UP * 1.4
		if gp.distance_to(camera.global_position) < 10.0 and can_see_point(gp):
			ghost_visible = true
			rate -= (2.0 if hidden_in != null else 6.0)
	GameState.sanity = clampf(GameState.sanity + rate * delta, 0.0, 100.0)
	if GameState.sanity <= 0.0 and not dead:
		die("sanity")


# จุด p อยู่ในจอและไม่มีกำแพงบังไหม (ใช้ตรวจว่าผู้เล่นมองเห็นผีหรือไม่)
func can_see_point(p: Vector3) -> bool:
	if not camera.is_position_in_frustum(p):
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(camera.global_position, p, GameState.PHYS_WORLD | GameState.PHYS_DOOR)
	return space.intersect_ray(q).is_empty()


# ไฟฉายร้อนขึ้นตอนเปิด เต็มแล้วจะส่งเสียงดึงดูดผีรัศมี 60 ม. (บท 1+) แล้วลดความร้อนลงบางส่วน
# ไฟกระพริบเมื่อร้อนจัดหรือผีอยู่ใกล้ (ใน 7 ม.)
func _update_flashlight(delta: float) -> void:
	if flashlight_on:
		flash_heat += FLASH_HEAT_UP * delta
		if flash_heat >= 100.0:
			flash_heat = 65.0
			if GameState.phase >= 1:
				GameState.make_noise(global_position, 60.0, "flashlight")
				GameState.say("แสงไฟฉายดึงดูดบางสิ่งเข้ามา...", 3.0)
				Sfx.play("sting", -8.0)
			elif not _flash_warned:
				_flash_warned = true
				GameState.say("(ยายเคยบอก... อย่าส่องไฟนาน ๆ)", 3.0)
	else:
		flash_heat = maxf(flash_heat - FLASH_HEAT_DOWN * delta, 0.0)
	# ไฟกระพริบเมื่อร้อนจัดหรือผีอยู่ใกล้
	var ghost_near := false
	var g := GameState.ghost
	if g != null and g.is_active() and g.global_position.distance_to(global_position) < 7.0:
		ghost_near = true
	if flashlight_on and (flash_heat > 75.0 or ghost_near) and randf() < 0.25:
		flashlight.light_energy = FLASH_ENERGY * randf_range(0.0, 0.8)
	else:
		flashlight.light_energy = lerpf(flashlight.light_energy, FLASH_ENERGY, delta * 10.0)


# ปรับเสียงลูปตามสถานการณ์: หัวใจเต้นเร็ว/ดังตามระยะผี+สติต่ำ, กระซิบดังขึ้นเมื่อสติต่ำกว่า 60
# (เสียงหายใจหอบแบบต่อเนื่องถูกปิดไว้ — เหลือเฉพาะเสียงหอบครั้งเดียวตอนกลั้นหายใจหมด)
func _update_audio(delta: float) -> void:
	var intensity := 0.0
	var g := GameState.ghost
	if g != null and g.is_active() and not dead:
		var d: float = g.global_position.distance_to(global_position)
		intensity = clampf(1.0 - d / 14.0, 0.0, 1.0)
		if g.is_chasing():
			intensity = maxf(intensity, 0.7)
	intensity = maxf(intensity, clampf((35.0 - GameState.sanity) / 35.0, 0.0, 1.0) * 0.8)
	_set_loop_vol(heart_player, intensity, -30.0, 2.0, delta)
	heart_player.pitch_scale = lerpf(0.9, 1.6, intensity)
	var w := clampf((60.0 - GameState.sanity) / 60.0, 0.0, 1.0)
	_set_loop_vol(whisper_player, w, -36.0, -12.0, delta)
	var b := clampf((40.0 - stamina) / 40.0, 0.0, 1.0)
	if hidden_in and not holding_breath and g != null and g.is_active() and g.global_position.distance_to(global_position) < 6.0:
		b = 1.0
	if holding_breath:
		b = 0.0
	_set_loop_vol(breath_player, 0.0, -30.0, -6.0, delta)  # ตัดเสียงหายใจหอบแบบต่อเนื่องออก (เสียงหอบครั้งเดียวตอนกลั้นหายใจหมดยังอยู่)


# ปรับความดังเสียงลูปให้ค่อย ๆ เปลี่ยนเข้าหาเป้าหมาย t (0-1 แปลงเป็นช่วง lo-hi เดซิเบล) ถ้า t ต่ำมากปิดเสียง
func _set_loop_vol(p: AudioStreamPlayer, t: float, lo: float, hi: float, delta: float) -> void:
	var target := -80.0 if t < 0.02 else lerpf(lo, hi, t)
	p.volume_db = move_toward(p.volume_db, target, delta * 60.0)
	if not p.playing:
		p.play()


# ------------------------------------------------------------------ ซ่อนตัว
# มุดเข้าที่ซ่อน: ปิดไฟฉาย ปิดตัวชน ล็อกการเดิน แล้วเลื่อนกล้องไปตำแหน่งมองจากในตู้/ใต้เตียง
func enter_hide(spot: Node3D) -> void:
	if hidden_in != null or dead:
		return
	toggle_flashlight(false)
	hidden_in = spot
	col.disabled = true
	velocity = Vector3.ZERO
	crouching = false
	var view_pos: Vector3 = spot.get_view_position()
	var view_h: float = spot.get_view_height()
	hide_yaw_center = spot.get_view_yaw()
	controls_locked = true
	if _hide_tween:
		_hide_tween.kill()
	_hide_tween = create_tween().set_parallel(true)
	_hide_tween.tween_property(self, "global_position", view_pos - Vector3(0, view_h, 0), 0.45)
	_hide_tween.tween_property(head, "position:y", view_h, 0.45)
	_hide_tween.tween_property(self, "rotation:y", hide_yaw_center, 0.45)
	_hide_tween.tween_property(head, "rotation:x", 0.0, 0.45)
	_hide_tween.chain().tween_callback(func(): controls_locked = false)
	pitch = 0.0


# ออกจากที่ซ่อน: เลื่อนกลับไปหน้าที่ซ่อนและคืนการควบคุม
func exit_hide() -> void:
	if hidden_in == null or dead:
		return
	var spot := hidden_in
	var exit_pos: Vector3 = spot.get_exit_position()
	controls_locked = true
	if _hide_tween:
		_hide_tween.kill()
	_hide_tween = create_tween().set_parallel(true)
	_hide_tween.tween_property(self, "global_position", exit_pos, 0.4)
	_hide_tween.tween_property(head, "position:y", STAND_HEAD, 0.4)
	_hide_tween.chain().tween_callback(func():
		col.disabled = false
		hidden_in = null
		holding_breath = false
		controls_locked = false
	)


# ผู้เล่นซ่อนอยู่ไหม (ผีใช้ตรวจ — ซ่อนอยู่ผีมองไม่เห็น)
func is_hidden() -> bool:
	return hidden_in != null


# ทำงานตอนซ่อนอยู่: กด Space กลั้นหายใจ (ได้ประมาณ 12 วินาที ฟื้นเร็วกว่าตอนกลั้น)
# ลมหมด = หอบดังรัศมี 2.2 ม. (ผีใกล้ ๆ ได้ยินทันที) ถ้าไม่กลั้นและผีอยู่ใกล้ (2.6 ม.) มีเสียงหายใจให้ผีสงสัย
func _hidden_process(delta: float) -> void:
	var want_hold := Input.is_action_pressed("hold_breath") and breath_exhausted <= 0.0 and not controls_locked
	holding_breath = want_hold and breath > 0.0
	if holding_breath:
		breath -= 100.0 / 12.0 * delta
		if breath <= 0.0:
			breath = 0.0
			holding_breath = false
			breath_exhausted = 2.5
			Sfx.play("breath", 0.0, 1.3)
			GameState.make_noise(global_position, 2.2, "gasp")
			GameState.say("(หายใจหอบ!)", 1.5)
	else:
		breath = minf(breath + 18.0 * delta, 100.0)
	breath_exhausted = maxf(breath_exhausted - delta, 0.0)

	breath_timer -= delta
	var g := GameState.ghost
	if not holding_breath and g != null and g.is_active() and breath_timer <= 0.0:
		if g.global_position.distance_to(global_position) < 2.6:
			breath_timer = 1.8
			GameState.make_noise(global_position, 2.6, "breath")


# ------------------------------------------------------------------ ตาย
# ตาย: reason = "sanity" (สติหมด ล้มลง) หรือ "caught" (ผีจับ ผีเป็นคนสั่ง jumpscare เอง)
func die(reason: String) -> void:
	if dead:
		return
	dead = true
	controls_locked = true
	toggle_flashlight(false)
	current_interactable = null
	if reason == "sanity":
		Sfx.play("sting", 0.0, 0.7)
		var t := create_tween().set_parallel(true)
		t.tween_property(head, "position:y", 0.3, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(head, "rotation:z", 1.2, 1.6)
		t.chain().tween_interval(1.0)
		t.chain().tween_callback(func(): GameState.player_died.emit(reason))
	# reason "caught" — ผีเป็นคนสั่ง jumpscare แล้วเรียก GameState.player_died เอง


# หันกล้องไปมองจุด p ในเวลา duration วินาที (ใช้ตอน jumpscare และเหตุการณ์)
func face_point(p: Vector3, duration: float = 0.25) -> void:
	var to := p - camera.global_position
	var yaw := atan2(-to.x, -to.z)
	var horiz := Vector2(to.x, to.z).length()
	var pt := atan2(to.y, horiz)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "rotation:y", rotation.y + wrapf(yaw - rotation.y, -PI, PI), duration)
	t.tween_property(head, "rotation:x", pt, duration)
	pitch = pt


# ตัวคูณความง่ายที่ผีจะเห็น: ย่อ x0.6 (เห็นยากขึ้น) | เปิดไฟฉาย x1.8 | อยู่ในแสงเทียน x1.25
# ผีเอาไปคูณกับระยะมองของตัวเอง
func get_visibility_factor() -> float:
	var f := 1.0
	if crouching:
		f *= 0.6
	if flashlight_on:
		f *= 1.8
	if in_light:
		f *= 1.25
	return f


# อ่าน/ตั้งมุมกล้อง (ใช้บันทึกและกู้จุดเซฟ)
func get_look() -> Vector2:
	return Vector2(rotation.y, pitch)


func apply_look(v: Vector2) -> void:
	rotation.y = v.x
	pitch = v.y
	head.rotation.x = pitch
