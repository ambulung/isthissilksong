# one_shot_audio.gd
extends AudioStreamPlayer2D

# This function will be called externally to set up and play the sound.
func fire(audio_stream: AudioStream, p_pitch_scale: float = 1.0):
    # Assign the sound file to play
    stream = audio_stream
    
    # Set the pitch
    pitch_scale = p_pitch_scale
    
    # Play the sound
    play()
    
    # Connect the "finished" signal to this node's queue_free method.
    # This will automatically delete the node after the sound has finished playing.
    finished.connect(queue_free)
