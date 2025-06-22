extends GPUParticles2D

func _ready():
    # Start emitting particles as soon as the node is ready
    emitting = true
    
    # Create a timer to delete this node after all particles have lived their life
    # The timer duration should be slightly longer than the particle lifetime
    # to ensure all particles have disappeared.
    var timer = get_tree().create_timer(lifetime - 0.2) 
    timer.timeout.connect(queue_free)
