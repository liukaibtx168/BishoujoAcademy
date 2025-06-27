extends Resource
class_name  AttributeSet

#暴露一个属性创建实例，用于编辑属性集合模版（如：英雄属性模版，怪物属性模版，障碍物属性模版），不同模版包含不同的属性列表
@export var attribute_to_initialize:Array[Attribute] = []

#储存实际初始化的Attribute实例
var _initialized_attributes:Dictionary[StringName,Attribute] = {}
var _is_initialized:bool = false

#定义信号
#当属性基础值发生变化后发出(属性，老的值，新的值，变化来源标记)
signal base_value_changed(attribute_instance:Attribute,old_base_value:float,new_base_value:float,source:Variant)
#当属性的当前值发生变化后发出(属性，老的值，新的值，变化来源标记)
signal current_value_changed(attribute_instance:Attribute,old_current_value:float,new_current_value:float,source:Variant)

#初始化AttributeSet，创建所有属性实例
#通常在角色_ready()中，获得AttributeSet实例后调用
func _initialize_set() -> void:
	if _is_initialized:
		print("属性集合已经初始化")
		return
		
	for template:Attribute in attribute_to_initialize:
		#为每个角色创建独立的属性实例
		var attribute_instance:Attribute = template.duplicate(true) as Attribute
		attribute_instance.set_owner_set(self) #设置对父合集的引用
		
		#初始时，当前值等于基础值（modifier还未进行修改）
		attribute_instance.set_base_value_internal(attribute_instance.base_value)
		attribute_instance.base_value_changed.connect(func(old_value,new_value):base_value_changed.emit(attribute_instance,old_value,new_value))
		attribute_instance.current_value_changed.connect(func(old_value,new_value):current_value_changed.emit(attribute_instance,old_value,new_value))
	
		if _initialized_attributes.has(attribute_instance.Attribute_name):
			printerr("Duplicate attribute_name 's%' found in AttributeSet configuration." % attribute_instance.Attribute_name)
		_initialized_attributes[attribute_instance.Attribute_name] = attribute_instance
		
	_is_initialized = true
	_on_resolve_inital_value_dependencies()  #调用钩子函数
	
	print("AttributeSet initialized with attributes:", _initialized_attributes.keys())
	
#获取指定名称的属性实例（Attribute的副本）
func get_attribute(attribute_name:StringName) -> Attribute:
	if not _is_initialized:
		printerr("属性没有初始化成功，第一次初始化调用initialize_set()")
		return null
	if not _initialized_attributes.has(attribute_name):
		printerr("属性 's%' 没有找到对应的属性集合" % attribute_name)
		return null
	return _initialized_attributes[attribute_name]

#获取属性的当前计算值
func get_current_value(attribute_name:StringName) ->float:
	var attr:= get_attribute(attribute_name)
	return attr.get_current_value() if attr else 0.0
	
#获取属性的基础计算值
func get_base_value(attribute_name:StringName) ->float:
	var attr:= get_attribute(attribute_name)
	return attr.get_base_value() if attr else 0.0

#设置属性的基础值
func set_base_value(attribute_name:StringName,new_base_value:float,source:Variant = null) -> bool:
	var attr:Attribute = get_attribute(attribute_name)
	if not attr:return false
	
	var old_base = attr.get_base_value()
	if old_base == new_base_value:
		return false #没有变化
		
	#钩子：基础值变化前
	var proposed_value = _pre_base_value_change(attr,old_base,new_base_value,source)
	var final_new_base_value = new_base_value
	if typeof(proposed_value) ==TYPE_FLOAT:
		final_new_base_value = proposed_value
	elif typeof(proposed_value) == TYPE_BOOL and not proposed_value:
		return false #变化被阻止
	
	attr.set_base_value_internal(final_new_base_value)
	
	#钩子：基础值变化过后
	_post_base_value_change(attr,old_base,attr.get_base_value(),source)
	return true

#修改属性基础值
func modify_base_value(attribute_name:StringName,modify_value:float,source:Variant = null) -> bool:
	var attr:Attribute = get_attribute(attribute_name)
	if not attr:
		return false
	return set_base_value(attribute_name,attr.get_base_value() + modify_value,source)
	
#像指定属性应用一个modifier
func apply_modifier(modifier:AttributeModifiers,source_ID:int) -> void:
	var attr:Attribute =get_attribute(modifier.attribute_ID)
	if not attr or not modifier:
		return
	if attr.get_active_modifier().has(modifier):
		printerr("属性修改 's%' 已经存在与属性 's%'。" % [modifier,modifier.attribute_iD])
		return
	modifier.source_ID = source_ID
	attr.add_modifier_internal(modifier) #添加到属性实例列表
	
#从指定属性移除一个modifier（通过modifier实例或者source_ID）
func remove_modifier(modifier_instance:AttributeModifiers,source_ID:int) -> void:
	if not is_instance_valid(modifier_instance):
		return
	var attr:Attribute = get_attribute(modifier_instance.attribute_ID)
	if not attr:
		return
	#直接调用内部方法
	attr.remove_modifier_internal(modifier_instance)
	
#通过来源ID匹配改ID所有的修改器
func remove_modifier_by_source_ID(source_ID:int) ->void:
	for attr in _initialized_attributes.values():
		for i in range(attr._active_modifiers.size() - 1, -1, -1):
			var modifier = attr._active_modifiers[i]
			if modifier.source_ID == source_ID:
				attr.remove_modifier_internal(modifier)
#钩子函数（虚拟方法，由具体业务逻辑的AttributeSet子类重写）

#在属性基础值要被修改前调用
#返回值：float - 修改后的新基础属性；或bool（false表示阻止修改）
func _pre_base_value_change(attribute_intance:Attribute,old_base_value:float,proposed_new_base_value:float,_source:Variant) -> Variant:
	var final_value =proposed_new_base_value
	#钳制当前生命值不会超过最大生命值
	if attribute_intance.attribute_name == &"CurrentHp":
		var max_hp_attr = get_attribute(&"MaxHp")
		if max_hp_attr:
			final_value = clamp(final_value,attribute_intance.min_value,max_hp_attr.get_current_value())
	return proposed_new_base_value
		
#在属性基础值已经被修改后调用
func _post_base_value_change(_attribute_instance:Attribute,_old_base_value:float,_new_base_value:float,_source:Variant) ->void:
	#默认实现：什么也不做
	#子类可以重写，例如当“最大生命值”变化时候，可能需要按差值或比例修改当前生命值
	pass

#在属性的当前值已经被修改并最终确认后调用
func _pre_current_value_change(_arrtibute_instance:Attribute,_old_current_value:float,proposed_new_current_value:float,_source:Variant) ->Variant:
	#其他通过钳制（基于属性自定义）已在attribute.recalculate_current_value()中调用
	#但是这里可以添加更复杂，跨属性或特定AttributeSet的钳制逻辑
	return proposed_new_current_value

#当属性的当前值已经被修改并最终确认后调用
func _post_current_value_change(_attribute_instance:Attribute,_old_current_value:float,_new_current_value:float,_source:Variant) ->void:
	#默认实现：什么也不做
	#子类可以重写，例如如果：
	#如果生命值为0，则角色死亡
	#如果某个属性增加到一定值，则添加另一个状态
	print("PostChange %s: from %s to %s (Source: %s)" % [_attribute_instance.attribute_name,_old_current_value,_new_current_value,_source])
	pass

#基础类提供一个常见的默认实现
func _on_resolve_inital_value_dependencies() ->void:
	#默认实现：同步当前血量/最大血量，当前魔力/最大魔力
	var current_hp_attr:Attribute = get_attribute(&'CurrentHp')
	var max_hp_attr:Attribute = get_attribute(&'MaxHp')
	
	if current_hp_attr and max_hp_attr:
		current_hp_attr.set_base_value_internal(max_hp_attr.get_base_value())
	
	var current_mp_attr:Attribute = get_attribute(&'CurrentMana')
	var max_mp_attr:Attribute = get_attribute(&'MaxMana')
	
	if current_mp_attr and max_mp_attr:
		current_mp_attr.set_base_value_internal(max_mp_attr.get_base_value())
		
	
	
		
		
