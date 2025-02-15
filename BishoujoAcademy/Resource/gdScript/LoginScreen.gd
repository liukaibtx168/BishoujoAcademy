extends Control

const SAVE_PATH = "res://Resource/savedata/savadata.json"
const SAVE_SCREEN_SCENE = preload("res://Resource/tscn/SaveScreen.tscn")

@onready var continue_button: TextureButton = $ContinueButton

func _ready():
	# 初始化按钮状态
	update_continue_button_state()
	
	# 连接信号
	$ExitButton.connect("pressed", _on_exit_pressed)
	$ContinueButton.connect("pressed", _on_continue_pressed)
	$NewButton.connect("pressed", _on_new_pressed)

func update_continue_button_state():
	var save_data = _load_save_data()
	continue_button.disabled = save_data.is_empty()

func _load_save_data() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return []
	return json.data

func _on_exit_pressed():
	get_tree().quit()

func _on_continue_pressed():
	if not continue_button.disabled:
		_open_save_screen(true)

func _on_new_pressed():
	_open_save_screen(false)

func _open_save_screen(is_loading: bool):
	var save_screen = SAVE_SCREEN_SCENE.instantiate()
	save_screen.set_operation_mode(is_loading)
	save_screen.connect("save_data_updated", self._handle_save_update) # 新增连接
	# 改为直接添加到当前场景的同级（保持层级不变）
	get_parent().add_child(save_screen)

# 新增处理函数
func _handle_save_update():
	update_continue_button_state()
