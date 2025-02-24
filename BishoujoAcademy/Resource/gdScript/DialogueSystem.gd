extends Control

# 对话数据
var dialogue_data = {}
var current_dialogue_id = -1  # 将初始值改为-1，表示没有激活的对话
var is_typing = false
var typing_speed = 0.05  # 打字机效果的速度
var is_mask_playing = false  # 添加遮罩动画状态标记
var is_shaking = false  # 添加震动状态标记

# 节点引用
@onready var dialogue_box = $DialogueBox
@onready var name_label = $DialogueBox/NameLabel
@onready var text_label = $DialogueBox/TextLabel
@onready var choices_container = $ChoicesContainer
@onready var shake_container = $ShakeContainer  # 新增震动容器引用
@onready var character_sprite = $ShakeContainer/CharacterSprite  # 修改路径
@onready var background = $ShakeContainer/Background  # 修改路径
@onready var mask_background = $MaskBackground  # 新增遮罩背景引用

# 音频播放器
@onready var bgm_player = $BGMPlayer
@onready var sound_player = $SoundPlayer
@onready var voice_player = $VoicePlayer

# 按钮样式
var normal_style: StyleBoxFlat
var hover_style: StyleBoxFlat
var pressed_style: StyleBoxFlat

# 震动效果相关常量
const STANDARD_UNIT = 100.0  # 标准震动单位
const SHAKE_DURATION = 1.0   # 单次震荡持续时间
const SPEED_MULTIPLIER = 5.0  # 速度倍数

func _ready():
	print("DialogueSystem: Starting initialization...")
	# 检查父节点是否为CanvasLayer
	if not get_parent() is CanvasLayer:
		print("DialogueSystem: Warning - This node should be a child of a CanvasLayer")
	
	# 创建按钮样式
	create_button_styles()
	# 加载对话数据
	if !load_dialogue_data():
		print("DialogueSystem: Failed to load dialogue data!")
		return
	# 初始化UI
	hide_dialogue_system()
	print("DialogueSystem: Initialization complete!")

func create_button_styles():
	# 普通状态
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(1, 1, 1, 0.3)
	normal_style.corner_radius_top_left = 5
	normal_style.corner_radius_top_right = 5
	normal_style.corner_radius_bottom_right = 5
	normal_style.corner_radius_bottom_left = 5
	
	# 悬停状态
	hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = Color(1, 1, 1, 0.5)
	hover_style.corner_radius_top_left = 5
	hover_style.corner_radius_top_right = 5
	hover_style.corner_radius_bottom_right = 5
	hover_style.corner_radius_bottom_left = 5
	
	# 按下状态
	pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.4, 0.4, 0.4, 0.9)
	pressed_style.border_width_left = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_bottom = 2
	pressed_style.border_color = Color(1, 1, 1, 0.7)
	pressed_style.corner_radius_top_left = 5
	pressed_style.corner_radius_top_right = 5
	pressed_style.corner_radius_bottom_right = 5
	pressed_style.corner_radius_bottom_left = 5

func load_dialogue_data() -> bool:
	print("DialogueSystem: Attempting to load dialogue data...")
	if !FileAccess.file_exists("res://Resource/json/dialogue.json"):
		print("DialogueSystem: dialogue.json file not found!")
		return false
	
	var file = FileAccess.open("res://Resource/json/dialogue.json", FileAccess.READ)
	if file == null:
		print("DialogueSystem: Failed to open dialogue.json!")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("DialogueSystem: Failed to parse JSON data!")
		print("Error: ", json.get_error_message())
		return false
	
	dialogue_data = json.get_data()
	print("DialogueSystem: Dialogue data loaded successfully!")
	return true

func start_dialogue(dialogue_id: int):
	print("DialogueSystem: Starting dialogue with ID: ", dialogue_id)
	if not dialogue_data.has(str(dialogue_id)):
		print("Error: Dialogue ID not found: ", dialogue_id)
		return
		
	current_dialogue_id = dialogue_id
	show_dialogue_system()
	display_current_dialogue()

func display_current_dialogue():
	print("DialogueSystem: Displaying dialogue ID: ", current_dialogue_id)
	var current = dialogue_data[str(current_dialogue_id)]
	print("DialogueSystem: Current dialogue data: ", current)
	
	# 处理屏幕特效
	print("DialogueSystem: Checking for mask change...")
	if current.has("maskChange"):
		print("DialogueSystem: Found maskChange field: ", current.maskChange)
		var mask_params = current.maskChange
		if mask_params is Dictionary and mask_params.has("[1]") and mask_params.has("[2]"):
			var color_type = int(mask_params["[1]"])
			var duration = float(mask_params["[2]"])
			print("DialogueSystem: Mask change with color type: ", color_type, " and duration: ", duration)
			await mask_change(color_type, duration)
		else:
			print("DialogueSystem: Invalid maskChange parameters")
	
	# 处理震动效果
	if current.has("Shake"):
		print("DialogueSystem: 检测到震动效果配置")
		var shake_value = current.Shake
		if shake_value == 1:
			await shake_effect(1.0, 2)  # 轻微震动：1倍强度，2次
		elif shake_value == 2:
			await shake_effect(1.5, 4)  # 剧烈震动：1.5倍强度，4次
	
	# 更新角色名
	name_label.text = current.name if current.has("name") else ""
	print("DialogueSystem: Set name to: ", name_label.text)
	
	# 更新角色立绘
	if current.has("modle") and current.modle != "":
		var texture_path = current.modle
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			if texture:
				character_sprite.texture = texture
				character_sprite.show()
			else:
				character_sprite.hide()
		else:
			character_sprite.hide()
	else:
		character_sprite.hide()
	
	# 更新背景
	if current.has("sence") and current.sence != "":
		var texture_path = current.sence
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			if texture:
				background.texture = texture
		else:
			print("DialogueSystem: Background file not found: ", texture_path)
	
	# 播放BGM
	if current.has("bgm") and current.bgm != "":
		var audio_path = current.bgm
		if ResourceLoader.exists(audio_path):
			var audio = load(audio_path)
			if audio:
				if not bgm_player.playing or bgm_player.stream != audio:
					bgm_player.stream = audio
					bgm_player.stream.loop = true  # 设置BGM循环播放
					bgm_player.play()
			else:
				print("DialogueSystem: Failed to load BGM!")
		else:
			print("DialogueSystem: BGM file not found: ", audio_path)
	
	# 播放音效
	if current.has("sound") and current.sound != "":
		var audio_path = current.sound
		if ResourceLoader.exists(audio_path):
			var audio = load(audio_path)
			if audio:
				sound_player.stream = audio
				sound_player.play()
	
	# 播放语音
	if current.has("voice") and current.voice != "":
		var audio_path = current.voice
		if ResourceLoader.exists(audio_path):
			var audio = load(audio_path)
			if audio:
				voice_player.stream = audio
				voice_player.play()
	
	# 显示文本（使用打字机效果）
	var text = current.text if current.has("text") else ""
	choices_container.hide()
	display_text_with_typing(text)

func display_text_with_typing(text: String):
	is_typing = true
	text_label.text = ""
	var displayed_text = ""
	
	for character in text:
		if not is_typing:  # 如果typing被中断，直接显示完整文本
			text_label.text = text
			break
			
		displayed_text += character
		text_label.text = displayed_text
		await get_tree().create_timer(typing_speed).timeout
	
	is_typing = false
	text_label.text = text  # 确保文本完全显示
	
	# 文字显示完成后，检查是否需要显示选项
	if current_dialogue_id != -1:  # 确保对话还在进行
		var current = dialogue_data[str(current_dialogue_id)]
		if current.get("isend", 0) == 1:
			# 如果是结束对话，等待点击
			return
		elif current.has("nextID"):
			# 如果有下一段对话，检查是否需要显示选项
			var next_ids = current.nextID
			if (next_ids is Array and next_ids.size() > 1) or (next_ids is Dictionary and next_ids.size() > 1):
				# 如果有多个选项，显示选项按钮
				prepare_choices(next_ids)

func prepare_choices(next_ids):
	print("DialogueSystem: Preparing choices: ", next_ids)
	# 清除现有选项
	for child in choices_container.get_children():
		child.queue_free()
	
	# 如果next_ids是空数组或空字典，直接返回
	if (next_ids is Array and next_ids.is_empty()) or (next_ids is Dictionary and next_ids.is_empty()):
		choices_container.hide()
		return
	
	# 将next_ids统一转换为字典格式
	var next_ids_dict = {}
	if next_ids is Array:
		print("DialogueSystem: Converting array to dictionary")
		for i in range(next_ids.size()):
			next_ids_dict["[" + str(i + 1) + "]"] = next_ids[i]
	else:
		next_ids_dict = next_ids
	
	# 如果只有一个选项，不显示选项按钮
	if next_ids_dict.size() == 1:
		choices_container.hide()
		return
	
	# 如果有多个选项，创建选项按钮
	choices_container.show()
	for key in next_ids_dict.keys():
		var choice_id = next_ids_dict[key]
		if not dialogue_data.has(str(choice_id)):
			continue
		
		var choice_dialogue = dialogue_data[str(choice_id)]
		var button = Button.new()
		
		# 获取选项的下一个对话ID
		var next_dialogue_id = null
		if choice_dialogue.has("nextID"):
			if choice_dialogue.nextID is Array and choice_dialogue.nextID.size() > 0:
				next_dialogue_id = choice_dialogue.nextID[0]
			elif choice_dialogue.nextID is Dictionary and choice_dialogue.nextID.has("[1]"):
				next_dialogue_id = choice_dialogue.nextID["[1]"]
		
		# 如果没有下一个对话ID，使用选项本身的ID
		if next_dialogue_id == null:
			print("DialogueSystem: Warning - Choice has no nextID, using choice ID: ", choice_id)
			next_dialogue_id = choice_id
		
		button.text = choice_dialogue.text
		button.custom_minimum_size = Vector2(200, 40)
		
		# 设置按钮样式
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", pressed_style)
		
		# 使用选项的下一个对话ID
		button.pressed.connect(_on_choice_selected.bind(next_dialogue_id))
		choices_container.add_child(button)

func _on_choice_selected(next_id):
	print("DialogueSystem: Choice selected, next ID: ", next_id)
	if str(next_id) in dialogue_data:
		current_dialogue_id = next_id
		choices_container.hide()
		display_current_dialogue()
	else:
		print("DialogueSystem: Invalid next dialogue ID: ", next_id)
		hide_dialogue_system()
		current_dialogue_id = -1

func hide_dialogue_system():
	print("DialogueSystem: Hiding dialogue system")
	# 确保所有UI元素都被隐藏
	dialogue_box.hide()
	choices_container.hide()
	character_sprite.hide()
	mask_background.hide()  # 使用节点引用
	
	# 停止所有音频
	bgm_player.stop()
	sound_player.stop()
	voice_player.stop()
	
	# 最后隐藏整个系统
	hide()
	print("DialogueSystem: Dialogue system is now hidden")

func show_dialogue_system():
	print("DialogueSystem: Showing dialogue system")
	# 显示整个系统
	show()
	modulate = Color(1, 1, 1, 1)
	
	# 显示遮罩背景
	mask_background.show()  # 使用节点引用
	
	# 显示对话框
	dialogue_box.show()
	dialogue_box.modulate = Color(1, 1, 1, 1)
	print("DialogueSystem: Dialogue system is now visible")

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_mask_playing or is_shaking:  # 如果遮罩动画或震动效果正在播放，不响应点击
			return
			
		if is_typing:
			# 如果正在打字，点击会立即显示完整文本
			is_typing = false
		elif current_dialogue_id == -1:
			# 如果没有激活的对话，忽略点击
			return
		else:
			var current = dialogue_data[str(current_dialogue_id)]
			
			# 如果是结束对话且文本已显示完成
			if current.get("isend", 0) == 1 and not is_typing:
				print("DialogueSystem: Ending dialogue")
				hide_dialogue_system()
				current_dialogue_id = -1
				return
			
			# 如果有下一个对话ID且文本已显示完成
			if current.has("nextID") and not is_typing:
				var next_ids = current.nextID
				# 如果只有一个选项，直接进入下一段对话
				if (next_ids is Array and next_ids.size() == 1) or (next_ids is Dictionary and next_ids.size() == 1):
					var next_id = next_ids[0] if next_ids is Array else next_ids["[1]"]
					if str(next_id) in dialogue_data:
						print("DialogueSystem: Moving to next dialogue: ", next_id)
						current_dialogue_id = next_id
						display_current_dialogue()
				# 如果有多个选项，确保选项已显示
				elif not choices_container.visible:
					prepare_choices(next_ids)

# 屏幕遮罩切换效果
func mask_change(color_type: int = 1, stay_duration: float = 0.3):
	print("DialogueSystem: Playing mask change effect")
	print("DialogueSystem: Color type: ", color_type, ", Stay duration: ", stay_duration)
	
	is_mask_playing = true  # 设置遮罩动画开始播放
	
	# 创建遮罩
	var mask_overlay = ColorRect.new()
	add_child(mask_overlay)
	
	# 设置遮罩颜色
	var mask_color = Color.BLACK if color_type == 1 else Color.WHITE
	mask_overlay.color = mask_color
	mask_overlay.color.a = 0  # 初始透明
	mask_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 设置遮罩大小为全屏
	var viewport_size = get_viewport_rect().size
	mask_overlay.size = viewport_size
	mask_overlay.position = Vector2.ZERO
	mask_overlay.z_index = 100
	
	# 第一阶段：淡入（0.5 -> 1.0，持续0.2秒）
	var tween_fade_in = create_tween()
	tween_fade_in.set_trans(Tween.TRANS_LINEAR)
	tween_fade_in.tween_property(mask_overlay, "color:a", 1.0, 0.2).from(0.5)
	await tween_fade_in.finished
	
	# 隐藏所有对话元素
	dialogue_box.hide()
	character_sprite.hide()
	choices_container.hide()
	
	# 停留指定时间
	await get_tree().create_timer(stay_duration).timeout
	
	# 第二阶段：淡出（1.0 -> 0.0，持续0.2秒）
	var tween_fade_out = create_tween()
	tween_fade_out.set_trans(Tween.TRANS_LINEAR)
	tween_fade_out.tween_property(mask_overlay, "color:a", 0.0, 0.2)  # 修正持续时间为0.2秒
	
	# 同时显示新的对话内容
	dialogue_box.show()
	if character_sprite.texture != null:
		character_sprite.show()
	
	# 等待淡出完成后清理遮罩
	await tween_fade_out.finished
	mask_overlay.queue_free()
	is_mask_playing = false  # 设置遮罩动画播放结束
	print("DialogueSystem: Mask change effect completed")

# 计算贝塞尔曲线点
func bezier(t: float, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> Vector2:
	var one_minus_t = 1.0 - t
	var one_minus_t_squared = one_minus_t * one_minus_t
	var one_minus_t_cubed = one_minus_t_squared * one_minus_t
	var t_squared = t * t
	var t_cubed = t_squared * t
	
	return p0 * one_minus_t_cubed + \
		   p1 * (3.0 * one_minus_t_squared * t) + \
		   p2 * (3.0 * one_minus_t * t_squared) + \
		   p3 * t_cubed

# 单次震荡
func single_oscillation(intensity: float, tween: Tween):
	# 固定为垂直方向（正下方到正上方）
	var direction = Vector2(0, 1)  # 向下的单位向量
	
	# 计算震动位移
	var displacement = direction * STANDARD_UNIT * intensity
	
	# 保存原始位置
	var original_pos = shake_container.position
	
	# 设置贝塞尔曲线的控制点
	var p0 = original_pos  # 起点
	var p1 = original_pos + displacement  # 第一控制点（向下）
	var p2 = original_pos - displacement  # 第二控制点（向上）
	var p3 = original_pos  # 终点
	
	# 创建震动关键帧
	var steps = 20  # 关键帧数量
	var frame_duration = (SHAKE_DURATION / SPEED_MULTIPLIER) / steps  # 加入速度倍数
	
	for i in range(steps + 1):
		var t = float(i) / steps
		var pos = bezier(t, p0, p1, p2, p3)
		tween.tween_property(shake_container, "position", pos, frame_duration)

# 震动效果
func shake_effect(intensity: float, repeat_count: int):
	print("DialogueSystem: 震动生效 - 强度系数: ", intensity, " 重复次数: ", repeat_count)
	is_shaking = true
	
	var tween = create_tween()
	tween.set_parallel(false)  # 串行执行每次震荡
	
	# 执行指定次数的震荡
	for i in range(repeat_count):
		single_oscillation(intensity, tween)
	
	# 确保最后回到原位
	tween.tween_property(shake_container, "position", shake_container.position, 0.1 / SPEED_MULTIPLIER)
	
	# 等待动画完成
	await tween.finished
	is_shaking = false
	print("DialogueSystem: 震动效果完成")
