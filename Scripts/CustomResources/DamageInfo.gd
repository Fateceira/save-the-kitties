extends Resource
class_name DamageInfo

var amount: int
var is_crit: bool
var pierce: int

func _init(amount: int, is_crit: bool = false, pierce: int = 0):
	self.amount = amount
	self.is_crit = is_crit
	self.pierce = pierce
