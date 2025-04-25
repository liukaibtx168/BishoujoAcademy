extends Control  # 场景根节点类型

const SAVE_PATH = "res://Resource/savedata/savadata.json"
# 节点引用声明（更安全的获取方式）
@onready var close_button: TextureButton = $CloseButton
# 在 SaveScreen.gd 顶部添加（类成员变量声明区域）↓
@onready var container = $Sprite2D/savedata  # 匹配场景中的实际路径

const ANIM_TIME = 0.3  # 动画持续时间
var _is_closing := false  # 防止重复关闭
# 新增模式区分参数
var is_load_mode := false

func set_operation_mode(is_load: bool):
	is_load_mode = is_load

func _ready():
	# 初始化动画
	_enter_animation()
	
	# 连接按钮信号（安全方式）
	if close_button:
		close_button.connect("pressed", _on_close_pressed)
	else:
		push_error("Close button not found!")

	load_and_display_saves()

func _enter_animation():
	# 初始状态设置
	modulate = Color(1, 1, 1, 0)
	# 入场动画：透明度渐变
	create_tween()\
		.tween_property(self, "modulate:a", 1.0, ANIM_TIME)\
		.set_trans(Tween.TRANS_SINE)

# 新增排序函数
func _sort_saves(a, b):
	return a["save_id"] < b["save_id"]  # 升序排列（1->2->3...）

func load_and_display_saves(from_delete=false, new_data=null):
	var save_data = new_data if from_delete else load_save_data()
	save_data.sort_custom(_sort_saves)  # 这里执行排序
	
	for slot_index in 4:
		var data_node = container.get_node("data%d" % (slot_index+1))
		if slot_index < save_data.size():
			var name_label = data_node.get_node("notnull/Diban01/name") # 关键路径
			name_label.text = save_data[slot_index]["name"] # 动态设置名称
			# 获取当前槽位的实际存档ID
			var real_save_id = save_data[slot_index]["save_id"]
			# 重新绑定删除按钮参数（重点修改）
			var del_btn = data_node.get_node("notnull/Diban01/datadel")
			if del_btn.is_connected("pressed", _on_datadel_pressed):
				del_btn.disconnect("pressed", _on_datadel_pressed)
			del_btn.connect("pressed", _on_datadel_pressed.bind(real_save_id))
			data_node.get_node("notnull").show()
			data_node.get_node("null").hide()
			populate_slot_data(data_node, save_data[slot_index])
		else:
			data_node.get_node("notnull").hide()
			data_node.get_node("null").show()

func load_save_data() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		print("存档文件不存在")
		return []
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	var parse_result = json.parse(file.get_as_text())
	
	return json.data if parse_result == OK else []

func find_save_by_id(data: Array, id: int) -> Dictionary:
	for save in data:
		if save["save_id"] == id:
			return save
	return {}

func populate_slot_data(slot_node: Control, data: Dictionary):
	var root_node = slot_node.get_node("notnull")
	# 设置头像
	var avatar_path = data.get("avatar_path", "")
	if ResourceLoader.exists(avatar_path):
		root_node.get_node("Diban01/Cundang04/Zhujiaohead").texture = load(avatar_path)
	
	# 设置名称标签
	_set_label(slot_node, "Diban01/name", data.get("name", ""))
	
	# 设置属性值
	_set_label(root_node, "Diban01/XiaoDiban01/Label", str(data.get("stamina", 0)))
	_set_label(root_node, "Diban01/XiaoDiban02/Label", str(data.get("intelligence", 0)))
	_set_label(root_node, "Diban01/XiaoDiban03/Label", str(data.get("charisma", 0)))
	
	# 设置时间
	var time_data = data.get("time", {"month":0, "day":0})
	var base_path = "res://Resource/res/ui/meishuzi/rili/"
	var time_node = slot_node.get_node("notnull/Diban01/time")

	# 处理月份（month节点）
	var month_num = time_data.get("month", 1)
	var month_texture_path = "%smonth_%d.png" % [base_path, month_num]
	if ResourceLoader.exists(month_texture_path):
		time_node.get_node("month").texture = load(month_texture_path)
	else:
		push_warning("月份图片缺失: ", month_texture_path)

	# 处理日期（day节点）
	var day_num = time_data.get("day", 1)
	var day_texture_path = "%sday_%d.png" % [base_path, day_num]
	if ResourceLoader.exists(day_texture_path):
		time_node.get_node("day").texture = load(day_texture_path)
	else:
		push_warning("日期图片缺失: ", day_texture_path)	

# 通用标签设置辅助方法
func _set_label(root: Node, path: String, text: String):
	var label = root.get_node_or_null(path) as Label
	if label:
		label.text = text
	else:
		print("警告：未找到标签节点 - ", path)
		
# 扩展输入处理（支持ESC键关闭）
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") and !_is_closing:
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed():
	if _is_closing: return
	_is_closing = true
	
	# 离场动画
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, ANIM_TIME)
	tween.tween_callback(queue_free)  # 动画完成后自动销毁

# 动画回调安全处理
func safe_queue_free():
	if is_instance_valid(self):
		queue_free()  # 不再需要特殊符号，直接调用继承自 Node 的方法
		
# 记录当前操作的存档ID
var current_selected_save_id = -1  

func _connect_delete_buttons(node: Node, target_id: int):
	var del_btn = node.get_node("datadel")  # 确保路径正确
	if del_btn.is_connected("pressed", _on_datadel_pressed):
		del_btn.disconnect("pressed", _on_datadel_pressed)  # 防止重复绑定
	
	del_btn.connect("pressed", self._on_datadel_pressed.bind(target_id))  # 绑定真实ID

# 添加删除按钮逻辑
func _setup_del_buttons():
	# 在load_and_display_saves遍历slot_index时添加（修改已有循环）：
	for slot_index in range(1, 5):
		var data_node = container.get_node("data%d" % slot_index)
		
		# 获取删除按钮并连接信号（新增）
		var del_btn = data_node.get_node("notnull/Diban01/datadel")
		# 避免重复连接
		if del_btn.is_connected("pressed", _on_datadel_pressed):
			del_btn.disconnect("pressed", _on_datadel_pressed) 
		del_btn.connect("pressed", self._on_datadel_pressed.bind(slot_index))

func _on_datadel_pressed(save_id):
	current_selected_save_id = save_id
	var confirm_dialog = preload("res://Resource/src/tscn/yes_or_no.tscn").instantiate()
	add_child(confirm_dialog)
	confirm_dialog.set_question("确认删除这个存档吗？", self._on_delete_confirmed)

# 删除确认回调
func _on_delete_confirmed():
	var save_data = load_save_data()
	# 创建新数组过滤被删存档
	var filtered_data  = save_data.filter(func(s): return s["save_id"] != current_selected_save_id)
	
	# 保存到文件
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(filtered_data))
	file.flush()                          # 确保写入完成（关键操作）
	
	# 直接使用新数据进行界面更新
	load_and_display_saves(true, filtered_data)  # 添加参数立即刷新
	# 界面刷新更新信号
	emit_signal("save_data_updated")

# 更新信号
signal save_data_updated
