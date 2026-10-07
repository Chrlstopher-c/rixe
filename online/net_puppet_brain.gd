class_name NetPuppetBrain
extends RefCounted
## Cerveau vide des marionnettes en ligne : elles sont menées par les instantanés reçus, pas par des intentions.


func think(_f: Node2D, _delta: float) -> Dictionary:
	return {"move": 0.0, "jump": false, "jump_held": false, "drop": false, "dash": false, "fire": false,
		"melee": false, "aim": Vector2.ZERO}
