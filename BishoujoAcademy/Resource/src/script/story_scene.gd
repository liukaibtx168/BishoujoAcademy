extends Node2D

# 添加一个变量来跟踪状态
var is_expanded = false
var expanded_height = 1150
var collapsed_height = 330

# 添加历史记录行数限制
var max_collapsed_lines = 9
var max_expanded_lines = 300
var full_history_text = ""  # 存储完整的历史记录

func _ready():
	# 查找节点，使用更灵活的方式
	var button_collapse = find_child("Button_collapse", true, false)
	var history_panel = find_child("History", true, false)
	var history_text = find_child("History_text", true, false)
	
	# 保存完整历史记录
	full_history_text = history_text.text
	
	# 确保按钮连接到切换函数
	button_collapse.pressed.connect(_on_button_collapse_pressed)
	
	# 初始状态设置为折叠
	_update_history_panel_size(history_panel, false)
	_update_history_text(history_text, false)
	print("StoryScene: 初始化完成")

func _on_button_collapse_pressed():
	# 获取节点引用
	var button_collapse = find_child("Button_collapse", true, false)
	var history_panel = find_child("History", true, false)
	var history_text = find_child("History_text", true, false)
	
	if not button_collapse or not history_panel or not history_text:
		return
	
	# 切换展开/折叠状态
	is_expanded = !is_expanded
	
	# 更新历史面板大小
	_update_history_panel_size(history_panel, is_expanded)
	
	# 更新历史文本内容
	_update_history_text(history_text, is_expanded)
	
	print("StoryScene: 切换状态为 ", "展开" if is_expanded else "折叠")

func _update_history_panel_size(panel, expanded: bool):
	if panel:
		var new_height = expanded_height if expanded else collapsed_height
		
		# 只更改高度，保持宽度不变
		panel.size.y = new_height
		print("StoryScene: 更新历史面板高度为 ", new_height)

# 新增：根据展开/折叠状态更新历史文本
func _update_history_text(text_label, expanded: bool):
	if text_label:
		var max_lines = max_expanded_lines if expanded else max_collapsed_lines
		var lines = full_history_text.split("\n")
		
		# 如果行数超过限制，只显示指定数量的行
		if lines.size() > max_lines:
			var limited_text = ""
			for i in range(max_lines):
				limited_text += lines[i] + "\n"
			text_label.text = limited_text.strip_edges()
		else:
			# 如果行数未超过限制，显示全部
			text_label.text = full_history_text
		
		print("StoryScene: 更新历史文本，显示 ", max_lines, " 行")

# 添加一个公共方法，用于添加新的历史记录
func add_history_entry(entry: String):
	# 获取历史文本节点
	var history_text = find_child("History_text", true, false)
	if not history_text:
		return
	
	# 添加新条目到完整历史记录
	full_history_text += entry + "\n"
	
	# 更新显示
	_update_history_text(history_text, is_expanded)
