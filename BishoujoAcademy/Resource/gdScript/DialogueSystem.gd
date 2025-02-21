extends Control

# 定义信号
signal dialogue_ended

# 对话数据
var dialogue_data = {}
var current_dialogue_id = -1  # 将初始值改为-1，表示没有激活的对话
var is_typing = false
var typing_speed = 0.05  # 打字机效果的速度

# 节点引用
@onready var dialogue_box = $DialogueBox
@onready var name_label = $DialogueBox/NameLabel
@onready var text_label = $DialogueBox/TextLabel
@onready var choices_container = $ChoicesContainer
@onready var character_sprite = $CharacterSprite
@onready var background = $Background

# 音频播放器
@onready var bgm_player = $BGMPlayer
@onready var sound_player = $SoundPlayer
@onready var voice_player = $VoicePlayer

# 按钮样式
var normal_style: StyleBoxFlat
var hover_style: StyleBoxFlat
var pressed_style: StyleBoxFlat

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
	if current.has("screenEffects"):
		print("DialogueSystem: Processing screen effect: ", current.screenEffects)
		match current.screenEffects:
			1: # 震动效果
				print("DialogueSystem: Starting screen shake effect")
				await screen_shake()
				print("DialogueSystem: Screen shake effect completed")
			2: # 黑屏淡出效果
				print("DialogueSystem: Starting screen fade effect")
				await screen_fade()
				print("DialogueSystem: Screen fade effect completed")
	
	# 更新角色名
	name_label.text = current.name if current.has("name") else ""
	print("DialogueSystem: Set name to: ", name_label.text)
	
	# 更新角色立绘
	if current.has("modle") and current.modle != "":
		print("DialogueSystem: Loading character sprite: ", current.modle)
		var texture_path = current.modle
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			if texture:
				character_sprite.texture = texture
				character_sprite.show()
				print("DialogueSystem: Character sprite loaded successfully")
			else:
				print("DialogueSystem: Failed to load character sprite!")
				character_sprite.hide()
		else:
			print("DialogueSystem: Character sprite file not found: ", texture_path)
			character_sprite.hide()
	else:
		character_sprite.hide()
		print("DialogueSystem: No character sprite to display")
	
	# 更新背景
	if current.has("sence") and current.sence != "":
		print("DialogueSystem: Loading background: ", current.sence)
		var texture_path = current.sence
		if ResourceLoader.exists(texture_path):
			var texture = load(texture_path)
			if texture:
				background.texture = texture
				print("DialogueSystem: Background loaded successfully")
			else:
				print("DialogueSystem: Failed to load background!")
		else:
			print("DialogueSystem: Background file not found: ", texture_path)
	
	# 播放BGM
	if current.has("bgm") and current.bgm != "":
		print("DialogueSystem: Loading BGM: ", current.bgm)
		var audio_path = current.bgm
		if ResourceLoader.exists(audio_path):
			var audio = load(audio_path)
			if audio:
				# 只有当当前没有播放BGM或者是不同的BGM时才更换
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
		print("DialogueSystem: Loading sound effect: ", current.sound)
		var audio_path = current.sound
		if ResourceLoader.exists(audio_path):
			var audio = load(audio_path)
			if audio:
				sound_player.stream = audio
				sound_player.play()
			else:
				print("DialogueSystem: Failed to load sound effect!")
		else:
			print("DialogueSystem: Sound effect file not found: ", audio_path)
	
	# 播放语音
	if current.has("voice") and current.voice != "":
		print("DialogueSystem: Loading voice: ", current.voice)
		var audio_path = current.voice
		if ResourceLoader.exists(audio_path):
			var audio = load(audio_path)
			if audio:
				voice_player.stream = audio
				voice_player.play()
			else:
				print("DialogueSystem: Failed to load voice!")
		else:
			print("DialogueSystem: Voice file not found: ", audio_path)
	
	# 显示文本（使用打字机效果）
	var text = current.text if current.has("text") else ""
	print("DialogueSystem: Displaying text: ", text)
	# 隐藏选项（在文字显示完成后才显示）
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
			# 如果有下一段对话，准备选项
			prepare_choices(current.nextID)

func prepare_choices(next_ids):
	print("DialogueSystem: Preparing choices: ", next_ids)
	# 清除现有选项
	for child in choices_container.get_children():
		child.queue_free()
	
	# 如果next_ids是空数组或空字典
	if (next_ids is Array and next_ids.is_empty()) or (next_ids is Dictionary and next_ids.is_empty()):
		return
	
	# 如果next_ids是数组，转换为字典格式
	var next_ids_dict = {}
	if next_ids is Array:
		print("DialogueSystem: Converting array to dictionary")
		for i in range(next_ids.size()):
			next_ids_dict["[" + str(i + 1) + "]"] = next_ids[i]
	else:
		next_ids_dict = next_ids
	
	# 如果只有一个选项，不显示选项框
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
		button.text = choice_dialogue.text
		button.custom_minimum_size = Vector2(200, 40)
		
		# 设置按钮样式
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", pressed_style)
		
		# 如果选项有下一段对话，连接到下一段
		if choice_dialogue.has("nextID"):
			var next_id = null
			if choice_dialogue.nextID is Array and choice_dialogue.nextID.size() > 0:
				next_id = choice_dialogue.nextID[0]
			elif choice_dialogue.nextID is Dictionary and choice_dialogue.nextID.has("[1]"):
				next_id = choice_dialogue.nextID["[1]"]
			
			if next_id != null:
				# 连接信号，直接跳转到选项的下一段对话
				button.pressed.connect(_on_choice_selected.bind(next_id))
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
		emit_signal("dialogue_ended")

func hide_dialogue_system():
	print("DialogueSystem: Hiding dialogue system")
	# 确保所有UI元素都被隐藏
	dialogue_box.hide()
	choices_container.hide()
	character_sprite.hide()
	
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
	
	# 显示对话框
	dialogue_box.show()
	dialogue_box.modulate = Color(1, 1, 1, 1)
	print("DialogueSystem: Dialogue system is now visible")

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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
				emit_signal("dialogue_ended")
				current_dialogue_id = -1
				return
			
			# 如果有选项且文本已显示完成
			if current.has("nextID") and not is_typing:
				var next_ids = current.nextID
				# 如果只有一个选项，点击后直接进入下一段对话
				if (next_ids is Array and next_ids.size() == 1) or (next_ids is Dictionary and next_ids.size() == 1 and next_ids.has("[1]")):
					var next_id = next_ids[0] if next_ids is Array else next_ids["[1]"]
					if str(next_id) in dialogue_data:
						current_dialogue_id = next_id
						display_current_dialogue()
				# 如果有多个选项且选项未显示，显示选项
				elif not choices_container.visible:
					choices_container.show() 

# 屏幕震动效果
func screen_shake(duration: float = 0.3, strength: float = 15.0):
	print("DialogueSystem: Playing screen shake effect")
	
	# 获取对话系统的根节点（应该是一个CanvasLayer）
	var root = get_parent()
	if not root is CanvasLayer:
		print("DialogueSystem: Warning - Parent is not a CanvasLayer, screen shake may not work correctly")
		return
	
	var original_offset = root.offset
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	
	# 创建一系列的震动移动
	var shake_steps = 8
	for i in range(shake_steps):
		var current_strength = strength if i == 0 else strength * (1.0 - float(i) / shake_steps)
		var offset = Vector2(
			randf_range(-current_strength, current_strength),
			randf_range(-current_strength, current_strength)
		)
		
		# 使用CanvasLayer的offset属性来实现整体位移
		tween.tween_property(root, "offset", original_offset + offset, duration / (shake_steps * 2))
		tween.tween_property(root, "offset", original_offset, duration / (shake_steps * 2))
	
	# 等待动画完成
	await tween.finished
	# 确保回到原始位置
	root.offset = original_offset

# 屏幕淡入淡出效果
func screen_fade(duration: float = 1.0):
	print("DialogueSystem: Playing screen fade effect")
	
	# 创建一个新的CanvasLayer来确保遮罩在最上层
	var overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 128  # 设置一个较高的层级
	get_tree().get_root().add_child(overlay_layer)
	
	# 创建黑色遮罩
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 将遮罩添加到新的CanvasLayer
	overlay_layer.add_child(fade_overlay)
	
	# 创建淡出效果
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(fade_overlay, "modulate:a", 0.0, duration)
	
	# 等待动画完成并清理
	await tween.finished
	overlay_layer.queue_free()
