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
	# 文字显示完成后，处理选项
	if current_dialogue_id != -1:  # 确保对话还在进行
		var current = dialogue_data[str(current_dialogue_id)]
		if current.has("nextID"):
			handle_choices(current.nextID)

func handle_choices(next_ids):
	print("DialogueSystem: Handling choices: ", next_ids)
	# 清除现有选项
	for child in choices_container.get_children():
		child.queue_free()
	
	# 如果next_ids是空数组或空字典
	if (next_ids is Array and next_ids.is_empty()) or (next_ids is Dictionary and next_ids.is_empty()):
		# 如果没有下一个对话，则设置标记等待点击结束
		print("DialogueSystem: No next dialogue, waiting for click to end")
		current_dialogue_id = 0  # 使用0作为等待结束的标记
		choices_container.hide()
		return
	
	# 如果next_ids是数组，转换为字典格式
	var next_ids_dict = {}
	if next_ids is Array:
		print("DialogueSystem: Converting array to dictionary")
		if next_ids.size() == 1:
			next_ids_dict["[1]"] = next_ids[0]
		else:
			for i in range(next_ids.size()):
				next_ids_dict["[" + str(i + 1) + "]"] = next_ids[i]
	else:
		next_ids_dict = next_ids
	
	if next_ids_dict.size() == 1:
		# 如果只有一个选项，不显示选项UI
		print("DialogueSystem: Single choice, hiding choices container")
		choices_container.hide()
		return
	
	# 显示多个选项
	print("DialogueSystem: Showing multiple choices")
	choices_container.show()
	for key in next_ids_dict.keys():
		var next_id = next_ids_dict[key]
		if !dialogue_data.has(str(next_id)):
			print("DialogueSystem: Choice option ID not found: ", next_id)
			continue
			
		var choice_text = dialogue_data[str(next_id)].text
		var button = Button.new()
		button.text = choice_text
		button.custom_minimum_size = Vector2(300, 50)
		
		# 设置按钮样式
		if normal_style:
			button.add_theme_stylebox_override("normal", normal_style)
		if hover_style:
			button.add_theme_stylebox_override("hover", hover_style)
		if pressed_style:
			button.add_theme_stylebox_override("pressed", pressed_style)
		
		# 设置文字颜色
		button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.8, 1))
		button.add_theme_color_override("font_pressed_color", Color(0.9, 0.8, 0.7, 1))
		
		# 设置字体大小
		button.add_theme_font_size_override("font_size", 18)
		
		choices_container.add_child(button)
		# 连接按钮信号
		button.pressed.connect(_on_choice_selected.bind(next_id))

func _on_choice_selected(next_id: int):
	print("DialogueSystem: Choice selected: ", next_id)
	
	# 获取选中选项对应的下一句对话
	if dialogue_data.has(str(next_id)):
		var selected_dialogue = dialogue_data[str(next_id)]
		if selected_dialogue.has("nextID"):
			var next_dialogue_id = null
			
			# 处理nextID可能是数组或字典的情况
			if selected_dialogue.nextID is Array:
				if selected_dialogue.nextID.size() > 0:
					next_dialogue_id = selected_dialogue.nextID[0]
			elif selected_dialogue.nextID is Dictionary:
				if selected_dialogue.nextID.has("[1]"):
					next_dialogue_id = selected_dialogue.nextID["[1]"]
			
			if next_dialogue_id != null and dialogue_data.has(str(next_dialogue_id)):
				# 直接跳转到下一句对话
				current_dialogue_id = next_dialogue_id
				choices_container.hide()
				display_current_dialogue()
			else:
				# 如果没有有效的下一句对话，设置为等待结束状态
				print("DialogueSystem: No valid next dialogue after choice")
				current_dialogue_id = 0
		else:
			# 如果选项没有下一句对话，设置为等待结束状态
			print("DialogueSystem: Choice has no nextID")
			current_dialogue_id = 0
	else:
		# 如果选项ID无效，设置为等待结束状态
		print("DialogueSystem: Invalid choice ID")
		current_dialogue_id = 0

func end_dialogue():
	print("DialogueSystem: Ending dialogue")
	current_dialogue_id = -1
	
	# 停止所有音频
	if bgm_player.playing:
		bgm_player.stop()
	if sound_player.playing:
		sound_player.stop()
	if voice_player.playing:
		voice_player.stop()
	
	# 清理UI
	text_label.text = ""
	name_label.text = ""
	
	# 清除立绘和背景
	if character_sprite.texture:
		character_sprite.texture = null
		character_sprite.hide()
	if background.texture:
		background.texture = null
	
	# 清除选项
	for child in choices_container.get_children():
		child.queue_free()
	choices_container.hide()
	
	# 隐藏对话系统
	hide_dialogue_system()
	
	# 发出对话结束信号
	print("DialogueSystem: Emitting dialogue_ended signal")
	dialogue_ended.emit()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("DialogueSystem: Mouse click detected")
		if current_dialogue_id == -1:
			print("DialogueSystem: No active dialogue")
			return
			
		if is_typing:
			print("DialogueSystem: Skipping typing animation")
			# 如果正在打字，则立即显示完整文本
			is_typing = false
			if dialogue_data.has(str(current_dialogue_id)) and dialogue_data[str(current_dialogue_id)].has("text"):
				text_label.text = dialogue_data[str(current_dialogue_id)].text
				# 文字显示完成后，处理选项
				var current = dialogue_data[str(current_dialogue_id)]
				if current.has("nextID"):
					handle_choices(current.nextID)
			return  # 重要：在快进文字显示时不处理其他点击逻辑
		elif choices_container.visible:
			print("DialogueSystem: Choices are visible, ignoring click")
			# 如果显示选项，则不进行处理
			return
		elif current_dialogue_id == 0:  # 等待结束的状态
			print("DialogueSystem: Ending dialogue after final click")
			end_dialogue()
			return
		else:
			print("DialogueSystem: Processing next dialogue")
			# 如果有下一句对话，则继续
			if not dialogue_data.has(str(current_dialogue_id)):
				print("DialogueSystem: Current dialogue ID not found: ", current_dialogue_id)
				end_dialogue()
				return
				
			var current = dialogue_data[str(current_dialogue_id)]
			print("DialogueSystem: Current dialogue data: ", current)
			
			if not current.has("nextID"):
				print("DialogueSystem: No nextID field in current dialogue")
				end_dialogue()
				return
				
			var next_ids = current.nextID
			print("DialogueSystem: Next IDs: ", next_ids)
			
			if next_ids is Array:
				if next_ids.size() == 1:
					var next_id = next_ids[0]
					if dialogue_data.has(str(next_id)):
						current_dialogue_id = next_id
						display_current_dialogue()
					else:
						print("DialogueSystem: Next dialogue ID not found: ", next_id)
						current_dialogue_id = 0  # 设置为等待结束状态
				elif next_ids.is_empty():
					print("DialogueSystem: Dialogue ready to end, waiting for click")
					current_dialogue_id = 0  # 设置为等待结束状态
				else:
					print("DialogueSystem: Multiple choices available in array")
			elif next_ids is Dictionary:
				if next_ids.size() == 1 and next_ids.has("[1]"):
					var next_id = next_ids["[1]"]
					if dialogue_data.has(str(next_id)):
						current_dialogue_id = next_id
						display_current_dialogue()
					else:
						print("DialogueSystem: Next dialogue ID not found: ", next_id)
						current_dialogue_id = 0  # 设置为等待结束状态
				elif next_ids.is_empty():
					print("DialogueSystem: Dialogue ready to end, waiting for click")
					current_dialogue_id = 0  # 设置为等待结束状态
				else:
					print("DialogueSystem: Multiple choices available in dictionary")
			else:
				print("DialogueSystem: Invalid nextID type: ", typeof(next_ids))
				current_dialogue_id = 0  # 设置为等待结束状态

func show_dialogue_system():
	print("DialogueSystem: Showing dialogue system")
	# 显示整个系统
	show()
	modulate = Color(1, 1, 1, 1)
	
	# 显示对话框
	dialogue_box.show()
	dialogue_box.modulate = Color(1, 1, 1, 1)
	print("DialogueSystem: Dialogue system is now visible")

func hide_dialogue_system():
	print("DialogueSystem: Hiding dialogue system")
	# 确保所有UI元素都被隐藏
	dialogue_box.hide()
	choices_container.hide()
	character_sprite.hide()
	
	# 最后隐藏整个系统
	hide()
	print("DialogueSystem: Dialogue system is now hidden") 
