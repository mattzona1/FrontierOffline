extends Control

const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("9fb0ca")
const SAVE_VERSION := 5
var status_label: Label

func _ready() -> void:
    _add_visual_backdrop()
    _draw_boot_screen()
    call_deferred("_boot_game")

func _add_visual_backdrop() -> void:
    var backdrop_script = load("res://scripts/VisualBackdrop.gd")
    if backdrop_script == null: return
    var backdrop := Control.new()
    backdrop.set_script(backdrop_script)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)
    move_child(backdrop, 0)

func _draw_boot_screen() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 24
    root.offset_right = -24
    root.offset_top = 80
    root.offset_bottom = -80
    root.alignment = BoxContainer.ALIGNMENT_CENTER
    root.add_theme_constant_override("separation", 18)
    add_child(root)
    var title := Label.new(); title.text = "BRAVE FRONTIER"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",46); title.add_theme_color_override("font_color",GOLD); root.add_child(title)
    var sub := Label.new(); sub.text = "OFFLINE REBUILD"; sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sub.add_theme_font_size_override("font_size",20); sub.add_theme_color_override("font_color",MUTED); root.add_child(sub)
    status_label = Label.new(); status_label.text = "Loading Grand Gaia..."; status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; status_label.add_theme_font_size_override("font_size",19); status_label.add_theme_color_override("font_color",TEXT); root.add_child(status_label)
    var bar := ProgressBar.new(); bar.max_value=100;bar.value=28;bar.custom_minimum_size=Vector2(520,28);bar.show_percentage=false;root.add_child(bar)
    var tip := Label.new(); tip.text="Loading bundled battle art...";tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;tip.add_theme_font_size_override("font_size",14);tip.add_theme_color_override("font_color",Color("8399b6"));root.add_child(tip)

func _boot_game() -> void:
    await get_tree().create_timer(0.35).timeout
    status_label.text = "Preparing offline unit archive..."
    _start_asset_cache()
    await get_tree().create_timer(0.30).timeout
    var script = load("res://scripts/BraveMain.gd")
    if script == null:
        status_label.text = "Recovery mode: core shell failed to load."
        return
    status_label.text = "Entering Grand Gaia..."
    await get_tree().create_timer(0.30).timeout
    var game := Control.new()
    game.set_script(script)
    game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(game)
    await get_tree().process_frame
    _start_first_quest_accuracy(game)
    await get_tree().process_frame
    _start_ui_enhancer(game)
    _start_battle_scene(game)
    if is_instance_valid(status_label):
        var boot_root := status_label.get_parent()
        if is_instance_valid(boot_root): boot_root.queue_free()

func _start_asset_cache() -> void:
    var cache_script = load("res://scripts/AssetCacheService.gd")
    if cache_script == null: return
    var service := Node.new(); service.set_script(cache_script); add_child(service)

func _start_first_quest_accuracy(game: Node) -> void:
    var accuracy_script = load("res://scripts/FirstQuestAccuracy.gd")
    if accuracy_script == null: return
    var service := Node.new()
    service.set_script(accuracy_script)
    service.set("game", game)
    add_child(service)

func _start_ui_enhancer(game: Node) -> void:
    var ui_script = load("res://scripts/BraveUIEnhancer.gd")
    if ui_script == null: return
    var enhancer := Node.new(); enhancer.set_script(ui_script); enhancer.set("game",game); add_child(enhancer)

func _start_battle_scene(game: Node) -> void:
    var battle_script = load("res://scripts/BraveBattleScene.gd")
    if battle_script == null: return
    var scene := Control.new()
    scene.set_script(battle_script)
    scene.set("game", game)
    scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(scene)