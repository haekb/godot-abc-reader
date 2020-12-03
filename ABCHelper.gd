extends Spatial

signal animation_command_string

func run_command_string(command_string : String):	
	emit_signal("animation_command_string", command_string)
# End Func
