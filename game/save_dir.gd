class_name SaveDir
extends RefCounted
## Where settings, progress and story decisions are kept. Tests point this somewhere of their own so a
## run never touches a real save.

## `--save-dir DIR` on the command line (after `--`) uses another folder, for checks that need a fresh save.
static var root := _from_args()


static func _from_args() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--save-dir")
	return args[i + 1] if i >= 0 and i + 1 < args.size() else "user://"


static func path(file: String) -> String:
	DirAccess.make_dir_recursive_absolute(root)
	return root.path_join(file)
