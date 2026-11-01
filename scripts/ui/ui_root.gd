class_name UIRoot
extends CanvasLayer
## Holds every 2D layer: vignette, HUD, touch controls, dialogue, menus, prologue and fades.

var vignette: TextureRect
var hud: HUD
var touch: TouchControls
var dialogue: DialogueBox
var title: Menus.TitleScreen
var pause_menu: Menus.PauseMenu
var settings: Menus.SettingsPanel
var ending: Menus.EndingScreen
var prologue: Prologue
var fade: ColorRect

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	vignette = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.01, 0.04, 0.03, 0.62))
	g.add_point(0.55, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.6)
	gt.fill_to = Vector2(1.1, 1.1)
	gt.width = 256
	gt.height = 256
	vignette.texture = gt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	hud = HUD.new()
	add_child(hud)
	touch = TouchControls.new()
	add_child(touch)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	title = Menus.TitleScreen.new()
	add_child(title)
	ending = Menus.EndingScreen.new()
	add_child(ending)
	ending.visible = false
	pause_menu = Menus.PauseMenu.new()
	add_child(pause_menu)
	pause_menu.visible = false
	settings = Menus.SettingsPanel.new()
	add_child(settings)
	settings.visible = false
	prologue = Prologue.new()
	add_child(prologue)
	prologue.visible = false
	fade = ColorRect.new()
	fade.color = Color(0.0, 0.0, 0.0, 1.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

func fade_to(alpha: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, duration)
	return tw

func set_gameplay_visible(v: bool) -> void:
	hud.visible = v
	touch.visible = v and (Game.is_touch_device() or OS.get_environment("ASTERION_TOUCH") == "1")
	if not v:
		touch.reset()
