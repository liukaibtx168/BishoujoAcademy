extends Resource
class_name AttributeModifiers

#枚举修改器可能执行的操作行为类型
enum ModifiersOperation {
	ADD_ABSOLUTE,                        #增加一个固定值，如果增加的值为负数则为减少（例如：+10攻击力，-10防御力）
	ADD_PERCENTAHE,                      #基于基础属性的百分比乘法计算（例如：+20%基础生命）
	OVERRIDE                             #直接进行覆盖操作（例如：速度设置为0）
}

#修改的属性ID
@export var  attribute_ID:StringName = &""
#修改幅度的定义（10，-10,2,0.5）
@export var magnitude:float = 0.0
#修改的操作类型
@export var operation:ModifiersOperation = ModifiersOperation.ADD_ABSOLUTE
#可选备用的变量，用于记录修改器来源标示（如装备，buff，称号）
#用于调试或外部系统对来特定来源的modifier进行控制
@export var source_ID:int = 0

func _init(
		p_attribute_ID:StringName = &"",
		p_magnitude:float = 0.0,
		p_operation:ModifiersOperation = ModifiersOperation.ADD_ABSOLUTE,
		p_source_ID:int = 0) -> void:
	attribute_ID = p_attribute_ID
	magnitude = p_magnitude
	operation = p_operation
	source_ID = p_source_ID

func  set_source(p_source_ID:int) -> void:
	source_ID = p_source_ID
