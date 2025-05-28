# YesOrNo.gd 完整修正版
extends Control
signal confirmed

func _ready():
	# 显式连接信号
	$TextureRect/yes.connect("pressed", self._on_yes_pressed)
	$TextureRect/no.connect("pressed", self._on_no_pressed)

func set_question(text: String, callback: Callable):
	$TextureRect/Label.text = text  
	confirmed.connect(callback)

func _on_yes_pressed():
	print("YES button pressed")  # 调试输出
	confirmed.emit()
	queue_free()

func _on_no_pressed():
	print("NO button pressed")
	queue_free()
