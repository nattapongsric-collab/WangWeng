extends Node
func _ready():
	for n in ["amb_house","amb_night","ghost_lullaby","heartbeat","whisper","breath","step_wood_1"]:
		var s: AudioStreamWAV = load("res://assets/audio/%s.wav" % n)
		print(n, " loop_mode=", s.loop_mode)
	get_tree().quit()
