extends Node2D
class_name Character

#定义常用信号如：角色死亡，生命值/魔力值变化
signal character_died(character:Character)
signal character_defeated(character:Character)
signal hp_change(current_hp:float,max_hp:float,character:Character)
signal mp_change(current_mp:float,max_mp:float,character:Character)

@export var character_data:CharactertData #角色静态数据

#导出AttributeSet资源模版（在编辑器中指定，如PlayerAttributeSet_Default.tres）
@export var attribute_set_resource:AttributeSet

#运行时角色实际持有的AttributeSet实例（通过模版duplicate而来）
var active_attribute_set:AttributeSet = null

#常用属性的快捷访问getter方法
var max_hp:float:
	get:return active_attribute_set.get_current_value(&"MaxHp") if active_attribute_set else 0.0

var current_hp:float:
	get:return active_attribute_set.get_current_value(&"CurrentHp") if active_attribute_set else 0.0

var max_mp:float:
	get:return active_attribute_set.get_current_value(&"MaxMp") if active_attribute_set else 0.0	

var current_mp:float:
	get:return active_attribute_set.get_current_value(&"CurrentMp") if active_attribute_set else 0.0

var attack_power:float:
	get:return active_attribute_set.get_current_value(&"AttackPower") if active_attribute_set else 0.0

var defense_power:float:
	get:return active_attribute_set.get_current_value(&"DefensePower") if active_attribute_set else 0.0

var is_alive:bool = true:
	get:return current_hp > 0.0 if active_attribute_set else 0.0

var is_defending:bool = false #临时行为状态
	
@onready var name_label:Label = $NameLabel #设置UI节点
@onready var hp_bar:ProgressBar = $HpBar   #设置血条节点

func _ready():
	if not character_data:
		printerr("%s:CharacterData not assigned!" % name)
		return
	if not attribute_set_resource:
		printerr("%s:AttributeSet resource not assigned!" % name)
		return
	
	#关键：为每个character创建一个独立的AttributeSet实例
	active_attribute_set = attribute_set_resource.duplicate(true) as AttributeSet
	if not active_attribute_set:
		printerr("%s:Failed to duplicate AttributeSet resource" % name)
		return
	
	#初始化AttributeSet实例
	active_attribute_set.initialize_set()
	
	#连接AttributeSet的信号到Character的出来函数
	active_attribute_set.current_value_changed.connect(_on_attribute_current_value_changed)
	active_attribute_set.base_value_changed.connect(_on_attribute_base_value_changed)
	
	#(可选)如果AttributeSet的钩子函数需要更复杂的处理，可以考虑将Character实例传递给AttributeSet
	#active_attribute_set.set_owner_character(self) #如果AttributeSet需要回调Character
	
	#初始化UI显示
	_update_name_dispaly()
	_update_hp_dispaly()
	_update_mp_dispaly()
	
	print("%s initialized. HP: %.1f%.1f,Attack: %.1f" % [character_data.character_name,current_hp,current_mp,attack_power])
	
#当AttributeSet中的属性当前值变化时候调用
func _on_attribute_current_value_changed(attribute_instance:Attribute,_old_value:float,_new_value:float,_source:Variant):
	if attribute_instance.attribute_name == &"CurrentHp":
		hp_change.emit(_new_value,max_hp,self)
		_update_hp_dispaly()
		if _new_value <= 0.0 and _old_value > 0.0: #从存活到死亡
			_die()
	elif attribute_instance.attribute_name == &"MaxHp":
		hp_change.emit(current_hp,_new_value,self)
		_update_hp_dispaly()
	elif attribute_instance.attribute_name == &"CurrentMp":
		mp_change.emit(_new_value,max_mp,self)
		_update_mp_dispaly()
	elif attribute_instance.attribute_name == &"MaxMp":
		mp_change.emit(current_mp,_new_value,self)
		_update_mp_dispaly()

#当AttributeSet中的属性基础值变化时候调用
func _on_attribute_base_value_changed(attribute_instance:Attribute,_old_value:float,_new_value:float,_source:Variant):
	if attribute_instance.attribute_name == &"MaxHp":
		hp_change.emit(_new_value,max_hp,self)
		_update_hp_dispaly()
	elif attribute_instance.attribute_name == &"MaxMp":
		mp_change.emit(_new_value,max_mp,self)
		_update_mp_dispaly()

func take_damage(base_damage:float) -> float:
	var final_damage:float = base_damage
	
	#如果处于防御状态下，则减免伤害
	if is_defending:
		final_damage = round(final_damage * 0.5)
		print(character_name + "正在防御，伤害减半！")
		set_defending(false)   #受到一次攻击后解除防御状态
		
	if final_damage <= 0:
		return 0.0
	
	active_attribute_set.modify_base_value("CurrentHp", -final_damage)
	return final_damage

func set_defending(value:bool) -> bool:
	is_defending = value
	return is_defending

func heal(amount:int) -> int:
	active_attribute_set.modify_base_value("CurrentHp",amount)
	return amount

func use_mp(amount:int) -> int:
	if current_mp >= amount:
		active_attribute_set.modify_base_value("CurrentMp",-amount)
		return true
	return false

func _update_name_dispaly():
	return

func _update_hp_dispaly():
	return

func _update_mp_dispaly():
	return

func _die():
	# is_alive的getter会自动更新，但是这里可以执行死亡动画，音效，移除战斗等逻辑
	print_rich("[color=red][b]%s[/b] has been defeated![/color]" % [character_data.character_name])
	character_defeated.emit(self)
	modulate = Color(0.5,0.5,0.5,0.5)
