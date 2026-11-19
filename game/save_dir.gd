class_name SaveDir
extends RefCounted
## Where settings, progress and story decisions are kept. Tests point this somewhere of their own so a
## run never touches a real save.

static var root := "user://"


static func path(file: String) -> String:
	DirAccess.make_dir_recursive_absolute(root)
	return root.path_join(file)
