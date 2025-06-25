extends Resource
class_name ShipStats

@export_group("Ship Settings")
@export var max_hp: int = 10
@export var max_speed: float = 200.0 
@export var acceleration: float = 800.0
@export var deceleration: float = 1200.0  
@export var fire_rate: float = 0.5
@export var luck: float = 0.1
@export var crit_multiplier: float = 2.0
@export var projectile_count: int = 1
@export var burst_delay: float = 0.1

@export_group("Dash Settings")
@export var dash_force: float = 500.0 
@export var dash_duration: float = 0.2 
@export var dash_cooldown: float = 1.0 
@export var max_dash_charges: int = 2
