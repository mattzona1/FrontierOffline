extends Control

const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("9fb0ca")
const PANEL := Color("101b2fdd")
const PANEL_2 := Color("223451")
const GREEN := Color("6ee7a8")
const RED := Color("ff6b6b")

var game: Node
var layer: CanvasLayer
var shade: ColorRect
var panel: PanelContainer
var content: VBoxContainer
var training_hp := 25000
var training_max_hp := 25000
var training_element := "Neutral"
var training_log: Label
var target_label: Label

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build_launcher()

func _build_launcher() -> void:
    layer = CanvasLayer.new()
    layer.layer = 50
    add_child(layer)

    var test_button := Button.new()
    test_button.text = "TEST"
    test_button.position = Vector2(590, 12)
    test_button.size = Vector2(112, 58)
    test_button.add_theme_font_size_override("font_size", 18)
    test_button.add_theme_color_override("font_color", TEXT)
    var s := StyleBoxFlat.new()
    s.bg_color = Color("5e3d99")
    s.corner_radius_top_left = 16
    s.corner_radius_top_right = 16
    s.corner_radius_bottom_left = 16
    s.corner_radius_bottom_right = 16
    test_button.add_theme_stylebox_override("normal", s)
    test_button.pressed.connect(_open_menu)
    layer.add_child(test_button)

func _open_menu() -> void:
    _close_menu()
    shade = ColorRect.new()
    shade.color = Color("00000099")
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    layer.add_child(shade)

    panel = PanelContainer.new()
    panel.position = Vector2(28, 105)
    panel.size = Vector2(664, 1050)
    var ps := StyleBoxFlat.new()
    ps.bg_color = PANEL
    ps.corner_radius_top_left = 22
    ps.corner_radius_top_right = 22
    ps.corner_radius_bottom_left = 22
    ps.corner_radius_bottom_right = 22
    ps.border_width_left = 2
    ps.border_width_top = 2
    ps.border_width_right = 2
    ps.border_width_bottom = 2
    ps.border_color = Color(GOLD, 0.45)
    panel.add_theme_stylebox_override("panel", ps)
    shade.add_child(panel)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)

    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 12)
    scroll.add_child(content)

    _title("TESTER TOOLS", "Development-only sandbox controls")
    _add_button("TRAINING AREA", _training_menu)
    _add_button("GIVE 5 GEMS", func(): _give_gems(5))
    _add_button("GIVE 50 GEMS", func(): _give_gems(50))
    _add_button("GIVE 500 GEMS", func(): _give_gems(500))
    _add_button("REFILL SQUAD BB", _max_bb)
    _add_button("CLOSE", _close_menu)

func _give_gems(amount: int) -> void:
    if game == null:
        return
    var current := int(game.get("gems"))
    game.set("gems", current + amount)
    if game.has_method("_save"):
        game.call("_save")
    if game.has_method("_refresh"):
        game.call("_refresh")
    _notice("Added %d Gems. Total: %d" % [amount, current + amount])

func _max_bb() -> void:
    if game == null:
        return
    var inv = game.get("inventory")
    var squad = game.get("squad")
    if typeof(inv) != TYPE_ARRAY or typeof(squad) != TYPE_ARRAY:
        return
    for idx in squad:
        var i := int(idx)
        if i >= 0 and i < inv.size() and typeof(inv[i]) == TYPE_DICTIONARY:
            inv[i]["bb"] = 10
    game.set("inventory", inv)
    if game.has_method("_save"):
        game.call("_save")
    _notice("Squad BB gauges filled to 10/10.")

func _training_menu() -> void:
    _clear_content()
    _title("TRAINING HALL", "No rewards, no costs, repeatable damage testing")

    target_label = Label.new()
    target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    target_label.add_theme_font_size_override("font_size", 22)
    target_label.add_theme_color_override("font_color", GOLD)
    content.add_child(target_label)
    _refresh_target()

    training_log = Label.new()
    training_log.text = "Choose a squad unit or run a full-squad attack."
    training_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    training_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    training_log.custom_minimum_size = Vector2(0, 84)
    training_log.add_theme_font_size_override("font_size", 18)
    training_log.add_theme_color_override("font_color", TEXT)
    content.add_child(training_log)

    _add_button("TARGET: 5,000 HP", func(): _set_target(5000))
    _add_button("TARGET: 25,000 HP", func(): _set_target(25000))
    _add_button("TARGET: 100,000 HP", func(): _set_target(100000))
    _add_button("CYCLE TARGET ELEMENT", _cycle_element)
    _add_button("REFILL TARGET", _refill_target)
    _add_button("REFILL ALL BB", _training_refill_bb)

    var sep := HSeparator.new()
    content.add_child(sep)
    _squad_training_buttons()
    _add_button("FULL SQUAD ATTACK", _full_squad_attack)
    _add_button("BACK TO TESTER TOOLS", _open_menu)

func _squad_training_buttons() -> void:
    if game == null:
        return
    var inv = game.get("inventory")
    var squad = game.get("squad")
    var defs = game.get("unit_defs")
    if typeof(inv) != TYPE_ARRAY or typeof(squad) != TYPE_ARRAY or typeof(defs) != TYPE_ARRAY:
        return
    for slot in range(squad.size()):
        var inv_index := int(squad[slot])
        if inv_index < 0 or inv_index >= inv.size():
            continue
        var u: Dictionary = inv[inv_index]
        var def_id := int(u.get("def_id", 0))
        if def_id < 0 or def_id >= defs.size():
            continue
        var d: Dictionary = defs[def_id]
        var label := "%s%s Lv.%d • %s" % ["LEADER • " if slot == 0 else "", d.get("name", "Unit"), int(u.get("level", 1)), d.get("element", "Neutral")]
        _add_button(label, func(s=slot): _training_attack(s, false))
        _add_button("↳ BRAVE BURST", func(s=slot): _training_attack(s, true))

func _training_attack(slot: int, use_bb: bool) -> void:
    if game == null or training_hp <= 0:
        return
    var inv = game.get("inventory")
    var squad = game.get("squad")
    var defs = game.get("unit_defs")
    if slot < 0 or slot >= squad.size():
        return
    var inv_index := int(squad[slot])
    var u: Dictionary = inv[inv_index]
    var d: Dictionary = defs[int(u.get("def_id", 0))]
    var atk := 1
    if game.has_method("_unit_atk"):
        atk = int(game.call("_unit_atk", u))
    var mult := 1.0
    if training_element != "Neutral" and game.has_method("_element_multiplier"):
        mult = float(game.call("_element_multiplier", str(d.get("element", "Neutral")), training_element))
    var damage := int(float(atk) * (1.72 if use_bb else 0.72) * mult)
    damage = maxi(1, damage)
    training_hp = maxi(0, training_hp - damage)
    training_log.text = "%s %s for %d damage%s" % [d.get("name", "Unit"), "used %s" % d.get("bb_name", "Brave Burst") if use_bb else "attacked", damage, " • TARGET DOWN" if training_hp == 0 else ""]
    _refresh_target()

func _full_squad_attack() -> void:
    if game == null or training_hp <= 0:
        return
    var inv = game.get("inventory")
    var squad = game.get("squad")
    var defs = game.get("unit_defs")
    var total := 0
    for slot in range(squad.size()):
        var inv_index := int(squad[slot])
        var u: Dictionary = inv[inv_index]
        var d: Dictionary = defs[int(u.get("def_id", 0))]
        var atk := int(game.call("_unit_atk", u)) if game.has_method("_unit_atk") else 1
        var mult := 1.0
        if training_element != "Neutral" and game.has_method("_element_multiplier"):
            mult = float(game.call("_element_multiplier", str(d.get("element", "Neutral")), training_element))
        total += maxi(1, int(float(atk) * 0.72 * mult))
    training_hp = maxi(0, training_hp - total)
    training_log.text = "Full squad dealt %d total damage%s" % [total, " • TARGET DOWN" if training_hp == 0 else ""]
    _refresh_target()

func _training_refill_bb() -> void:
    _max_bb()
    if training_log != null:
        training_log.text = "All squad BB gauges refilled."

func _set_target(hp: int) -> void:
    training_max_hp = hp
    training_hp = hp
    _refresh_target()

func _refill_target() -> void:
    training_hp = training_max_hp
    _refresh_target()
    if training_log != null:
        training_log.text = "Training target restored."

func _cycle_element() -> void:
    var elements := ["Neutral", "Fire", "Water", "Earth", "Thunder", "Light", "Dark"]
    var i := elements.find(training_element)
    training_element = elements[(i + 1) % elements.size()]
    _refresh_target()

func _refresh_target() -> void:
    if target_label != null:
        target_label.text = "Training Golem • %s\nHP %d / %d" % [training_element, training_hp, training_max_hp]

func _notice(text: String) -> void:
    _clear_content()
    _title("TESTER TOOLS", text)
    var l := Label.new()
    l.text = "Changes are saved immediately."
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", 18)
    l.add_theme_color_override("font_color", GREEN)
    content.add_child(l)
    _add_button("BACK", _open_menu)

func _title(a: String, b: String) -> void:
    var h := Label.new()
    h.text = a
    h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.add_theme_font_size_override("font_size", 30)
    h.add_theme_color_override("font_color", GOLD)
    content.add_child(h)
    var sub := Label.new()
    sub.text = b
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sub.add_theme_font_size_override("font_size", 17)
    sub.add_theme_color_override("font_color", MUTED)
    content.add_child(sub)

func _add_button(label: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(0, 72)
    b.add_theme_font_size_override("font_size", 19)
    b.add_theme_color_override("font_color", TEXT)
    var s := StyleBoxFlat.new()
    s.bg_color = PANEL_2
    s.corner_radius_top_left = 13
    s.corner_radius_top_right = 13
    s.corner_radius_bottom_left = 13
    s.corner_radius_bottom_right = 13
    b.add_theme_stylebox_override("normal", s)
    b.pressed.connect(callback)
    content.add_child(b)

func _clear_content() -> void:
    if content == null:
        return
    for child in content.get_children():
        child.queue_free()

func _close_menu() -> void:
    if is_instance_valid(shade):
        shade.queue_free()
    shade = null
    panel = null
    content = null
