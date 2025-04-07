extends Node2D

# 添加一个变量来跟踪状态
var is_expanded = false
var expanded_height = 1150
var collapsed_height = 330

# 添加历史记录行数限制
var max_collapsed_lines = 9
var max_expanded_lines = 300
var full_history_text = ""  # 存储完整的历史记录

# 添加地图相关变量
var current_world_id = 101  # 设置默认worldID为101
var story_map_data = {}     # 存储地图数据
var map_events_data = {}    # 存储事件数据
var string_data = {}        # 存储字符串数据

# 添加坐标显示相关变量
var mouse_position = Vector2.ZERO  # 当前鼠标位置

func _ready():
	print("游戏启动，开始初始化流程...")
	
	# 1. 首先加载所有配置数据
	load_config_data()
	print("配置数据加载完成")
	
	# 2. 加载基础模板信息
	load_template_scenes()
	print("模板场景加载完成")
	
	# 3. 根据配置和模板创建实际游戏内容
	initialize_map_with_world_id(current_world_id)
	print("地图和事件初始化完成")
	
	# UI初始化
	initialize_coords_label()
	setup_history_panel()
	
	print("游戏初始化完成")

# 加载所有配置数据
func load_config_data():
	print("开始加载配置数据...")
	
	# 加载StoryMap配置
	var story_map_path = "res://Resource/src/excleToJson/StoryMap.json"
	var story_map_file = FileAccess.open(story_map_path, FileAccess.READ)
	if story_map_file:
		var json_string = story_map_file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			story_map_data = json.data
			print("成功加载StoryMap配置，共 ", story_map_data.size(), " 条数据")
		else:
			print("解析StoryMap.json失败: ", json.get_error_message(), " at line ", json.get_error_line())
	else:
		print("无法打开StoryMap配置文件: ", story_map_path)
	
	# 加载MapEvent配置
	var map_events_path = "res://Resource/src/excleToJson/MapEvent.json"
	var map_events_file = FileAccess.open(map_events_path, FileAccess.READ)
	if map_events_file:
		var json_string = map_events_file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			map_events_data = json.data
			print("成功加载MapEvent配置，共 ", map_events_data.size(), " 条数据")
		else:
			print("解析MapEvent.json失败: ", json.get_error_message(), " at line ", json.get_error_line())
	else:
		print("无法打开MapEvent配置文件: ", map_events_path)
	
	# 加载String_cn配置
	var string_data_path = "res://Resource/src/lang/String_cn.csv"
	var string_file = FileAccess.open(string_data_path, FileAccess.READ)
	if string_file:
		# 跳过表头行
		string_file.get_line()
		string_file.get_line()
		string_file.get_line()
		
		# 清空现有的字符串数据
		string_data.clear()
		var loaded_count = 0
		
		# 读取数据行
		while !string_file.eof_reached():
			var line = string_file.get_line()
			if line.strip_edges() == "":
				continue
				
			var parts = line.split("\t")
			if parts.size() >= 3:
				# 尝试将ID转换为整数，以便于后续检索
				var id = parts[0].strip_edges()
				var id_int = id.to_int()
				var text = parts[2].strip_edges()
				
				# 同时以字符串和整数形式存储，增加查找成功率
				string_data[id] = text  # 字符串形式
				string_data[id_int] = text  # 整数形式
				loaded_count += 1
				
				# 调试输出
				if id == "10004" || id_int == 10004:
					print("DEBUG: 成功加载字符串ID=10004，内容: ", text)
					print("  - 类型检查: id类型=", typeof(id), ", id_int类型=", typeof(id_int))
		
		print("成功加载String_cn配置，共 ", loaded_count, " 条数据，字典大小: ", string_data.size())
		print("DEBUG: 字符串表中包含ID=10004吗? ", string_data.has("10004") || string_data.has(10004))
	else:
		print("无法打开String_cn配置文件: ", string_data_path)

# 加载基础模板场景
func load_template_scenes():
	print("开始加载基础模板场景...")
	
	# 1. 获取StoryMap节点
	var story_map_node = get_node_or_null("StoryMap")
	if !story_map_node:
		print("错误: 场景中找不到StoryMap节点")
		return
	
	# 2. 获取test_map_001节点和它的MapImage
	var map_node = story_map_node.get_node_or_null("test_map_001")
	if !map_node:
		print("错误: StoryMap中找不到test_map_001节点")
		return
	
	var map_image = map_node.get_node_or_null("MapImage")
	if !map_image:
		print("错误: test_map_001中找不到MapImage节点")
		return
		
	# 3. 获取或创建EventLayer
	var event_layer = map_image.get_node_or_null("EventLayer")
	if !event_layer:
		print("警告: 找不到EventLayer，创建新的EventLayer")
		event_layer = Node2D.new()
		event_layer.name = "EventLayer"
		map_image.add_child(event_layer)
	
	# 4. 加载事件模板
	print("检查事件模板...")
	
	# 检查是否需要加载事件模板
	var has_templates = false
	var template_names = ["Event_Choice", "Event_Scene", "Event_Shop", "Event_Battle", "Event_Dungeon"]
	
	for template_name in template_names:
		if event_layer.has_node(template_name):
			has_templates = true
			break
	
	# 如果没有模板，尝试从map_event.tscn加载
	if !has_templates:
		print("未找到事件模板，尝试从map_event.tscn加载...")
		var template_scene_path = "res://Resource/src/tscn/map_event.tscn"
		
		if ResourceLoader.exists(template_scene_path):
			var template_scene = load(template_scene_path)
			if template_scene:
				# 直接实例化整个场景作为模板
				var template_instance = template_scene.instantiate()
				
				# 作为临时节点添加到事件层以获取其子节点
				event_layer.add_child(template_instance)
				
				# 检查和处理所有模板节点
				for template_name in template_names:
					var template_node = template_instance.get_node_or_null(template_name)
					if template_node:
						# 直接复制整个模板节点，保留所有属性和子节点
						var node_copy = template_node.duplicate()
						event_layer.add_child(node_copy)
						
						# 只修改其可见性属性
						node_copy.visible = false
						
						print("已加载事件模板: ", template_name)
					else:
						print("警告: 在模板场景中找不到 ", template_name)
				
				# 移除临时实例
				template_instance.queue_free()
				
				print("完成事件模板加载")
			else:
				print("错误: 无法加载事件模板场景")
		else:
			print("错误: 找不到事件模板场景文件: ", template_scene_path)
	
	# 检查模板是否正确加载
	var missing_templates = []
	
	for template_name in template_names:
		var template_node = event_layer.get_node_or_null(template_name)
		if !template_node:
			missing_templates.append(template_name)
		else:
			# 只确保模板不可见，不修改其他属性
			template_node.visible = false
			
			# 检查关键子节点是否存在
			if template_node.get_node_or_null("build_di"):
				print("模板 ", template_name, " 包含build_di节点")
			else:
				print("警告: 模板 ", template_name, " 缺少build_di节点")
				
			if template_node.get_node_or_null("CollisionShape2D"):
				print("模板 ", template_name, " 包含CollisionShape2D节点")
			else:
				print("警告: 模板 ", template_name, " 缺少CollisionShape2D节点")
	
	if missing_templates.size() > 0:
		print("警告: 以下事件模板缺失: ", missing_templates)
	else:
		print("所有事件模板已找到并设置为不可见")

# 根据worldID初始化地图
func initialize_map_with_world_id(world_id):
	print("初始化worldID为 ", world_id, " 的地图...")
	
	# 找到对应世界ID的起始地图
	var start_map_id = ""
	var start_map_data = null
	
	for map_id in story_map_data:
		var map_data = story_map_data[map_id]
		if map_data.worldID == world_id && map_data.startMap == 1:
			start_map_id = map_id
			start_map_data = map_data
			break
	
	if start_map_data == null:
		print("错误: 找不到worldID为 ", world_id, " 的起始地图")
		return
	
	print("找到起始地图: ", start_map_id, " - ", start_map_data.comment)
	
	# 获取StoryMap节点
	var story_map_node = get_node_or_null("StoryMap")
	if !story_map_node:
		print("错误: 场景中找不到StoryMap节点")
		return
	
	# 获取test_map_001节点和它的MapImage
	var map_node = story_map_node.get_node_or_null("test_map_001")
	if !map_node:
		print("错误: StoryMap中找不到test_map_001节点")
		return
	
	var map_image = map_node.get_node_or_null("MapImage")
	if !map_image:
		print("错误: test_map_001中找不到MapImage节点")
		return
	
	# 验证事件模板是否存在
	if !check_event_templates(map_image):
		print("错误: 事件模板验证失败，无法初始化地图")
		return
	
	# 加载地图图片
	var map_image_path = "res://Resource/res/" + start_map_data.mapImage
	var texture = load(map_image_path)
	if texture:
		map_image.texture = texture
		print("成功加载地图图片: ", map_image_path)
		
		# 重要：首先加载事件，这样迷雾生成可以基于事件信息
		load_map_events(start_map_id, map_node)
		
		# 然后设置迷雾层
		setup_fog_layer(map_node, start_map_data)
		
		# 最后通知story_map节点更新地图（其中可能包含额外的处理）
		if story_map_node.has_method("initialize_existing_maps"):
			story_map_node.initialize_existing_maps()
			print("已通知story_map重新初始化地图")
	else:
		print("错误: 无法加载地图图片 ", map_image_path)

# 检查事件模板是否存在和完整
func check_event_templates(map_image):
	var event_layer = map_image.get_node_or_null("EventLayer")
	if !event_layer:
		print("错误: 找不到EventLayer节点，无法验证事件模板")
		return false
	
	print("验证事件模板...")
	
	# 检查模板是否存在
	var template_names = ["Event_Choice", "Event_Scene", "Event_Shop", "Event_Battle", "Event_Dungeon"]
	var missing_templates = []
	
	for template_name in template_names:
		var template_node = event_layer.get_node_or_null(template_name)
		if !template_node:
			missing_templates.append(template_name)
	
	if missing_templates.size() > 0:
		print("错误: 以下事件模板缺失: ", missing_templates)
		return false
	
	print("事件模板验证通过")
	return true

# 设置迷雾层
func setup_fog_layer(map_node, map_data):
	var map_image = map_node.get_node_or_null("MapImage")
	if !map_image:
		print("错误: 找不到MapImage节点")
		return
		
	var fog_layer = map_image.get_node_or_null("FogLayer")
	if !fog_layer:
		print("错误: 找不到FogLayer节点")
		return
	
	# 根据地图配置设置迷雾层可见性
	fog_layer.visible = map_data.fogLayer == 1
	print("设置迷雾层可见性: ", fog_layer.visible)
	
	# 更新迷雾遮罩
	var story_map = get_node_or_null("StoryMap")
	if story_map && story_map.has_method("reveal_event_areas"):
		story_map.reveal_event_areas(map_node.name)
		print("已更新迷雾遮罩")

# 加载指定地图的事件
func load_map_events(map_id, map_node):
	print("加载地图 ", map_id, " 的事件...")
	
	# 获取MapImage和EventLayer
	var map_image = map_node.get_node_or_null("MapImage")
	if !map_image:
		print("错误: 找不到MapImage节点")
		return
		
	var event_layer = map_image.get_node_or_null("EventLayer")
	if !event_layer:
		print("错误: 找不到EventLayer节点")
		return
	
	# 确保事件模板是隐藏的
	hide_event_templates(event_layer)
	
	# 清除现有事件 (保留原始模板节点)
	for child in event_layer.get_children():
		if child.name.begins_with("Event_") && !is_event_template(child.name):
			child.queue_free()
	
	# 根据配置加载事件
	var event_count = 0
	for event_id in map_events_data:
		var event_data = map_events_data[event_id]
		if str(event_data.storyMapID) == str(map_id):
			var new_event = create_map_event(event_data, event_layer)
			if new_event:
				event_count += 1
	
	print("地图事件加载完成，共创建 ", event_count, " 个事件")
	
	# 事件加载完成后，刷新迷雾遮罩以反映新的事件位置
	var story_map = get_node_or_null("StoryMap")
	if story_map && story_map.has_method("reveal_event_areas"):
		# 等待一帧确保所有事件都已完全创建
		await get_tree().process_frame
		story_map.reveal_event_areas(map_id)
		print("已刷新地图 ", map_id, " 的迷雾遮罩")

# 判断节点是否为事件模板
func is_event_template(node_name: String) -> bool:
	var template_names = ["Event_Choice", "Event_Scene", "Event_Shop", "Event_Battle", "Event_Dungeon"]
	return template_names.has(node_name)

# 隐藏事件模板节点 - 简化版
func hide_event_templates(event_layer: Node):
	var template_names = ["Event_Choice", "Event_Scene", "Event_Shop", "Event_Battle", "Event_Dungeon"]
	
	for template_name in template_names:
		var template_node = event_layer.get_node_or_null(template_name)
		if template_node:
			template_node.visible = false

# 创建地图事件
func create_map_event(event_data, event_layer):
	# 获取事件类型和位置
	var event_type = event_data.eventType
	
	# 直接从配置中读取事件位置坐标
	var event_pos_x = float(event_data.eventPos["[1]"])
	var event_pos_y = float(event_data.eventPos["[2]"])
	
	# 找到事件模板
	var event_template = event_layer.get_node_or_null(event_type)
	if !event_template:
		print("错误: 找不到事件模板 ", event_type)
		return null
	
	# 复制事件模板（保留所有原始属性）
	var new_event = event_template.duplicate()
	new_event.name = "Event_" + str(event_data.ID)
	
	# 确保事件可见
	new_event.visible = true
	
	# 添加到场景树
	event_layer.add_child(new_event)
	
	# 设置事件位置 - 直接使用配置中的坐标
	new_event.position = Vector2(event_pos_x, event_pos_y)
	
	# 调整碰撞形状大小 - 使用配置中的lightRange字段
	var collision_shape = new_event.get_node_or_null("CollisionShape2D")
	if collision_shape:
		if event_data.has("lightRange"):
			# 确保lightRange存在且不为空
			var light_range_value = str(event_data.lightRange)
			if light_range_value != "" && light_range_value != "0":
				# 转换为浮点数
				var light_range = float(light_range_value)
				if light_range > 0:
					# 获取当前形状
					var shape = collision_shape.shape
					if shape is CircleShape2D:
						# 如果是圆形，设置半径
						shape.radius = light_range
						print("设置事件 ", event_data.ID, " 的碰撞半径为: ", light_range)
					elif shape is RectangleShape2D:
						# 如果是矩形，设置大小为正方形
						shape.size = Vector2(light_range * 2, light_range * 2)
						print("设置事件 ", event_data.ID, " 的碰撞大小为: ", shape.size)
					
					# 添加调试信息
					print("事件 ", event_data.ID, " (类型: ", event_type, ") 创建成功")
					print("- 位置: ", new_event.position)
					print("- 全局位置: ", new_event.global_position)
					print("- 碰撞形状: ", "圆形" if shape is CircleShape2D else "矩形")
					print("- 碰撞大小: ", shape.radius if shape is CircleShape2D else shape.size)
	
	# 从配置中读取事件显示信息并应用
	update_event_display(new_event, event_data)
	
	# 标记事件的ID，方便后续引用
	new_event.set_meta("event_id", str(event_data.ID))
	new_event.set_meta("event_type", event_type)
	
	# 连接基本事件信号
	if !new_event.is_connected("input_event", _on_event_input.bind(new_event)):
		new_event.connect("input_event", _on_event_input.bind(new_event))
	
	if !new_event.is_connected("mouse_entered", _on_event_mouse_entered.bind(new_event)):
		new_event.connect("mouse_entered", _on_event_mouse_entered.bind(new_event))
	
	if !new_event.is_connected("mouse_exited", _on_event_mouse_exited.bind(new_event)):
		new_event.connect("mouse_exited", _on_event_mouse_exited.bind(new_event))
	
	print("创建事件: ", event_data.ID, " 类型: ", event_type, " 位置: (", event_pos_x, ",", event_pos_y, ")")
	return new_event

# 更新事件的显示信息（文本和图标）
func update_event_display(event_node, event_data):
	# 查找事件中的build_di节点（通常包含显示元素）
	var build_di = event_node.get_node_or_null("build_di")
	if !build_di:
		print("警告: 事件 ", event_data.ID, " 中没有找到build_di节点")
		return
	
	# 获取事件类型
	var event_type = event_data.eventType
	
	# 处理文本显示 - 按照配置表说明2处理文本
	# 只有Event_Choice和Event_Scene需要处理文本
	if event_type == "Event_Choice" || event_type == "Event_Scene":
		# 按照配置表规则，使用nameID查找string数据
		if event_data.has("nameID") && event_data.nameID != 0:
			# 获取nameID，确保我们有多种格式以增加查找成功率
			var name_id_raw = event_data.nameID  # 原始格式
			var name_id_int = int(str(name_id_raw))  # 确保是整数
			var name_id_str = str(name_id_raw)  # 确保是字符串
			
			print("DEBUG: 事件 ", event_data.ID, " nameID处理: 原始=", name_id_raw, 
				" (类型=", typeof(name_id_raw), "), 整数=", name_id_int, 
				", 字符串=", name_id_str)
			
			# 使用多种可能的键格式查找文本
			var text = null
			if string_data.has(name_id_raw):
				text = string_data[name_id_raw]
				print("DEBUG: 使用原始格式找到文本")
			elif string_data.has(name_id_int):
				text = string_data[name_id_int]
				print("DEBUG: 使用整数格式找到文本")
			elif string_data.has(name_id_str):
				text = string_data[name_id_str]
				print("DEBUG: 使用字符串格式找到文本")
			
			if text != null:
				build_di.set_text(text)
				print("设置事件 ", event_data.ID, " 文本为: ", text)
			else:
				print("警告: 事件 ", event_data.ID, " 的nameID(", name_id_raw, ")在string表中不存在")
				print("DEBUG: 字符串表中包含键: ", string_data.keys().slice(0, min(10, string_data.size())), "...")
		else:
			# nameID不存在或为0时不进行处理
			print("信息: 事件 ", event_data.ID, " 没有配置nameID或nameID为0，不设置文本")
	
	# 处理图标显示 - 按照配置表说明2处理图标
	# 5种类型事件都需要处理图标
	if event_type == "Event_Choice" || event_type == "Event_Scene" || event_type == "Event_Shop" || event_type == "Event_Battle" || event_type == "Event_Dungeon":
		# 按照配置表规则，icon字段指定了图标路径
		if event_data.has("icon") && event_data.icon != "":
			var icon_path = "res://Resource/res/" + event_data.icon
			if ResourceLoader.exists(icon_path):
				var texture = load(icon_path)
				if texture:
					# 直接设置Button的图标
					build_di.set_button_icon(texture)
				else:
					print("警告: 事件 ", event_data.ID, " 无法加载图标纹理: ", icon_path)
			else:
				print("警告: 事件 ", event_data.ID, " 图标文件不存在: ", icon_path)
		# 如果没有配置icon字段，保留默认图标，不做任何处理
	else:
		print("警告: 事件 ", event_data.ID, " 的事件类型不支持图标: ", event_type)

# 事件鼠标进入
func _on_event_mouse_entered(event):
	# 获取事件ID和类型
	var event_id = event.get_meta("event_id") if event.has_meta("event_id") else "unknown"
	var event_type = event.get_meta("event_type") if event.has_meta("event_type") else "unknown"
	
	print("鼠标进入事件: ID=", event_id, " 类型=", event_type)

# 事件鼠标离开
func _on_event_mouse_exited(event):
	# 获取事件ID和类型
	var event_id = event.get_meta("event_id") if event.has_meta("event_id") else "unknown"
	var event_type = event.get_meta("event_type") if event.has_meta("event_type") else "unknown"
	
	print("鼠标离开事件: ID=", event_id, " 类型=", event_type)

# 事件交互处理 
func _on_event_input(viewport, input_event, shape_idx, event):
	if input_event is InputEventMouseButton && input_event.pressed && input_event.button_index == MOUSE_BUTTON_LEFT:
		# 获取事件ID和类型
		var event_id = event.get_meta("event_id") if event.has_meta("event_id") else "unknown"
		var event_type = event.get_meta("event_type") if event.has_meta("event_type") else "unknown"
		
		# 打印点击信息
		print("点击了事件: ID=", event_id, " 类型=", event_type)
		add_history_entry("点击了事件: " + event_type + " (ID: " + event_id + ")")
		
		# 基本事件响应
		match event_type:
			"Event_Scene":
				# 切换场景
				print("准备切换场景")
				var target_map_id = find_target_map_id(event_id)
				if target_map_id:
					switch_to_map(target_map_id)
			_:
				print("触发事件: ", event_type)

# 根据事件ID查找目标地图ID
func find_target_map_id(event_id):
	# 这里可以定义各事件对应的目标地图
	# 示例：使用简单的映射或从配置中读取
	var event_to_map = {
		"1010002": "10102",  # 例如：事件1010002跳转到地图10102（工厂）
		"1010006": "10103"   # 例如：事件1010006跳转到地图10103（实验室）
	}
	
	if event_to_map.has(event_id):
		return event_to_map[event_id]
	
	# 如果没有找到映射，则可以使用其他逻辑
	# 例如，从事件ID推断地图ID，或返回默认地图
	print("警告: 未找到事件 ", event_id, " 的目标地图ID")
	return null

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
	
	# print("StoryScene: 切换状态为 ", "展开" if is_expanded else "折叠")

func _update_history_panel_size(panel, expanded: bool):
	if panel:
		var new_height = expanded_height if expanded else collapsed_height
		
		# 只更改高度，保持宽度不变
		panel.size.y = new_height
		# print("StoryScene: 更新历史面板高度为 ", new_height)

# 根据展开/折叠状态更新历史文本
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
		
		# print("StoryScene: 更新历史文本，显示 ", max_lines, " 行")

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

# 切换到指定的地图
func switch_to_map(map_id):
	print("切换到地图 ", map_id)
	
	# 查找地图数据
	if !story_map_data.has(str(map_id)):
		print("错误: 找不到地图ID ", map_id)
		return
		
	var map_data = story_map_data[str(map_id)]
	
	# 获取StoryMap节点
	var story_map_node = get_node_or_null("StoryMap")
	if !story_map_node:
		print("错误: 场景中找不到StoryMap节点")
		return
	
	# 获取test_map_001节点和它的MapImage
	var map_node = story_map_node.get_node_or_null("test_map_001")
	if !map_node:
		print("错误: StoryMap中找不到test_map_001节点")
		return
	
	var map_image = map_node.get_node_or_null("MapImage")
	if !map_image:
		print("错误: test_map_001中找不到MapImage节点")
		return
	
	# 验证事件模板是否存在
	if !check_event_templates(map_image):
		print("错误: 事件模板验证失败，无法切换地图")
		return
	
	# 加载地图图片
	var map_image_path = "res://Resource/res/" + map_data.mapImage
	var texture = load(map_image_path)
	if texture:
		map_image.texture = texture
		print("成功切换地图图片: ", map_image_path)
		
		# 重要：首先加载事件，这样迷雾生成可以基于事件信息
		load_map_events(map_id, map_node)
		
		# 然后设置迷雾层
		setup_fog_layer(map_node, map_data)
		
		# 添加历史记录
		add_history_entry("进入地图: " + map_data.comment)
	else:
		print("错误: 无法加载地图图片 ", map_image_path)

# 更新事件后刷新迷雾
func refresh_fog_after_event_change(map_id):
	# 在事件变化后调用此方法刷新迷雾
	print("事件变更，刷新地图 ", map_id, " 的迷雾...")
	
	# 获取地图节点
	var story_map_node = get_node_or_null("StoryMap")
	if !story_map_node:
		print("错误: 场景中找不到StoryMap节点")
		return
		
	var map_node = story_map_node.get_node_or_null("test_map_001")
	if !map_node:
		print("错误: StoryMap中找不到test_map_001节点")
		return
		
	# 获取地图数据
	if !story_map_data.has(str(map_id)):
		print("错误: 找不到地图ID ", map_id)
		return
		
	var map_data = story_map_data[str(map_id)]
	
	# 重要：为了确保迷雾正确反映事件的位置，我们需要先刷新事件
	# 这会使用配置表中的坐标创建事件，然后再根据这些事件生成迷雾
	load_map_events(map_id, map_node)
	
	# 然后刷新迷雾
	setup_fog_layer(map_node, map_data)

# 重写_process函数以更新鼠标位置
func _process(delta):
	# 获取鼠标在视窗中的位置（这将直接使用以左上角为原点的坐标系）
	var viewport_mouse_position = get_viewport().get_mouse_position()
	
	# 更新鼠标位置，四舍五入为整数
	mouse_position = Vector2(
		round(viewport_mouse_position.x),
		round(viewport_mouse_position.y)
	)
	
	# 使用现有的CanvasLayer/Label节点
	var canvas_layer = get_node_or_null("CanvasLayer")
	if canvas_layer:
		var coords_label = canvas_layer.get_node_or_null("Label")
		if coords_label:
			# 确保标签可见
			coords_label.visible = true
			
			# 更新标签文本
			coords_label.text = "X=%d Y=%d" % [mouse_position.x, mouse_position.y]
		# else:
		# 	if Engine.get_frames_drawn() < 10:  # 仅在前几帧打印警告
		# 		print("警告: 未找到story_scene/CanvasLayer/Label节点")
	# else:
	# 	if Engine.get_frames_drawn() < 10:  # 仅在前几帧打印警告
	# 		print("警告: 未找到story_scene/CanvasLayer节点")

# 初始化坐标显示标签
func initialize_coords_label():
	# print("初始化坐标显示标签...")
	var canvas_layer = get_node_or_null("CanvasLayer")
	if canvas_layer:
		var coords_label = canvas_layer.get_node_or_null("Label")
		if coords_label:
			# 确保标签可见并设置初始样式
			coords_label.visible = true
			coords_label.text = "X=0 Y=0"  # 初始坐标
			
			# print("坐标标签初始化完成")
		# else:
		# 	print("警告: 未找到story_scene/CanvasLayer/Label节点")
	# else:
	# 	print("警告: 未找到story_scene/CanvasLayer节点")

# 设置历史记录面板
func setup_history_panel():
	# 查找节点，使用更灵活的方式
	var button_collapse = find_child("Button_collapse", true, false)
	var history_panel = find_child("History", true, false)
	var history_text = find_child("History_text", true, false)
	
	# 保存完整历史记录
	if history_text:
		full_history_text = history_text.text
	
	# 确保按钮连接到切换函数
	if button_collapse:
		button_collapse.pressed.connect(_on_button_collapse_pressed)
	
	# 初始状态设置为折叠
	if history_panel and history_text:
		_update_history_panel_size(history_panel, false)
		_update_history_text(history_text, false)
	
	print("历史记录面板初始化完成")
