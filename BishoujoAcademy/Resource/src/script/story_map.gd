extends Node2D

# 地图数据结构
class MapData:
	var id: String
	var name: String
	var image_path: String
	var events: Array
	var fog_enabled: bool = true
	
	func _init(p_id: String, p_name: String, p_image_path: String, p_events: Array = [], p_fog_enabled: bool = true):
		id = p_id
		name = p_name
		image_path = p_image_path
		events = p_events
		fog_enabled = p_fog_enabled

# 存储所有地图数据的字典
var maps_data = {}
# 当前激活的地图ID
var current_map_id: String = ""

# 存储形状类型信息的字典
var shape_types = {}

func _ready():
	# 初始化场景中已有的地图节点
	initialize_existing_maps()
	
	# 自动揭示事件区域
	if current_map_id != "":
		reveal_event_areas(current_map_id)

# 初始化场景中已有的地图节点
func initialize_existing_maps():
	# 查找所有直接子节点，假设它们都是地图节点
	for child in get_children():
		if child is Node2D:
			var map_id = child.name
			print("找到地图节点: ", map_id)
			
			# 获取地图图像
			var map_image = child.get_node_or_null("MapImage")
			if not map_image:
				print("警告: 地图节点 ", map_id, " 没有 MapImage 子节点")
				continue
				
			var image_path = ""
			if map_image.texture:
				image_path = map_image.texture.resource_path
			
			# 创建地图数据
			var map_data = MapData.new(
				map_id,
				map_id,  # 使用节点名称作为地图名称
				image_path,
				[],
				true
			)
			
			# 存储地图数据
			maps_data[map_id] = map_data
			
			# 确保有事件层
			var event_layer = map_image.get_node_or_null("EventLayer")
			if not event_layer:
				event_layer = Node2D.new()
				event_layer.name = "EventLayer"
				map_image.add_child(event_layer)
			else:
				# 收集已有的事件ID
				for event in event_layer.get_children():
					if event is Area2D:
						var event_id = event.name.replace("Event_", "")
						map_data.events.append(event_id)
						print("找到事件: ", event_id)
			
			# 确保有迷雾层
			var fog_layer = map_image.get_node_or_null("FogLayer")
			if not fog_layer:
				print("警告: 地图节点 ", map_id, " 没有 FogLayer 子节点")
			
			# 设置当前地图ID（使用第一个找到的地图）
			if current_map_id == "":
				current_map_id = map_id
				print("设置当前地图为: ", current_map_id)

# 添加事件触发点
func add_event(map_id: String, event_id: String, position: Vector2, size: Vector2, callback: Callable):
	var map_node = get_node_or_null(map_id)
	if not map_node:
		print("错误: 找不到地图节点 ", map_id)
		return
		
	var map_image = map_node.get_node_or_null("MapImage")
	if not map_image:
		print("错误: 地图节点 ", map_id, " 没有 MapImage 子节点")
		return
		
	var event_layer = map_image.get_node_or_null("EventLayer")
	if not event_layer:
		print("错误: 地图节点 ", map_id, " 没有 EventLayer 子节点")
		return
	
	# 检查是否已存在同名事件
	if event_layer.has_node("Event_" + event_id):
		print("警告: 事件 ", event_id, " 已存在，将被替换")
		event_layer.get_node("Event_" + event_id).queue_free()
	
	# 创建事件区域
	var event = Area2D.new()
	event.name = "Event_" + event_id
	event_layer.add_child(event)
	
	# 添加碰撞形状
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.name = "CollisionShape2D"
	event.add_child(collision)
	
	# 设置位置
	event.position = position
	
	# 添加视觉指示器
	var indicator = Sprite2D.new()
	# 根据事件ID加载不同的图标
	var icon_path = "res://Resource/res/icon/map/" + event_id + ".png"
	if ResourceLoader.exists(icon_path):
		indicator.texture = load(icon_path)
	else:
		# 使用默认图标
		print("警告: 找不到事件图标 ", icon_path, "，使用默认图标")
		var default_icon_path = "res://Resource/res/icon/map/default.png"
		if ResourceLoader.exists(default_icon_path):
			indicator.texture = load(default_icon_path)
	
	event.add_child(indicator)
	
	# 连接信号
	event.input_event.connect(func(viewport, input_event, shape_idx):
		if input_event is InputEventMouseButton and input_event.pressed:
			print("触发事件: ", event_id)
			callback.call()
	)
	
	# 将事件添加到地图数据
	if maps_data.has(map_id):
		maps_data[map_id].events.append(event_id)
	
	# 返回事件对象，以便后续操作
	return event

# 揭示所有事件区域 - 简化版，直接基于场景结构
func reveal_event_areas(map_id: String):
	var map_node = get_node_or_null(map_id)
	if not map_node:
		print("错误: 找不到地图节点 ", map_id)
		return
		
	var map_image = map_node.get_node_or_null("MapImage")
	if not map_image:
		print("错误: 地图节点 ", map_id, " 没有 MapImage 子节点")
		return
		
	var event_layer = map_image.get_node_or_null("EventLayer")
	if not event_layer:
		print("错误: 地图节点 ", map_id, " 没有 EventLayer 子节点")
		return
		
	var fog_layer = map_image.get_node_or_null("FogLayer")
	if not fog_layer:
		print("错误: 地图节点 ", map_id, " 没有 FogLayer 子节点")
		return
	
	# 创建遮罩材质 - 基本原理是用事件区域作为遮罩来挖孔
	setup_fog_mask(map_id)

# 设置迷雾遮罩 - 使用shader方法
func setup_fog_mask(map_id: String):
	var map_node = get_node_or_null(map_id)
	if not map_node:
		print("错误: 找不到地图节点 ", map_id)
		return
		
	var map_image = map_node.get_node_or_null("MapImage")
	if not map_image:
		print("错误: 地图节点 ", map_id, " 没有 MapImage 子节点")
		return
	
	var fog_layer = map_image.get_node_or_null("FogLayer")
	if not fog_layer:
		print("错误: 地图节点 ", map_id, " 没有 FogLayer 子节点")
		return
	
	var event_layer = map_image.get_node_or_null("EventLayer")
	if not event_layer:
		print("错误: 地图节点 ", map_id, " 没有 EventLayer 子节点")
		return
	
	# 清理旧的调试节点
	for child in map_image.get_children():
		if child.name == "MaskDebug":
			child.queue_free()
	
	# 确保FogLayer是ColorRect类型
	if not fog_layer is ColorRect:
		print("警告: FogLayer不是ColorRect类型，无法应用shader效果")
		return
	
	# 确保FogLayer有合适的大小
	if map_image.texture:
		fog_layer.size = map_image.texture.get_size()
		print("设置迷雾层大小: ", fog_layer.size)
	
	# 获取或创建shader材质
	var shader_material
	if fog_layer.material and fog_layer.material is ShaderMaterial:
		shader_material = fog_layer.material
		print("使用现有ShaderMaterial")
	else:
		# 尝试加载fog_mask着色器
		var shader_path = "res://Resource/src/shader/fog_mask.gdshader"
		var shader
		if ResourceLoader.exists(shader_path):
			shader = load(shader_path)
			print("加载着色器: ", shader_path)
		else:
			print("错误: 找不到着色器 ", shader_path)
			return
		
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		fog_layer.material = shader_material
		print("创建新的ShaderMaterial")
	
	# 收集区域数据
	var circle_count = 0
	var rect_count = 0
	var circle_data = []
	var rect_data = []
	
	print("开始收集区域数据...")
	
	# 限制最多支持的区域数量
	var max_areas = 10
	
	for event in event_layer.get_children():
		if event is Area2D:
			var collision = event.get_node_or_null("CollisionShape2D")
			if collision and collision.shape:
				var global_pos = event.global_position
				print("处理事件: ", event.name, " 全局位置: ", global_pos)
				
				if collision.shape is CircleShape2D and circle_count < max_areas:
					var radius = collision.shape.radius
					# 将半径转换为屏幕坐标
					var screen_radius = radius
					
					# 创建圆形数据 [x, y, radius]
					var data = Vector3(global_pos.x, global_pos.y, screen_radius)
					circle_data.append(data)
					circle_count += 1
					print("添加圆形区域 #", circle_count, ": 位置(", global_pos.x, ",", global_pos.y, ") 半径: ", screen_radius)
					
				elif collision.shape is RectangleShape2D and rect_count < max_areas:
					var size = collision.shape.size
					# 创建矩形数据 [x, y, width, height]
					var data = Vector4(
						global_pos.x - size.x/2, 
						global_pos.y - size.y/2,
						size.x,
						size.y
					)
					rect_data.append(data)
					rect_count += 1
					print("添加矩形区域 #", rect_count, ": 位置(", global_pos.x - size.x/2, ",", global_pos.y - size.y/2, ") 尺寸: ", size)
				
				if circle_count + rect_count >= max_areas:
					print("警告: 达到最大支持区域数量限制 (", max_areas, ")")
					break
	
	# 将收集到的数据设置为shader参数
	print("设置shader参数: 圆形区域 ", circle_count, "个, 矩形区域 ", rect_count, "个")
	
	# 设置圆形数据
	shader_material.set_shader_parameter("circle_count", circle_count)
	if circle_count > 0:
		# 确保数组大小为10
		while circle_data.size() < 10:
			circle_data.append(Vector3(0, 0, 0))
		shader_material.set_shader_parameter("circle_data", circle_data)
	
	# 设置矩形数据
	shader_material.set_shader_parameter("rect_count", rect_count)
	if rect_count > 0:
		# 确保数组大小为10
		while rect_data.size() < 10:
			rect_data.append(Vector4(0, 0, 0, 0))
		shader_material.set_shader_parameter("rect_data", rect_data)
	
	# 设置迷雾颜色 (暗灰色半透明)
	shader_material.set_shader_parameter("fog_color", Color(0.1, 0.1, 0.1, 0.8))
	
	print("为 ", map_id, " 设置了迷雾遮罩，共处理了 ", circle_count + rect_count, " 个事件区域")

# 切换迷雾显示
func toggle_fog(map_id: String, enabled: bool):
	var map_node = get_node_or_null(map_id)
	if not map_node:
		print("错误: 找不到地图节点 ", map_id)
		return
		
	var map_image = map_node.get_node_or_null("MapImage")
	if not map_image:
		print("错误: 地图节点 ", map_id, " 没有 MapImage 子节点")
		return
		
	var fog_layer = map_image.get_node_or_null("FogLayer")
	if not fog_layer:
		print("错误: 地图节点 ", map_id, " 没有 FogLayer 子节点")
		return
		
	# 设置迷雾可见性
	fog_layer.visible = enabled
	
	# 更新地图数据
	if maps_data.has(map_id):
		maps_data[map_id].fog_enabled = enabled
