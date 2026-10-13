extends Node3D
class_name Ghost
## แม่หญิงชุดขาว — วิญญาณผู้พิทักษ์บ้าน
## State machine: DORMANT → STARE → PATROL ⇄ INVESTIGATE (ได้ยินเสียง) ⇄ CHASE (เห็นผู้เล่น) → SEARCH
## - เห็น: กรวยสายตา + raycast (ผนัง/ประตูบัง) ระยะคูณด้วย visibility ของผู้เล่น (ไฟฉาย/ย่อ/แสงเทียน)
## - ได้ยิน: รับ GameState.noise_made (ฝีเท้า, ชนของ, ไฟฉายร้อนเกิน, เสียงหายใจตอนซ่อน)
## - เป็นวิญญาณ: ลอยทะลุประตูได้ (navmesh ไม่นับประตู) แต่เข้าห้องพระที่จุดเทียนไว้ไม่ได้

# สถานะของผี (state machine)
# DORMANT=หลับ/ยังไม่ปรากฏ  STARE=ยืนจ้องผู้เล่นตอนปรากฏตัว  PATROL=เดินลาดตระเวน
# INVESTIGATE=เดินไปตรวจจุดที่ได้ยินเสียง  CHASE=ไล่ล่า  SEARCH=ค้นหาจุดที่เห็นล่าสุด
# RETREAT=ถอย/จางหาย (เช่น เข้าห้องพระไม่ได้)  JUMPSCARE=จับผู้เล่นได้
enum State { DORMANT, STARE, PATROL, INVESTIGATE, CHASE, SEARCH, RETREAT, JUMPSCARE }

# โหนดลูกที่ใช้อ้างอิง: ตัวหาเส้นทาง (navmesh), โมเดลผี, แสงรอบตัว, เสียงฮัม
@onready var agent: NavigationAgent3D = $Agent
@onready var model: GhostSprite = $Model
@onready var aura: OmniLight3D = $Aura
@onready var hum: AudioStreamPlayer3D = $Hum

# สถานะปัจจุบัน
var state: State = State.DORMANT
# ความเร็ว (เมตร/วินาที) แต่ละสถานะ และระยะมองเห็น — ถูกเปลี่ยนตามบทใน apply_phase_stats()
var patrol_speed := 1.4
var investigate_speed := 2.2
var chase_speed := 3.3
var view_range := 13.0
# ครึ่งหนึ่งของมุมกรวยสายตา (60° = มองกว้างรวม 120°)
var view_half_angle := deg_to_rad(60.0)

# ความสงสัย 0..1 เห็นผู้เล่นแล้วค่าเพิ่ม ถึง 1 เริ่มไล่ล่า (ไม่ได้ไล่ทันทีที่เห็น)
var suspicion := 0.0
# ตัวจับเวลาและตัวช่วยของแต่ละสถานะ: เวลาในสถานะ, เวลารอ, ตำแหน่งที่เห็นล่าสุด, เวลาที่มองไม่เห็นผู้เล่น
var state_time := 0.0
var wait_time := 0.0
var last_seen := Vector3.ZERO
var lost_time := 0.0
# ที่ซ่อนที่ผีรู้ว่าผู้เล่นซ่อนอยู่ (ตู้/เตียง) — null = ไม่รู้
var target_hide: Node3D = null
# ตัวนับเวลาสำหรับคำนวณเส้นทางใหม่ / เวลาที่ผู้เล่นอยู่ไกล / จับเวลาไล่ล่าช่วงบท 3 / จำนวนจุดที่ยังต้องค้นหา
var repath_t := 0.0
var far_time := 0.0
var hunt_t := 0.0
var search_points := 0
# navmesh พร้อมใช้งานหรือยัง (ตอน bake ใหม่ผีจะหยุดอยู่กับที่)
var nav_ready := false
# ตัวแปรสำหรับแอนิเมชันลอยขึ้นลงและกระพริบ
var bob_t := 0.0
var flicker_t := 3.0
# ตัวแปรภายใน: เฟรมที่แล้วเห็นผู้เล่นไหม, จุดลาดตระเวนล่าสุด, ถึงเป้าหมายแล้วไหม
var _saw_player := false
var _last_patrol: Node3D = null
var _arrived := false
# true = จ้องแล้วค่อย ๆ จางหายไป (ปรากฏตัวให้เห็นแล้วหายวับ ตอนเปิดบท 1)
var vanish_after_stare := false
var hide_suspicion := 0.0  # ได้ยินเสียงหายใจจากที่ซ่อนสะสม (ถึง 1 = รู้ว่าซ่อนตรงไหน)


# เริ่มต้น: ลงทะเบียนตัวเองกับ GameState, ฟังสัญญาณเสียงจากผู้เล่น/ของในฉาก, ตั้งค่าตัวหาเส้นทาง แล้วเริ่มในสถานะหลับ
func _ready() -> void:
	GameState.ghost = self
	GameState.noise_made.connect(_on_noise)
	agent.path_desired_distance = 0.45
	agent.target_desired_distance = 0.6
	agent.path_height_offset = 0.0
	set_dormant()


# ผีกำลังปรากฏอยู่ในเกมไหม (ไม่ได้หลับและมองเห็นได้)
func is_active() -> bool:
	return state != State.DORMANT and visible


func is_chasing() -> bool:
	return state == State.CHASE


# ------------------------------------------------------------------ ควบคุมจากเลเวล
# สั่งให้ผีหลับ: ซ่อนตัวและหยุดเสียงฮัม
func set_dormant() -> void:
	state = State.DORMANT
	visible = false
	hum.stop()


# ปลุกผีที่ตำแหน่ง at  stare=true: จ้องผู้เล่นก่อน / false: เริ่มลาดตระเวนทันที
# vanish_after=true: จ้องเสร็จแล้วหายวับ
func activate(at: Vector3, stare: bool = true, vanish_after: bool = false) -> void:
	vanish_after_stare = vanish_after
	visible = true
	global_position = closest_nav(at)
	model.set_fade(1.0)
	apply_phase_stats()
	if not hum.playing:
		hum.play()
	_set_state(State.STARE if stare else State.PATROL)
	if not stare:
		_next_patrol()


# ตั้งความเร็วและระยะมองตามบทของเรื่อง ยิ่งบทสูงผียิ่งเร็วและมองไกลขึ้น (0 = ช่วงเริ่มเกม, 1-3 = บทที่ 1-3)
func apply_phase_stats() -> void:
	match GameState.phase:
		0:
			patrol_speed = 1.2
			investigate_speed = 1.9
			chase_speed = 3.0
			view_range = 11.0
		1:
			patrol_speed = 1.4
			investigate_speed = 2.2
			chase_speed = 3.3
			view_range = 13.0
		2:
			patrol_speed = 1.6
			investigate_speed = 2.5
			chase_speed = 3.7
			view_range = 14.0
		_:
			patrol_speed = 1.9
			investigate_speed = 2.8
			chase_speed = 4.0
			view_range = 15.0


# วาร์ปผีไปยังจุดที่ใกล้ที่สุดบนพื้นที่เดินได้
func teleport(pos: Vector3) -> void:
	global_position = closest_nav(pos)
	agent.target_position = global_position


# หาจุดบน navmesh ที่ใกล้ตำแหน่ง pos ที่สุด (กันสั่งให้ผีไปยืนในกำแพง)
func closest_nav(pos: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return pos
	return NavigationServer3D.map_get_closest_point(map, pos)


# ------------------------------------------------------------------ loop หลัก
# ทำงานทุกเฟรมฟิสิกส์: รับรู้ผู้เล่น (_sense) แล้วทำตามสถานะปัจจุบัน
func _physics_process(delta: float) -> void:
	if state == State.DORMANT or state == State.JUMPSCARE:
		return
	if not nav_ready:
		return
	state_time += delta
	var p: Player = GameState.player as Player
	if p != null and p.dead:
		_animate(delta)
		return
	# ตรวจว่าเห็นผู้เล่นไหม แล้วอัปเดตความสงสัย / ค่าสงสัยจากเสียงหายใจค่อย ๆ ลดลงเองเมื่อเวลาผ่านไป
	_sense(delta, p)
	hide_suspicion = maxf(hide_suspicion - delta * 0.12, 0.0)

	# พฤติกรรมของแต่ละสถานะ
	match state:
		# STARE: หันจ้องผู้เล่นประมาณ 2.8 วินาที แล้วลาดตระเวนต่อ (หรือถอยหายถ้าสั่งให้หายวับ)
		State.STARE:
			if p:
				_face_dir(p.global_position - global_position, delta, 6.0)
			if state_time > 2.8:
				if vanish_after_stare:
					vanish_after_stare = false
					_set_state(State.RETREAT)
				else:
					_set_state(State.PATROL)
					_next_patrol()
		# PATROL: เดินไปจุดลาดตระเวน ถึงแล้วหยุดรอ หมุนตัวมองรอบ ๆ แล้วเลือกจุดถัดไป
		State.PATROL:
			if _move(patrol_speed, delta):
				if wait_time <= 0.0:
					wait_time = randf_range(1.0, 3.0)
				wait_time -= delta
				rotate_y(delta * 0.6)
				if wait_time <= 0.0:
					_next_patrol()
		# INVESTIGATE: เดินไปจุดที่ได้ยินเสียง ถึงแล้วมองรอบ ๆ แล้วเปลี่ยนเป็นค้นหา
		State.INVESTIGATE:
			if _move(investigate_speed, delta):
				wait_time -= delta
				rotate_y(delta * 1.2)
				if wait_time <= 0.0:
					_set_state(State.SEARCH)
					search_points = 2
					_search_next()
		# CHASE: ไล่ล่าผู้เล่น (ดู _chase)
		State.CHASE:
			_chase(delta, p)
		# SEARCH: เดินค้นหารอบจุดที่เห็นผู้เล่นล่าสุด 2 จุด ไม่เจอก็กลับไปลาดตระเวน
		State.SEARCH:
			if _move(investigate_speed * 0.8, delta):
				wait_time -= delta
				rotate_y(delta * 1.5)
				if wait_time <= 0.0:
					if search_points > 0:
						_search_next()
					else:
						_set_state(State.PATROL)
						_next_patrol()
		# RETREAT: ตัวผีจางหายไป แล้ววาร์ปไปจุดที่ไกลที่สุดจากผู้เล่น
		State.RETREAT:
			model.set_fade(maxf(model.get_fade() - delta * 0.8, 0.0))
			if state_time > 1.6:
				_respawn_far(p)

	# ตรวจจับผู้เล่นได้ไหม / วาร์ปเข้าใกล้ถ้าผู้เล่นอยู่ไกลเกินไป / บทที่ 3 คอยไล่กดดัน
	if p != null:
		_check_catch(p)
		_far_teleport_check(delta, p)
		_hunt(delta, p)
	_animate(delta)


# เปลี่ยนสถานะ พร้อมรีเซ็ตตัวจับเวลา
func _set_state(s: State) -> void:
	state = s
	state_time = 0.0
	wait_time = 0.0
	_arrived = false


# เลือกจุดลาดตระเวนถัดไปจากกลุ่ม ghost_patrol
# 60% เลือกจุดที่อยู่ใกล้ผู้เล่น (ภายใน 16 ม.) เพื่อให้ผีวนเวียนใกล้ผู้เล่น ที่เหลือสุ่มทั้งบ้าน
func _next_patrol() -> void:
	var pts := get_tree().get_nodes_in_group("ghost_patrol")
	if pts.is_empty():
		return
	var p := GameState.player as Node3D
	var near: Array = []
	if p:
		for pt in pts:
			if pt != _last_patrol and (pt as Node3D).global_position.distance_to(p.global_position) < 16.0:
				near.append(pt)
	var choice: Node3D
	if not near.is_empty() and randf() < 0.6:
		choice = near.pick_random()
	else:
		choice = pts.pick_random()
	_last_patrol = choice
	agent.target_position = closest_nav(choice.global_position)
	wait_time = 0.0
	_arrived = false


# เลือกจุดค้นหาถัดไป: รอบจุดที่เห็นล่าสุด ห่าง 4.5-8 ม. (ไม่ยืนแนบตู้ที่ผู้เล่นซ่อนนานเกินไป)
func _search_next() -> void:
	search_points -= 1
	# ค้นหารอบ ๆ จุดที่เห็นล่าสุด แต่ห่างออกไป 3-6 ม. (ไม่ยืนแนบตู้นานจนผู้เล่นกลั้นหายใจไม่ไหว)
	var ang := randf() * TAU
	var target := last_seen
	for i in 8:
		var off := Vector3(cos(ang), 0, sin(ang)) * randf_range(4.5, 8.0)
		target = closest_nav(last_seen + off)
		if target.distance_to(last_seen) > 3.5:
			break
		ang = randf() * TAU
	agent.target_position = target
	wait_time = randf_range(1.0, 2.0)
	_arrived = false


# สั่งให้ผีไปตรวจจุด pos (เรียกเมื่อได้ยินเสียง)
func investigate(pos: Vector3) -> void:
	_set_state(State.INVESTIGATE)
	agent.target_position = closest_nav(pos)
	last_seen = pos
	wait_time = randf_range(2.0, 3.5)


# เริ่มไล่ล่า: เล่นเสียงตกใจ แสดง !!! และตั้งค่าสถานะ
func _start_chase() -> void:
	if state != State.CHASE:
		Sfx.play_at("sting", global_position + Vector3.UP * 1.5, -2.0, 0.8)
		GameState.say("!!!", 1.0)
	_set_state(State.CHASE)
	suspicion = 1.0
	lost_time = 0.0


# พฤติกรรมไล่ล่า — อัปเดตเส้นทางทุก 0.2 วินาที
# ถ้ารู้ว่าซ่อนที่ไหน ไปที่ทางออกของที่ซ่อน / ถ้าเห็นอยู่ ตามตำแหน่งจริง (ยกเว้นผู้เล่นซ่อนอยู่) / ไม่งั้นไปจุดที่เห็นล่าสุด
# หาไม่เจอเกิน 2.5 วินาที เปลี่ยนไปค้นหา
func _chase(delta: float, p: Player) -> void:
	if p == null:
		return
	repath_t -= delta
	if repath_t <= 0.0:
		repath_t = 0.2
		if target_hide != null:
			agent.target_position = closest_nav(target_hide.get_exit_position())
		elif lost_time < 0.6 and not p.is_hidden():
			agent.target_position = closest_nav(p.global_position)
		else:
			agent.target_position = closest_nav(last_seen)
	_move(chase_speed, delta)
	if lost_time > 0.0 and lost_time < 1.0 and target_hide == null:
		pass
	if lost_time > 2.5 and target_hide == null:
		_set_state(State.SEARCH)
		search_points = 2
		agent.target_position = closest_nav(last_seen)
		wait_time = 1.2


# ------------------------------------------------------------------ การรับรู้
# การรับรู้ด้วยสายตา — คำนวณความสงสัยและสั่งไล่ล่า
func _sense(delta: float, p: Player) -> void:
	if p == null or state == State.STARE or state == State.RETREAT:
		return
	# ผู้เล่นอยู่ในห้องพระที่ปลอดภัย: ผีหยุดไล่และถอยออกไป
	if p.in_safe:
		if state == State.CHASE:
			GameState.say("(เธอหยุดอยู่หน้าห้องพระ... เข้ามาไม่ได้)", 3.0)
			Sfx.play_at("ghost_hum", global_position, 4.0, 0.7)
			_set_state(State.RETREAT)
		suspicion = 0.0
		target_hide = null
		return

	if not p.is_hidden():
		target_hide = null

	# เห็นผู้เล่นไหม — ถ้าเห็น ความสงสัยเพิ่มตามความสว่าง/ระยะ (ใกล้ + ไฟฉายเปิด = เพิ่มเร็ว) ครบ 1 เริ่มไล่ล่า
	var sees := _can_see_player(p)
	if sees:
		last_seen = p.global_position
		lost_time = 0.0
		if state != State.CHASE:
			var d := global_position.distance_to(p.global_position)
			var gain := 2.0 * p.get_visibility_factor() * clampf(8.0 / maxf(d, 1.0), 0.35, 3.0)
			suspicion += delta * gain
			if state == State.PATROL or state == State.SEARCH:
				_face_dir(p.global_position - global_position, delta, 2.0)
			if suspicion >= 1.0:
				_start_chase()
	else:
		# ไม่เห็น: ความสงสัยลดลงทีละน้อย และถ้ากำลังไล่ล่าอยู่ ให้นับเวลาที่มองไม่เห็น
		suspicion = maxf(suspicion - delta * 0.35, 0.0)
		if state == State.CHASE:
			lost_time += delta
			# เห็นผู้เล่นมุดเข้าที่ซ่อน "ต่อหน้าต่อตา" ในระยะประชิดเท่านั้น จึงรู้ว่าซ่อนตรงไหน
			if _saw_player and p.is_hidden() and target_hide == null:
				if global_position.distance_to(p.global_position) < 2.2:
					target_hide = p.hidden_in
	_saw_player = sees


# ผีเห็นผู้เล่นไหม ตรวจตามลำดับ
# 1) ผู้เล่นซ่อนอยู่ = มองไม่เห็นเลย  2) ระยะ (คูณด้วยปัจจัยการมองเห็น: ย่อ = เห็นยากขึ้น ไฟฉาย = เห็นง่ายขึ้น)
# 3) อยู่ในกรวยสายตา (หรือไฟฉายส่องเข้าตาผี)  4) ไม่มีกำแพง/ประตูบัง (ยิงลำแสงตรวจที่ระดับหัวและอก)
func _can_see_player(p: Player) -> bool:
	if p.is_hidden():
		return false
	var eye := global_position + Vector3.UP * 1.6
	var target := p.camera.global_position
	var to := target - eye
	var d := to.length()
	var rng := view_range * p.get_visibility_factor()
	if d > rng:
		return false
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	var flat := Vector3(to.x, 0, to.z)
	var in_cone := flat.length() < 0.01 or fwd.normalized().angle_to(flat.normalized()) < view_half_angle
	# แสงไฟฉายที่ส่องมาหาเธอ ทำให้เธอเห็นแม้ไม่ได้หันมา
	if not in_cone and p.flashlight_on and d < 16.0:
		var cam_fwd := -p.camera.global_transform.basis.z
		if cam_fwd.angle_to(-to.normalized()) < deg_to_rad(20.0):
			in_cone = true
	if not in_cone and d > 2.0 and state != State.CHASE:
		return false
	var space := get_world_3d().direct_space_state
	var mask := GameState.PHYS_WORLD | GameState.PHYS_DOOR
	for h in [0.0, -0.6]:
		var q := PhysicsRayQueryParameters3D.create(eye, target + Vector3(0, h, 0), mask)
		if space.intersect_ray(q).is_empty():
			return true
	return false


# ได้ยินเสียง: เสียงต้องอยู่ในรัศมีของมัน (เช่น วิ่ง 12 ม. เดิน 3.5 ม. ย่อ 0)
# เสียงหายใจตอนผู้เล่นซ่อน: สะสมความสงสัย ถึง 1 จึงรู้ว่าซ่อนตรงไหน / เสียงหอบ (gasp) รู้ทันที
# เสียงอื่น: ไปตรวจจุดนั้น (ถ้ากำลังไล่ล่าอยู่ไม่สนใจ)
func _on_noise(pos: Vector3, radius: float, source: String) -> void:
	if state in [State.DORMANT, State.JUMPSCARE, State.RETREAT, State.STARE]:
		return
	if not nav_ready:
		return
	var d := global_position.distance_to(pos)
	if d > radius:
		return
	var p: Player = GameState.player as Player
	if p != null and p.in_safe:
		return
	if (source == "breath" or source == "gasp") and p != null and p.is_hidden():
		# ได้ยินเสียงหายใจ: สงสัยก่อน (หยุดฟัง) ต้องได้ยินซ้ำถึงจะรู้ตำแหน่ง / หอบหายใจดัง = รู้ทันที
		hide_suspicion += 1.0 if source == "gasp" else 0.5
		if hide_suspicion >= 1.0:
			target_hide = p.hidden_in
			last_seen = p.global_position
			_start_chase()
		elif state != State.CHASE:
			investigate(pos)
			wait_time = 3.0
		return
	if state == State.CHASE:
		return
	investigate(pos)


# ------------------------------------------------------------------ จับ / jumpscare
# ตรวจว่าจับผู้เล่นได้ไหม: ระยะน้อยกว่า 0.95 ม. หรือยืนหน้าที่ซ่อนที่ตัวเองรู้ว่าผู้เล่นอยู่
func _check_catch(p: Player) -> void:
	if p.dead or p.in_safe or state == State.RETREAT or state == State.STARE:
		return
	if p.is_hidden():
		if target_hide != null and target_hide == p.hidden_in:
			var ex: Vector3 = target_hide.get_exit_position()
			if Vector2(global_position.x - ex.x, global_position.z - ex.z).length() < 1.2 and absf(global_position.y - ex.y) < 1.5:
				_jumpscare(p)
		return
	var d := Vector2(global_position.x - p.global_position.x, global_position.z - p.global_position.z).length()
	if d < 0.95 and absf(global_position.y - p.global_position.y) < 1.6:
		_jumpscare(p)


# จับผู้เล่นได้: ผีวาร์ปมายืนตรงหน้ากล้อง หันกล้องไปที่ผี สั่นจอ เล่นเสียงกรีด แล้วส่งสัญญาณผู้เล่นตาย
func _jumpscare(p: Player) -> void:
	_set_state(State.JUMPSCARE)
	p.die("caught")
	var cam := p.camera
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	global_position = cam.global_position + fwd * 0.75 - Vector3.UP * 1.55
	var look := cam.global_position
	look.y = global_position.y
	if look.distance_to(global_position) > 0.01:
		look_at(look, Vector3.UP)
	model.position = Vector3.ZERO
	model.set_fade(1.0)
	model.visible = true
	p.face_point(global_position + Vector3.UP * 1.6, 0.06)
	p.shake = 2.0
	aura.light_energy = 2.5
	hum.stop()
	model.set_glitch(1.0)
	Sfx.play("scream", 2.0)
	GameState.jumpscare.emit()
	var t := create_tween()
	t.tween_interval(1.5)
	t.tween_callback(func(): GameState.player_died.emit("caught"))


# ------------------------------------------------------------------ กดดันผู้เล่น
# ถ้าผีเดินลาดตระเวนห่างผู้เล่นเกิน 20 ม. (หรือคนละชั้น) นานเกินกำหนด วาร์ปมาใกล้ ๆ ในจุดที่ผู้เล่นมองไม่เห็น
func _far_teleport_check(delta: float, p: Player) -> void:
	if state != State.PATROL:
		far_time = 0.0
		return
	var d := global_position.distance_to(p.global_position)
	if d > 20.0 or absf(global_position.y - p.global_position.y) > 2.5:
		far_time += delta
	else:
		far_time = 0.0
	var limit := 30.0 if GameState.phase < 3 else 15.0
	if far_time > limit:
		far_time = 0.0
		var spot := _pick_point_near(p, 8.0, 16.0)
		if spot != Vector3.INF:
			teleport(spot)
			_next_patrol()


# บทที่ 3 (ทวงหนี้): ทุก 11 วินาที ผีสั่งไปตรวจตำแหน่งใกล้ผู้เล่น คอยกดดันไม่ให้อยู่นิ่ง
func _hunt(delta: float, p: Player) -> void:
	if GameState.phase < 3 or state == State.CHASE:
		return
	hunt_t += delta
	if hunt_t > 11.0:
		hunt_t = 0.0
		if not p.is_hidden() and not p.in_safe:
			var off := Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			investigate(p.global_position + off)


# สุ่มจุดลาดตระเวนที่ห่างผู้เล่น dmin-dmax เมตรและผู้เล่นมองไม่เห็น (คืน INF ถ้าไม่เจอ)
func _pick_point_near(p: Player, dmin: float, dmax: float) -> Vector3:
	var pts := get_tree().get_nodes_in_group("ghost_patrol")
	pts.shuffle()
	for pt in pts:
		var pos: Vector3 = (pt as Node3D).global_position
		var d := pos.distance_to(p.global_position)
		if d >= dmin and d <= dmax and not p.can_see_point(pos + Vector3.UP * 1.3):
			return pos
	return Vector3.INF


# ผีเกิดใหม่ที่จุดลาดตระเวนที่ไกลที่สุดจากผู้เล่น แล้วกลับไปลาดตระเวน
func _respawn_far(p: Player) -> void:
	var pts := get_tree().get_nodes_in_group("ghost_patrol")
	var best: Node3D = null
	var best_d := -1.0
	for pt in pts:
		var d := (pt as Node3D).global_position.distance_to(p.global_position) if p else randf()
		if d > best_d:
			best_d = d
			best = pt
	if best:
		teleport(best.global_position)
	model.set_fade(1.0)
	target_hide = null
	suspicion = 0.0
	_set_state(State.PATROL)
	_next_patrol()


# ------------------------------------------------------------------ เคลื่อนที่ / แอนิเมชัน
# เดินตามเส้นทางของ navmesh ด้วยความเร็ว speed คืน true เมื่อถึงปลายทางแล้ว
func _move(speed: float, delta: float) -> bool:
	if agent.is_navigation_finished():
		_arrived = true
		return true
	var next := agent.get_next_path_position()
	var to := next - global_position
	var step := speed * delta
	if to.length() <= step:
		global_position = next
	else:
		global_position += to.normalized() * step
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() > 0.05:
		_face_dir(flat, delta, 5.0)
	return false


# หมุนตัวผีไปทาง dir อย่างนุ่มนวล (เฉพาะแนวระนาบ)
func _face_dir(dir: Vector3, delta: float, rate: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * rate, 0.0, 1.0))


# แอนิเมชันและเอฟเฟกต์: ลอยขึ้นลง, กระพริบหายวับเป็นช่วง ๆ, แสงรอบตัวสว่างขึ้นตอนไล่ล่า, เสียงฮัมดังขึ้นและสูงขึ้น
func _animate(delta: float) -> void:
	bob_t += delta
	if state != State.JUMPSCARE:
		model.position.y = 0.1 + sin(bob_t * 1.3) * 0.05
		_update_visual_fx(delta)
	# กระพริบหายวับเป็นระยะ
	flicker_t -= delta
	if flicker_t <= 0.0 and state != State.JUMPSCARE:
		flicker_t = randf_range(2.5, 7.0)
		model.visible = false
		aura.light_energy = 0.1
		get_tree().create_timer(randf_range(0.05, 0.18)).timeout.connect(func():
			if is_instance_valid(model):
				model.visible = true)
	var target_e := 1.0 if state == State.CHASE else 0.6
	aura.light_energy = lerpf(aura.light_energy, target_e * randf_range(0.8, 1.1), delta * 6.0)
	hum.volume_db = lerpf(hum.volume_db, 4.0 if state == State.CHASE else -2.0, delta * 2.0)
	hum.pitch_scale = 1.08 if state == State.CHASE else 1.0


var _glitch_burst := 0.0


# เอฟเฟกต์ภาพของผี: โดนไฟฉายส่อง (เปลี่ยนสี), glitch/ภาพซ้อนเมื่อไล่ล่าหรืออยู่ใกล้ผู้เล่น
func _update_visual_fx(delta: float) -> void:
	var p := GameState.player as Player
	var d := 99.0
	var lit := 0.0
	if p != null:
		d = global_position.distance_to(p.global_position)
		if p.flashlight_on and d < 18.0:
			var cam_fwd := -p.camera.global_transform.basis.z
			var to := (global_position + Vector3.UP * 1.1 - p.camera.global_position).normalized()
			if cam_fwd.angle_to(to) < deg_to_rad(16.0):
				lit = 1.0
	model.set_lit(lit)
	# glitch: ตอนไล่ล่า / ใกล้ผู้เล่น / สุ่มกระตุกเป็นช่วง ๆ
	_glitch_burst = maxf(_glitch_burst - delta * 3.0, 0.0)
	if randf() < delta * 0.6:
		_glitch_burst = randf_range(0.5, 1.0)
	var g := 0.0
	if state == State.CHASE:
		g = 0.45
	g = maxf(g, clampf(1.0 - d / 6.0, 0.0, 1.0) * 0.8)
	model.set_glitch(maxf(g, _glitch_burst))
	model.set_echo_strength(0.32 if state == State.CHASE else 0.14)
