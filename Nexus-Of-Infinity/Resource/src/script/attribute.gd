extends Resource
class_name Attribute

#定义属性名称，属性唯一标示
@export var attribute_name:StringName = &""
#定义属性名称，属性对外显示
@export var attribute_dispaly_name:String = ""
#定义属性描述
@export_multiline var attribute_description:String = ""
#属性允许的最小值
@export var min_value:= -INF
#属性允许的最大值
@export var max_value:= INF
#属性值是否可以为负数
@export var can_be_negative: = false
#属性基础值，用于创建实例
@export var base_value:float = 0.0:
	set(value):
		var old_value = base_value
		base_value = value
		base_value_changed.emit(old_value,value)
#属性当前值，计算得出，无需设置
var current_value:float = 0.0:
	set(value):
		var old_value = current_value
		current_value = value
		current_value_changed.emit(old_value,value)
#储存当前作用于此属性实例的修改行为数组：AttributeModifier="属性修改器"
var _active_modifiers:Array[AttributeModifiers] = []
#对父级AttributeSet="属性设置"的引用
var _owner_set:AttributeSet = null

signal base_value_changed(old_value,new_value)
signal current_value_changed(old_value,new_value)

func _init(p_owner_set:AttributeSet = null,p_base_value_override:float = -1.0) -> void:
	_owner_set = p_owner_set
	#允许实例化的时候覆盖基础数值
	if p_base_value_override != -1.0:
		base_value = p_base_value_override
	else:
		pass

func get_active_modifier() -> Array[AttributeModifiers]:
	return _active_modifiers

#（由AttributeSet="属性设置"调用）添加一个修改行为并重新计算当前值
func add_modifier_internal(modifier:AttributeModifiers):
	if not modifier in _active_modifiers:#判断数组中是否有相同的修改行为，避免重复执行
		_active_modifiers.append(modifier)
		_recalculate_current_value() 
		#对某个属性的修改行为，同一个属性可能被多个行为影响，记录其行为方便属性动态变化的管理
		print("添加修改行为：%s 到 %s" % [modifier,attribute_name])

#（由AttributeSet="属性设置"调用）移出一个修改行为并重新计算当前值
func remove_modifier_internal(modifier:AttributeModifiers):
	if not modifier in _active_modifiers:#判断数组中是否有相同的修改行为，避免重复执行
		_active_modifiers.erase(modifier)
		_recalculate_current_value() 
		#对某个属性的修改行为，同一个属性可能被多个行为影响，记录其行为方便属性动态变化的管理
		print("移除修改行为：%s 从 %s" % [modifier,attribute_name])

#（由AttributeSet="属性设置"调用）设置基础值，重新计算当前值
func set_base_value_internal(new_base_value:float) -> void:
	base_value = new_base_value
	_recalculate_current_value()

#获取当前计算出来的值
func get_current_value() -> float:
	return current_value

#设置所属AttributeSet="属性设置"（在AttributeSet="属性设置"中实例化此属性时调用）
func set_owner_set(owner:AttributeSet):
	_owner_set = owner

#计算逻辑的思路：
#1.对基础值进行固定值计算，加减法
#2.基于基础值进行不同乘区的计算，如装备、技能、buff、光环等
#3.判断是否有覆盖类型的数值，理论上来说覆盖某个属性是优先级最高的，通常也用于一些比较特殊的效果
#4.对计算的数值进行牵制，使其满足正负条件，最大/最小值条件
#5.最后返回基础值是否发生变化的判断，用于其他判断条件的依据

#基于基础属性和所有的修改行为，对属性进行计算，得出最终的当前属性
func _recalculate_current_value() ->bool:
	var before_current_value = current_value
	var value_after_addtive_mods = base_value #用于计算正常值的变化
	var addtive_bonus:float = 0.0
	var multiply_percentage_total_bonus:float = 1.0 #乘法计算的基础值为1
	
	#步骤1:计算有固定数值的增减(先对基础数值固定值变化的计算，武器增加20点攻击力，被动增加10点攻击力)
	for modifier in _active_modifiers:
		if modifier.operation == AttributeModifiers.ModifiersOperation.ADD_ABSOLUTE:
			addtive_bonus += modifier.magnitude
	
	value_after_addtive_mods += base_value + addtive_bonus
	
	#步骤2：计算基于“当前累计值”的百分比修改（多个乘区直接连续计算，例如：技能造成150%伤害，暴击造成150%伤害，buff增加20%伤害）
	for modifier in _active_modifiers:
		if modifier.operation == AttributeModifiers.ModifiersOperation.ADD_PERCENTAHE:
			multiply_percentage_total_bonus *= (1.0 + modifier.magnitude)
	
	var final_value = value_after_addtive_mods * multiply_percentage_total_bonus

	#步骤3：覆盖类型的修改（如速度设置为0，防御设置为0等）
	var override_value:float = NAN  #定义一个覆盖的值，默认是一个非数字的数
	for modifier in _active_modifiers: #这里做了简单的比较处理，将修改器中的值进行比较，最大的值作为最终值
		if modifier.operation == AttributeModifiers.ModifiersOperation.OVERRIDE:
			var temp_override_value: float = modifier.magnitude  # 创建临时变量
			# 取较大的值给override_value
			if is_nan(temp_override_value) and abs(temp_override_value) > abs(override_value): 
				override_value = temp_override_value

	if not is_nan(override_value):   #如果override_value是一个数值类型，则最终值被覆盖
		final_value = override_value

	#步骤4：最终数值的钳制，如果不能为负数则取0
	var clamped_value = final_value
	if can_be_negative == false and clamped_value < 0.0:
		clamped_value = 0.0
	
	clamped_value = clampf(clamped_value,min_value,max_value)
	
	#更新当前值
	current_value = clamped_value

	#返回值，计算下来的最终属性和计算前的属性是否有变化
	return current_value != before_current_value
