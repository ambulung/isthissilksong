# enemy.gd (or whatever your enemy script is named)
extends CharacterBody2D # Or RigidBody2D, etc.

var health = 100

func take_damage(amount: int):
	health -= amount
	print("Enemy took ", amount, " damage. Health: ", health)
	if health <= 0:
		print("Enemy defeated!")
		queue_free() # Remove enemy if health is 0
