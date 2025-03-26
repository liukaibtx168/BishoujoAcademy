extends CanvasLayer

@onready var dialogue_system = $DialogueSystem

func start_dialogue(dialogue_id: int):
	dialogue_system.start_dialogue(dialogue_id) 
