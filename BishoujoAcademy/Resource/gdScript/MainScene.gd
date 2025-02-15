extends Node2D

var target_width = 720.0
var target_height = 1600.0

func _ready():
	# 设置初步窗口大小并调整视口
	_update_window_size()

#func _process(delta):
#	# 定期更新窗口大小
#	_update_window_size()

func _update_window_size():
	var screen_size = DisplayServer.screen_get_size()  # 获取窗口大小
	print("当前设备像素: ", screen_size)  # 打印窗口大小

	# 计算缩放比例
	var scale_x = screen_size.x / target_width
	var scale_y = screen_size.y / target_height
	var scale = min(scale_x, scale_y)
	print("当前窗口缩放比例: ", scale)

	# 调整窗口大小
	var new_size = Vector2(target_width * scale, target_height * scale)
	DisplayServer.window_set_size(new_size)  # 设置窗口大小

	# 调整视口
	_adjust_viewport(scale)
	

func _adjust_viewport(scale: float):
	# 设置缩放
	get_viewport().set_size(Vector2(target_width * scale, target_height * scale))  # 将两个值组合成 Vector2
	# 调整摄像机缩放
	var camera = get_node("Camera2D")
	if camera:  # 检查摄像机是否存在
		camera.zoom = Vector2(1, 1)  # 根据缩放因子调整摄像机的缩放
