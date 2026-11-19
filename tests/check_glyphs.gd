extends SceneTree
## Every character the HUD draws must come from a real font on this machine, not the missing-glyph box:
## the bundled family covers the letters, the system symbol fallback the marks. (Godot's own system fallback
## still applies behind ours, so this fails only where no installed font has the glyph.)

const MARKS := "⇄✦◆⚔▲▸·»“”"
const TEXT := "AWAKENING THE WARDEN'S GATE Its guard faces forward. 0/4 "


func _init() -> void:
	var ts := TextServerManager.get_primary_interface()
	var failed := 0
	for weight in ["medium", "demibold", "bold", "heavy"]:
		var font := SkLabel.font_for(weight)
		var line := TextLine.new()
		line.add_string(TEXT + MARKS, font, 16)
		var missing := ""
		for g in ts.shaped_text_get_glyphs(line.get_rid()):
			if not (g.font_rid as RID).is_valid() or int(g.index) == 0:
				missing += char(int(g.index)) if not (g.font_rid as RID).is_valid() else "?"
		if missing != "":
			print("FAIL %s: no font for [%s]" % [weight, missing])
			failed += 1
	print("symbol fallback resolves to: %s" % (SkLabel.symbols() as SystemFont).get_font_name())
	print("glyphs: %d weights checked, %d failed (%s)" % [4, failed, OS.get_name()])
	quit(1 if failed > 0 else 0)
