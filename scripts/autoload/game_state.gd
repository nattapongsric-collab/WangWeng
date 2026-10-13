extends Node
## GameState (Autoload) — เก็บสถานะเกมทั้งหมด: ไอเทม, จดหมาย, เฟสของเรื่อง, checkpoint, ค่าตั้งค่า
## ทุกระบบสื่อสารกันผ่าน signal ที่นี่ เพื่อไม่ให้สคริปต์ผูกกันแน่นเกินไป

# สัญญาณ (signal) ที่ส่งหากัน — ผู้ส่งไม่ต้องรู้ว่าใครรับ
# noise_made: มีเสียงเกิดขึ้น (ผีฟังอยู่)  inventory_changed: ไอเทมเปลี่ยน  objective_changed: ภารกิจเปลี่ยน
# subtitle: ข้อความบนจอ  phase_changed: เปลี่ยนบท  note_opened: เปิดอ่านจดหมาย  player_died: ผู้เล่นตาย
# settings_changed: ตั้งค่าเปลี่ยน  item_picked: เก็บของ  jumpscare: ผีจับผู้เล่นได้
signal noise_made(pos: Vector3, radius: float, source: String)
signal inventory_changed
signal objective_changed(text: String)
signal subtitle(text: String, duration: float)
signal phase_changed(phase: int)
signal note_opened(note_id: String)
signal player_died(reason: String)
signal settings_changed
signal item_picked(pickup_id: String, item_id: String)
signal jumpscare

# ชั้นการชน (collision layer) ของแต่ละประเภทวัตถุ: โลก ผู้เล่น ผี ประตู ของที่ผลักได้ ของที่โต้ตอบได้
const PHYS_WORLD := 1
const PHYS_PLAYER := 2
const PHYS_GHOST := 4
const PHYS_DOOR := 8
const PHYS_PROP := 16
const PHYS_INTERACT := 32

# ------------------------------------------------------------------ ข้อมูลไอเทม
# ข้อมูลไอเทมทั้งหมด (ชื่อ + คำอธิบายที่แสดงในสมุดบันทึก)
const ITEMS := {
	"flashlight": {"name": "ไฟฉาย", "desc": "ไฟฉายเก่าของยาย ส่องสว่างได้ดี แต่ถ้าเปิดนานเกินไป แสงจะดึงดูด 'เธอ' [F] เปิด/ปิด"},
	"matches": {"name": "ไม้ขีดไฟ", "desc": "ใช้จุดเทียนที่ดับอยู่ แสงเทียนช่วยให้สติกลับคืนมา"},
	"key_backdoor": {"name": "กุญแจประตูหลังบ้าน", "desc": "ลูกกุญแจทองเหลืองเก่า มีด้ายแดงผูกไว้"},
	"key_storage": {"name": "กุญแจห้องเก็บของ", "desc": "กุญแจเหล็กขึ้นสนิม ป้ายเขียนว่า 'ห้องเก็บของ ชั้นบน'"},
	"photo_piece": {"name": "เศษรูปถ่าย", "desc": "เศษรูปถ่ายครอบครัวที่ถูกฉีก ต้องรวบรวมให้ครบ 3 ชิ้น"},
	"family_photo": {"name": "รูปถ่ายครอบครัว", "desc": "รูปที่ต่อกลับมาครบแล้ว ผู้หญิงชุดขาวยืนอยู่ด้านหลังทุกคน"},
	"key_grandma": {"name": "กุญแจห้องยาย", "desc": "กุญแจดอกเล็ก ผูกด้วยสายสิญจน์"},
	"contract": {"name": "สัญญาผ้ายันต์", "desc": "ผ้าแดงลงอักขระ ห่อกระดาษเก่าที่ลงนามด้วยเลือด"},
}

# ------------------------------------------------------------------ จดหมาย / บันทึก
# ข้อมูลจดหมาย/บันทึกทั้งหมด (หัวข้อ เนื้อหา และภาพประกอบถ้ามี) ที่อ่านในเกมได้
const NOTES := {
	"letter_grandma": {
		"title": "จดหมายจากยาย",
		"body": "ข้าวฟ่าง หลานรักของยาย\n\nถ้าหลานได้อ่านจดหมายฉบับนี้ ก็แปลว่ายายไม่อยู่แล้ว\nยายรู้ว่าหลานจะกลับมาขายบ้าน ยายไม่โกรธหรอก\nแต่ก่อนจะไป ขอให้หลานจำที่ยายบอกไว้...\n\nตอนกลางคืน อย่าเดินเสียงดัง อย่าส่องไฟนาน ๆ\nถ้าได้ยินเสียงผู้หญิงครวญเพลงกล่อมเด็ก ให้หาที่ซ่อน แล้วกลั้นหายใจไว้\nอย่าอยู่ในที่มืดนานเกินไป จุดเทียนไว้ เธอไม่ชอบแสงเทียน\n\nบ้านหลังนี้มันจำได้นะลูก\nมันจำได้ ว่าใครเป็นหนี้มัน\n\nรักหลานเสมอ\nยาย",
	},
	"note_kitchen": {
		"title": "สมุดรายจ่ายของยาย",
		"body": "เดือนสิบสอง\n\nข้าวสาร ๑ ถัง .................. ๑๒๐\nธูป ๙ ดอก เทียน ๒ เล่ม ........ ๒๐\nไข่ต้ม ๒ ฟอง (ถวายแม่หญิง คืนวันพระ)\nผ้าขาว ๑ พับ (ชุดของแม่หญิงขาดอีกแล้ว)\n\n* กุญแจประตูหลังบ้าน วางไว้บนเคาน์เตอร์ข้างตู้กับข้าว\n* ศาลพระภูมิในสวน ต้องเปลี่ยนน้ำทุกเช้า\n  รูปที่ซ่อนไว้ที่ศาล ห้ามให้ใครเห็นเด็ดขาด",
	},
	"note_shrine": {
		"title": "บทขอขมา",
		"body": "(เขียนด้วยดินสอบนกระดาษสา วางไว้ใต้กระถางธูป)\n\nข้าพเจ้า ลูกหลานตระกูลเรือนทอง\nขอขมาต่อแม่หญิงผู้ไม่มีชื่อ\n\nรูปครอบครัวถูกฉีกเป็นสามชิ้น\nชิ้นหนึ่งอยู่กับพระภูมิ ชิ้นหนึ่งอยู่กับเด็ก ชิ้นหนึ่งถูกเก็บไว้กับของที่ถูกลืม\n\nหากต่อรูปได้ครบ จงวางไว้บนโต๊ะหมู่\nกุญแจห้องของยายจะถูกคืนให้",
	},
	"drawing_kid": {
		"title": "ภาพวาดของข้าวฟ่างตอนเด็ก",
		"image": "res://assets/textures/kid_drawing.png",
		"body": "(ลายมือเด็ก ตัวหนังสือโย้เย้)\n\nบ้านของหนู มียาย มีหนู มีแม่\nแล้วก็มีพี่สาวชุดขาว\n\nพี่สาวชุดขาวเล่นซ่อนหากับหนูทุกคืน\nพี่เขาบอกว่า ถ้าหนูโตแล้ว หนูต้องกลับมาหาพี่นะ\nพี่จะรอ",
	},
	"newspaper": {
		"title": "หนังสือพิมพ์เก่า พ.ศ. ๒๔๙๘",
		"body": "\"พบศพหญิงสาวสวมชุดขาว ในบ่อน้ำหลังเรือนใหญ่ตระกูลเรือนทอง\nชาวบ้านลือกันว่าเธอเป็นคนรับใช้ที่ตั้งท้องกับบุตรชายเจ้าของบ้าน\nเจ้าหน้าที่สรุปว่าเป็นอุบัติเหตุ ตกบ่อน้ำเสียชีวิต\"\n\n(ลายมือยายเขียนต่อท้าย)\nพ่อของยายเป็นคนทำ\nแล้วพ่อก็ไปทำสัญญากับหมอผี ให้ขังวิญญาณเธอไว้ในบ้านนี้\nเพื่อไม่ให้เธอไปไหนได้ ไม่ให้เธอไปฟ้องใคร\nแลกกับว่า... ลูกหลานทุกคนที่เกิดในบ้านนี้\nต้องกลับมาใช้หนี้ให้เธอ",
	},
	"family_photo": {
		"title": "รูปถ่ายครอบครัว",
		"image": "res://assets/textures/family_photo.png",
		"body": "ยาย แม่ และข้าวฟ่างตอนเด็ก ยืนอยู่หน้าบ้านหลังนี้\nด้านหลังสุด มีผู้หญิงชุดขาวผมยาวยืนอยู่ ใบหน้าของเธอถูกขูดจนเป็นรอย\n\nด้านหลังรูปเขียนไว้ว่า\n\"กุญแจห้องยาย อยู่ใต้ฐานพระ\"",
	},
	"letter_final": {
		"title": "จดหมายฉบับสุดท้ายของยาย",
		"body": "ข้าวฟ่าง...\n\nยายขอโทษที่ไม่เคยบอกความจริง\nทุกคนที่เกิดในบ้านนี้ต้องกลับมาใช้หนี้ แม่ของหลานก็เช่นกัน\nยายแบกหนี้ไว้แทนหลานมาตลอดหกสิบปี ด้วยการดูแลเธอ ถวายข้าวถวายน้ำทุกคืน\nตอนนี้ยายไม่อยู่แล้ว เธอจึงมาทวงจากหลาน\n\nสัญญาผ้ายันต์อยู่ในหีบข้างเตียง\nถ้าหลานอยากให้มันจบ จงนำสัญญาไปเผาด้วยไฟเทียนบนโต๊ะหมู่ในห้องพระ\nแล้วขอขมาเธอด้วยใจจริง\n\nแต่ถ้าหลานกลัว... ก็จงวิ่ง\nวิ่งออกประตูหน้าไปเลย และอย่ากลับมาอีก\n\nยายรักหลาน",
	},
}

# ชื่อบท 0-3 ของเรื่อง
const PHASE_NAMES := ["เงียบสงัด", "เธอตื่นแล้ว", "บ้านจำได้", "ทวงหนี้"]

# ------------------------------------------------------------------ สถานะ
# สถานะของเกมที่ต้องจำไว้ (จะถูกเก็บลงจุดเซฟ): บทปัจจุบัน ไอเทม จดหมายที่ได้ ของที่เก็บแล้ว ประตูที่ปลดล็อก เทียนที่จุด flags ภารกิจ สติ
var phase := 0
var inventory := {}
var notes: Array = []
var collected := {}
var unlocked_doors := {}
var lit_candles := {}
var flags := {}
var objective := ""
var sanity := 100.0
var ending := ""
var deaths := 0
var play_time := 0.0

# จุดเซฟล่าสุด และตัวอ้างอิงถึงผู้เล่น/ผี/ด่าน (ตั้งค่าโดยสคริปต์ของแต่ละตัวตอนเริ่ม) เพื่อให้ส่วนอื่นเรียกใช้ได้
var checkpoint := {}  # snapshot ล่าสุด
var player: Node = null  # ตั้งโดย Player
var ghost: Node = null  # ตั้งโดย Ghost
var level: Node = null  # ตั้งโดย Level

# ค่าตั้งค่า
# ค่าตั้งค่าของผู้เล่น: ความไวเมาส์ ความดังรวม กลับด้านแกน Y (บันทึกลงไฟล์ settings.cfg)
var mouse_sensitivity := 0.0025
var master_volume := 0.8
var invert_y := false

const SETTINGS_PATH := "user://settings.cfg"


# ทำงานแม้เกมหยุดชั่วคราว และโหลดค่าตั้งค่าที่บันทึกไว้
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


# นับเวลาเล่น (เฉพาะตอนอยู่ในด่านและเกมไม่หยุด)
func _process(delta: float) -> void:
	if level != null and not get_tree().paused:
		play_time += delta


# ------------------------------------------------------------------ เกมใหม่ / checkpoint
# เริ่มเกมใหม่: ล้างสถานะทั้งหมด เริ่มด้วยไฟฉายและไม้ขีด 2 อัน
func new_game() -> void:
	phase = 0
	inventory = {"matches": 2, "flashlight": 1}
	notes = []
	collected = {}
	unlocked_doors = {}
	lit_candles = {}
	flags = {}
	objective = ""
	sanity = 100.0
	ending = ""
	deaths = 0
	play_time = 0.0
	checkpoint = {}


# บันทึกจุดเซฟ: คัดลอกสถานะทั้งหมด + ตำแหน่ง/มุมมองผู้เล่น (สติอย่างน้อย 70 เพื่อไม่ให้เกิดใหม่แล้วตายซ้ำ)
func save_checkpoint(player_xform: Transform3D, player_yaw_pitch: Vector2 = Vector2.ZERO) -> void:
	checkpoint = {
		"phase": phase,
		"inventory": inventory.duplicate(true),
		"notes": notes.duplicate(),
		"collected": collected.duplicate(),
		"unlocked_doors": unlocked_doors.duplicate(),
		"lit_candles": lit_candles.duplicate(),
		"flags": flags.duplicate(true),
		"objective": objective,
		"sanity": maxf(sanity, 70.0),
		"xform": player_xform,
		"look": player_yaw_pitch,
	}


# มีจุดเซฟอยู่ไหม
func has_checkpoint() -> bool:
	return not checkpoint.is_empty()


# กู้สถานะจากจุดเซฟ
func restore_checkpoint() -> void:
	if checkpoint.is_empty():
		return
	phase = checkpoint.phase
	inventory = checkpoint.inventory.duplicate(true)
	notes = checkpoint.notes.duplicate()
	collected = checkpoint.collected.duplicate()
	unlocked_doors = checkpoint.unlocked_doors.duplicate()
	lit_candles = checkpoint.lit_candles.duplicate()
	flags = checkpoint.flags.duplicate(true)
	objective = checkpoint.objective
	sanity = checkpoint.sanity


# ตายแล้วเล่นใหม่: นับจำนวนครั้งที่ตาย กู้จุดเซฟ แล้วโหลดฉากใหม่
func retry_from_checkpoint() -> void:
	deaths += 1
	restore_checkpoint()
	get_tree().paused = false
	get_tree().reload_current_scene()


# ------------------------------------------------------------------ ไอเทม
# จัดการไอเทม: มีไหม / มีกี่ชิ้น / เพิ่ม / ลบ / เพิ่มจดหมาย / ชื่อไอเทม (ทุกครั้งที่เปลี่ยนจะส่งสัญญาณ inventory_changed)
func has_item(id: String, count: int = 1) -> bool:
	return int(inventory.get(id, 0)) >= count


func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, amount: int = 1) -> void:
	inventory[id] = item_count(id) + amount
	inventory_changed.emit()


func remove_item(id: String, amount: int = 1) -> void:
	var c := item_count(id) - amount
	if c <= 0:
		inventory.erase(id)
	else:
		inventory[id] = c
	inventory_changed.emit()


func add_note(id: String) -> void:
	if not notes.has(id):
		notes.append(id)
	inventory_changed.emit()


func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


# ------------------------------------------------------------------ flags / เรื่อง
# flags: ธงสำหรับจำเหตุการณ์ในเรื่อง เช่น วางรูปแล้ว ประตูหน้าปลดล็อกแล้ว
func set_flag(id: String, value: Variant = true) -> void:
	flags[id] = value


func get_flag(id: String, default: Variant = false) -> Variant:
	return flags.get(id, default)


# ตั้งภารกิจที่แสดงมุมจอ
func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


# แสดงข้อความ (คำบรรยาย) บนจอ duration วินาที
func say(text: String, duration: float = 3.5) -> void:
	subtitle.emit(text, duration)


# เลื่อนบท (เลื่อนไปข้างหน้าได้อย่างเดียว) แล้วส่งสัญญาณให้ด่านเปลี่ยนบ้าน
func advance_phase(p: int) -> void:
	if p <= phase:
		return
	phase = p
	phase_changed.emit(p)


# ส่งเสียงที่ตำแหน่ง pos รัศมี radius เมตร — ผีที่อยู่ในรัศมีจะได้ยินและมาตรวจ (source ระบุชนิด เช่น footstep, breath)
func make_noise(pos: Vector3, radius: float, source: String = "") -> void:
	if radius <= 0.0:
		return
	noise_made.emit(pos, radius, source)


# ------------------------------------------------------------------ settings
# โหลด/บันทึก/ใช้ค่าตั้งค่า (ความไวเมาส์ ความดัง) จากไฟล์ user://settings.cfg
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		mouse_sensitivity = cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)
		invert_y = cfg.get_value("input", "invert_y", invert_y)
		master_volume = cfg.get_value("audio", "master_volume", master_volume)
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	settings_changed.emit()
