tool
extends EditorPlugin


var import_plugin


func _enter_tree():
	var path = "%s/Importer.gd" % self.get_script().get_path().get_base_dir()
	import_plugin = load(path).new()
	add_import_plugin(import_plugin)


func _exit_tree():
	remove_import_plugin(import_plugin)
	import_plugin = null
