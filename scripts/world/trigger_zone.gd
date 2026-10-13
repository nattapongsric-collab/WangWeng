extends Area3D
class_name TriggerZone
## โซนทริกเกอร์ — ผู้เล่นเดินเข้าแล้วแจ้ง level.on_trigger(zone_id) (ครั้งเดียว)

# ตั้งค่าได้: รหัสโซน (level.gd ใช้แยกว่าเหตุการณ์อะไร), ขนาดกล่อง, เกิดครั้งเดียวไหม, ทำงานเฉพาะช่วงบท min_phase ถึง max_phase
@export var zone_id := "zone"
@export var size := Vector3(2, 2.5, 2)
@export var once := true
@export var min_phase := 0
@export var max_phase := 9


# สร้างกล่องตรวจจับ (ตรวจเฉพาะผู้เล่น) และฟังเมื่อมีอะไรเดินเข้ามา
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = Vector3(0, size.y * 0.5, 0)
	add_child(cs)
	body_entered.connect(_on_body_entered)


# เมื่อมีอะไรเดินเข้าโซน: ต้องเป็นผู้เล่น และอยู่ในช่วงบทที่กำหนด
# ถ้าตั้งให้ครั้งเดียว จะจำไว้ใน flags ว่าเกิดแล้ว (ไม่เกิดซ้ำแม้โหลดเซฟ) แล้วแจ้ง level.gd ให้ทำเหตุการณ์
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if GameState.phase < min_phase or GameState.phase > max_phase:
		return
	var key := "trig_" + zone_id
	if once and GameState.get_flag(key):
		return
	GameState.set_flag(key)
	if GameState.level and GameState.level.has_method("on_trigger"):
		GameState.level.on_trigger(zone_id)
