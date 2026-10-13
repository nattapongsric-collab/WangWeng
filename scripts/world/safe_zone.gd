extends Node3D
class_name SafeZone
## พื้นที่ปลอดภัย (ห้องพระ) — ผีเข้ามาไม่ได้ ตราบใดที่เทียนบนโต๊ะหมู่ยังติดอยู่

# ขนาดกล่องของเขตปลอดภัย (กว้าง x สูง x ลึก เมตร) วางครอบห้องพระ
@export var size := Vector3(6.6, 3.0, 4.6)


# ลงทะเบียนในกลุ่ม safe_zone (ผู้เล่นและผีค้นหาโซนนี้ตอนตรวจ)
func _ready() -> void:
	add_to_group("safe_zone")


# ตำแหน่ง pos อยู่ในเขตปลอดภัยไหม — ต้องอยู่ในกล่อง และมีเทียนบนโต๊ะหมู่ติดอยู่อย่างน้อยหนึ่งเล่ม
# (เทียนดับ = ห้องพระไม่ปลอดภัยอีกต่อไป ผีเข้าได้)
func contains(pos: Vector3) -> bool:
	var l := to_local(pos)
	if absf(l.x) > size.x * 0.5 or absf(l.z) > size.z * 0.5 or l.y < -0.5 or l.y > size.y:
		return false
	for c in get_tree().get_nodes_in_group("shrine_candle"):
		if c.lit:
			return true
	return false
