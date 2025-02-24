extends Node2D

var target_width = 720.0
var target_height = 1600.0
@onready var dialogue_system = $SubViewportContainer/DialogueSystem

func _ready():
	# 设置初步窗口大小并调整视口
	_update_window_size()
	
	# 创建测试按钮
	var test_button = Button.new()
	test_button.text = "开始对话测试"
	test_button.position = Vector2(50, 50)
	test_button.custom_minimum_size = Vector2(200, 50)
	test_button.pressed.connect(_on_test_button_pressed)
	add_child(test_button)
	
	# 初始化对话系统
	if dialogue_system:
		dialogue_system.hide()  # 初始时隐藏对话系统
	else:
		print("错误：找不到对话系统节点！")

func _on_test_button_pressed():
	if dialogue_system:
		dialogue_system.show()  # 显示对话系统
		dialogue_system.start_dialogue(100)  # 从ID为99的对话开始
	else:
		print("错误：对话系统未初始化！")

#func _process(delta):
#	# 定期更新窗口大小
#	_update_window_size()

func _update_window_size():
	var screen_size = DisplayServer.screen_get_size()  # 获取窗口大小
	print("当前设备像素: ", screen_size)  # 打印窗口大小

	# 计算缩放比例
	var scale_value_x = screen_size.x / target_width
	var scale_value_y = screen_size.y / target_height
	var scale_value = min(scale_value_x, scale_value_y)
	print("当前窗口缩放比例: ", scale)

	# 调整窗口大小
	var new_size = Vector2(target_width * scale_value, target_height * scale_value)
	DisplayServer.window_set_size(new_size)  # 设置窗口大小

	# 调整视口
	_adjust_viewport(scale_value)
	

func _adjust_viewport(scale_value: float):
	# 设置缩放
	get_viewport().set_size(Vector2(target_width * scale_value, target_height * scale_value))  # 将两个值组合成 Vector2
	# 调整摄像机缩放
	var camera = get_node("Camera2D")
	if camera:  # 检查摄像机是否存在
		camera.zoom = Vector2(1, 1)  # 根据缩放因子调整摄像机的缩放
