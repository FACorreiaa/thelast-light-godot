class_name Settings
extends RefCounted
## What the player can change in Settings. Port of Settings.swift, kept in user://settings.cfg.

enum Difficulty { STORY, NORMAL, HARD }

const DIFFICULTY_IDS := ["story", "normal", "hard"]
const DIFFICULTY_NAMES := ["Story", "Normal", "Hard"]
## How much of an enemy's damage reaches a hero.
const DAMAGE_TAKEN := [0.5, 1.0, 1.5]

var volume := 0.7
var haptics := true
var screen_shake := true
var debug_overlay := false
var difficulty := Difficulty.NORMAL


func damage_taken() -> float:
	return DAMAGE_TAKEN[difficulty]


func copy() -> Settings:
	var s := Settings.new()
	s.volume = volume
	s.haptics = haptics
	s.screen_shake = screen_shake
	s.debug_overlay = debug_overlay
	s.difficulty = difficulty
	return s


static func load_saved() -> Settings:
	var s := Settings.new()
	var cfg := ConfigFile.new()
	if cfg.load(SaveDir.path("settings.cfg")) != OK:
		return s
	s.volume = float(cfg.get_value("settings", "volume", s.volume))
	s.haptics = bool(cfg.get_value("settings", "haptics", s.haptics))
	s.screen_shake = bool(cfg.get_value("settings", "shake", s.screen_shake))
	s.debug_overlay = bool(cfg.get_value("settings", "debug", false))
	var d := DIFFICULTY_IDS.find(String(cfg.get_value("settings", "difficulty", "normal")))
	s.difficulty = (d if d >= 0 else Difficulty.NORMAL) as Difficulty
	return s


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "haptics", haptics)
	cfg.set_value("settings", "shake", screen_shake)
	cfg.set_value("settings", "debug", debug_overlay)
	cfg.set_value("settings", "difficulty", DIFFICULTY_IDS[difficulty])
	cfg.save(SaveDir.path("settings.cfg"))
