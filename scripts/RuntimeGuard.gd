extends Node

var game: Node
var gallery: Node
var last_inventory_size := 0
var initialized := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_initialize")

func _initialize() -> void:
    await get_tree().process_frame
    if game == null:
        return
    var inv = game.get("inventory")
    if typeof(inv) == TYPE_ARRAY:
        last_inventory_size = inv.size()
    initialized = true
    _inject_home_art_button()

func _process(_delta: float) -> void:
    if not initialized or game == null or not is_instance_valid(game):
        return
    _refund_new_duplicates()
    _inject_home_art_button()

func _refund_new_duplicates() -> void:
    var inv = game.get("inventory")
    if typeof(inv) != TYPE_ARRAY:
        return
    if inv.size() <= last_inventory_size:
        last_inventory_size = inv.size()
        return

    var seen := {}
    var duplicate_indexes: Array = []
    for i in range(inv.size()):
        var unit = inv[i]
        if typeof(unit) != TYPE_DICTIONARY:
            continue
        var def_id := int(unit.get("def_id", -1))
        if seen.has(def_id):
            duplicate_indexes.append(i)
        else:
            seen[def_id] = true

    if duplicate_indexes.is_empty():
        last_inventory_size = inv.size()
        return

    duplicate_indexes.reverse()
    for index in duplicate_indexes:
        inv.remove_at(int(index))
        game.set("gems", int(game.get("gems")) + 5)

    _repair_squad_after_refund(inv.size())
    game.set("inventory", inv)
    if game.has_method("_save"):
        game.call("_save")
    if game.has_method("_refresh"):
        game.call("_refresh")
    last_inventory_size = inv.size()
    _show_toast("DUPLICATE UNIT • 5 GEMS REFUNDED")

func _repair_squad_after_refund(inv_size: int) -> void:
    var squad = game.get("squad")
    if typeof(squad) != TYPE_ARRAY or inv_size <= 0:
        return
    for i in range(squad.size()):
        squad[i] = clampi(int(squad[i]), 0, inv_size - 1)
    game.set("squad", squad)

func _inject_home_art_button() -> void:
    if gallery == null or not is_instance_valid(gallery):
        return
    var body = game.get("body")
    if body == null or not is_instance_valid(body):
        return

    var has_quests := false
    var has_summon := false
    var has_art := false
    for child in body.get_children():
        if child is Button:
            var text := str(child.text)
            if text.contains("QUESTS"):
                has_quests = true
            if text.contains("SUMMON GATE"):
                has_summon = true
            if text.contains("ORIGINAL ART"):
                has_art = true
    if not has_quests or not has_summon or has_art:
        return

    var button := Button.new()
    button.text = "🖼  ORIGINAL BRAVE FRONTIER ART"
    button.custom_minimum_size = Vector2(0, 82)
    button.add_theme_font_size_override("font_size", 20)
    button.pressed.connect(func(): gallery.call("_open_gallery"))
    var style := StyleBoxFlat.new()
    style.bg_color = Color("5a327e")
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_left = 14
    style.corner_radius_bottom_right = 14
    button.add_theme_stylebox_override("normal", style)

    var insert_at := mini(3, body.get_child_count())
    body.add_child(button)
    body.move_child(button, insert_at)

func _show_toast(message: String) -> void:
    var layer := CanvasLayer.new()
    layer.layer = 100
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(70, 90)
    panel.size = Vector2(580, 92)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("3d274f")
    style.corner_radius_top_left = 16
    style.corner_radius_top_right = 16
    style.corner_radius_bottom_left = 16
    style.corner_radius_bottom_right = 16
    panel.add_theme_stylebox_override("panel", style)
    layer.add_child(panel)
    var label := Label.new()
    label.text = message
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 22)
    panel.add_child(label)
    await get_tree().create_timer(2.2).timeout
    if is_instance_valid(layer):
        layer.queue_free()
