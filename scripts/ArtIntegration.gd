extends Node

# Integrates the six cached original BF1 starter artworks into the live game UI.
# The artwork itself is downloaded/cached by AssetGallery.gd from the official library.

var game: Node
var gallery: Node
var last_signature := ""
var tick := 0.0

const STARTERS := [
    {"def_id":0,"name":"Vargas","title":"Fencer Vargas","element":"Fire","cache":"vargas_official.png"},
    {"def_id":1,"name":"Selena","title":"Ice Selena","element":"Water","cache":"selena_official.png"},
    {"def_id":2,"name":"Lance","title":"Lancer Lance","element":"Earth","cache":"lance_official.png"},
    {"def_id":3,"name":"Eze","title":"Warrior Eze","element":"Thunder","cache":"eze_official.png"},
    {"def_id":4,"name":"Atro","title":"Light Atro","element":"Light","cache":"atro_official.png"},
    {"def_id":5,"name":"Magress","title":"Iron Magress","element":"Dark","cache":"magress_official.png"}
]

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_apply_unit_identity")
    call_deferred("_refresh_visuals")

func _process(delta: float) -> void:
    tick += delta
    if tick < 0.22:
        return
    tick = 0.0
    if game == null or not is_instance_valid(game):
        return
    _apply_unit_identity()
    var sig := _screen_signature()
    if sig != last_signature:
        last_signature = sig
        call_deferred("_refresh_visuals")

func _apply_unit_identity() -> void:
    if game == null or not is_instance_valid(game):
        return
    var defs = game.get("unit_defs")
    if typeof(defs) != TYPE_ARRAY or defs.size() < 6:
        return
    for item in STARTERS:
        var d = defs[int(item["def_id"])]
        if typeof(d) != TYPE_DICTIONARY:
            continue
        d["name"] = item["name"]
        d["title"] = item["title"]
        d["element"] = item["element"]

func _body() -> Node:
    if game == null or not is_instance_valid(game):
        return null
    return game.get("body")

func _screen_signature() -> String:
    var body := _body()
    if body == null:
        return ""
    var parts: Array[String] = []
    for c in body.get_children():
        if c is Label:
            parts.append(c.text.left(60))
        elif c is Button:
            parts.append(c.text.left(60))
        elif c is PanelContainer:
            parts.append("panel")
    return "|".join(parts)

func _refresh_visuals() -> void:
    await get_tree().process_frame
    var body := _body()
    if body == null:
        return
    _remove_old_visuals(body)
    var screen := _detect_screen(body)
    match screen:
        "home": _decorate_home(body)
        "units": _decorate_units(body)
        "unit_details": _decorate_unit_details(body)
        "squad": _decorate_squad(body)
        "choose": _decorate_choose(body)
        "summon": _decorate_summon(body)
        "summon_result": _decorate_summon_result(body)
        "battle": _decorate_battle(body)
        "training": _decorate_training(body)

func _remove_old_visuals(body: Node) -> void:
    for child in body.get_children():
        if child.has_meta("bf_art_integration"):
            child.queue_free()

func _detect_screen(body: Node) -> String:
    var text := ""
    for c in body.get_children():
        if c is Label or c is Button:
            text += "\n" + str(c.text)
    if text.contains("SUMMON RESULT"):
        return "summon_result"
    if text.contains("SUMMON GATE"):
        return "summon"
    if text.contains("UNIT INVENTORY"):
        return "units"
    if text.contains("CHOOSE UNIT"):
        return "choose"
    if text.contains("Six active slots") or text.contains("SQUAD") and text.contains("LEADER"):
        return "squad"
    if text.contains("TRAINING GOLEM") and text.contains("TARGET HP"):
        return "training"
    if text.contains("HP") and text.contains("BB") and (text.contains("RETREAT") or text.contains("RESET TARGET")):
        return "battle"
    if text.contains("Leader:") and text.contains("XP"):
        return "unit_details"
    if text.contains("QUESTS") and text.contains("TRAINING HALL") and text.contains("TESTER GEM CONSOLE"):
        return "home"
    return ""

func _decorate_home(body: Node) -> void:
    var title := _section_label("CLASSIC HERO SQUAD", "Original BF1 starter art • cached offline")
    _insert_after_header(body, title)
    var row := HBoxContainer.new()
    _mark(row)
    row.add_theme_constant_override("separation", 4)
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var squad = game.get("squad")
    var inventory = game.get("inventory")
    if typeof(squad) == TYPE_ARRAY and typeof(inventory) == TYPE_ARRAY:
        for s in range(mini(6, squad.size())):
            var inv_idx := int(squad[s])
            if inv_idx >= 0 and inv_idx < inventory.size():
                var def_id := int(inventory[inv_idx].get("def_id", -1))
                row.add_child(_portrait_card(def_id, Vector2(102, 128), true))
    _insert_after_node(body, title, row)

func _decorate_units(body: Node) -> void:
    var grid := GridContainer.new()
    _mark(grid)
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var inventory = game.get("inventory")
    if typeof(inventory) == TYPE_ARRAY:
        for i in range(inventory.size()):
            var def_id := int(inventory[i].get("def_id", -1))
            if def_id >= 0 and def_id < 6:
                grid.add_child(_portrait_card(def_id, Vector2(210, 210), true))
    _insert_after_heading(body, "UNIT INVENTORY", grid)

func _decorate_unit_details(body: Node) -> void:
    var selected := int(game.get("selected"))
    var inventory = game.get("inventory")
    if typeof(inventory) != TYPE_ARRAY or selected < 0 or selected >= inventory.size():
        return
    var def_id := int(inventory[selected].get("def_id", -1))
    if def_id < 0 or def_id >= 6:
        return
    var portrait := _portrait_card(def_id, Vector2(0, 430), false)
    portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _insert_after_first_panel(body, portrait)

func _decorate_squad(body: Node) -> void:
    var row := HBoxContainer.new()
    _mark(row)
    row.add_theme_constant_override("separation", 5)
    var squad = game.get("squad")
    var inventory = game.get("inventory")
    if typeof(squad) == TYPE_ARRAY and typeof(inventory) == TYPE_ARRAY:
        for s in range(mini(6, squad.size())):
            var inv_idx := int(squad[s])
            var def_id := -1
            if inv_idx >= 0 and inv_idx < inventory.size():
                def_id = int(inventory[inv_idx].get("def_id", -1))
            var card := _portrait_card(def_id, Vector2(105, 145), true)
            if s == 0:
                var leader := Label.new()
                leader.text = "LEADER"
                leader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                leader.add_theme_font_size_override("font_size", 11)
                card.add_child(leader)
            row.add_child(card)
    _insert_after_heading(body, "SQUAD", row)

func _decorate_choose(body: Node) -> void:
    var grid := GridContainer.new()
    _mark(grid)
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 7)
    grid.add_theme_constant_override("v_separation", 7)
    var inventory = game.get("inventory")
    if typeof(inventory) == TYPE_ARRAY:
        for u in inventory:
            var def_id := int(u.get("def_id", -1))
            if def_id >= 0 and def_id < 6:
                grid.add_child(_portrait_card(def_id, Vector2(210, 190), true))
    _insert_after_heading(body, "CHOOSE UNIT", grid)

func _decorate_summon(body: Node) -> void:
    var banner := HBoxContainer.new()
    _mark(banner)
    banner.add_theme_constant_override("separation", 3)
    for i in range(6):
        banner.add_child(_portrait_card(i, Vector2(105, 150), false))
    _insert_after_first_panel(body, banner)

func _decorate_summon_result(body: Node) -> void:
    var chosen := _infer_result_def_id(body)
    if chosen < 0 or chosen >= 6:
        return
    var art := _portrait_card(chosen, Vector2(0, 500), false)
    art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _insert_after_first_panel(body, art)

func _decorate_battle(body: Node) -> void:
    var strip := HBoxContainer.new()
    _mark(strip)
    strip.add_theme_constant_override("separation", 4)
    var squad = game.get("squad")
    var inventory = game.get("inventory")
    if typeof(squad) == TYPE_ARRAY and typeof(inventory) == TYPE_ARRAY:
        for s in range(mini(6, squad.size())):
            var inv_idx := int(squad[s])
            var def_id := -1
            if inv_idx >= 0 and inv_idx < inventory.size():
                def_id = int(inventory[inv_idx].get("def_id", -1))
            strip.add_child(_portrait_card(def_id, Vector2(105, 135), false))
    _insert_after_battle_log(body, strip)

func _decorate_training(body: Node) -> void:
    var row := HBoxContainer.new()
    _mark(row)
    row.add_theme_constant_override("separation", 4)
    var squad = game.get("squad")
    var inventory = game.get("inventory")
    if typeof(squad) == TYPE_ARRAY and typeof(inventory) == TYPE_ARRAY:
        for s in range(mini(6, squad.size())):
            var inv_idx := int(squad[s])
            var def_id := int(inventory[inv_idx].get("def_id", -1)) if inv_idx >= 0 and inv_idx < inventory.size() else -1
            row.add_child(_portrait_card(def_id, Vector2(105, 130), false))
    _insert_after_first_panel(body, row)

func _infer_result_def_id(body: Node) -> int:
    var txt := ""
    for c in body.get_children():
        if c is Label or c is Button:
            txt += " " + str(c.text)
    for item in STARTERS:
        if txt.contains(str(item["name"])):
            return int(item["def_id"])
    var inventory = game.get("inventory")
    if typeof(inventory) == TYPE_ARRAY and not inventory.is_empty():
        return int(inventory[inventory.size()-1].get("def_id", -1))
    return -1

func _portrait_card(def_id: int, min_size: Vector2, show_name: bool) -> VBoxContainer:
    var card := VBoxContainer.new()
    card.custom_minimum_size = min_size
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var frame := PanelContainer.new()
    frame.custom_minimum_size = Vector2(min_size.x, maxf(90.0, min_size.y - (28.0 if show_name else 0.0)))
    var style := StyleBoxFlat.new()
    style.bg_color = Color("101827")
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    style.corner_radius_bottom_left = 10
    style.corner_radius_bottom_right = 10
    if def_id >= 0 and def_id < 6:
        style.border_color = _element_color(str(STARTERS[def_id]["element"]))
    else:
        style.border_color = Color("52677e")
    frame.add_theme_stylebox_override("panel", style)
    card.add_child(frame)
    var tex := TextureRect.new()
    tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tex.custom_minimum_size = frame.custom_minimum_size
    tex.texture = _load_texture(def_id)
    frame.add_child(tex)
    if show_name:
        var label := Label.new()
        label.text = str(STARTERS[def_id]["name"]) if def_id >= 0 and def_id < 6 else "Unit"
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 13)
        card.add_child(label)
    return card

func _load_texture(def_id: int) -> Texture2D:
    if def_id >= 0 and def_id < 6:
        var path := "user://bf_assets/%s" % STARTERS[def_id]["cache"]
        if FileAccess.file_exists(path):
            var img := Image.new()
            if img.load(ProjectSettings.globalize_path(path)) == OK:
                return ImageTexture.create_from_image(img)
    var gradient := GradientTexture2D.new()
    var g := Gradient.new()
    var c := Color("52677e")
    if def_id >= 0 and def_id < 6:
        c = _element_color(str(STARTERS[def_id]["element"]))
    g.colors = PackedColorArray([c, Color("0b1220")])
    gradient.gradient = g
    gradient.width = 256
    gradient.height = 256
    return gradient

func _section_label(title: String, subtitle: String) -> VBoxContainer:
    var box := VBoxContainer.new()
    _mark(box)
    var h := Label.new()
    h.text = title
    h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.add_theme_font_size_override("font_size", 20)
    h.add_theme_color_override("font_color", Color("f2c14e"))
    box.add_child(h)
    var s := Label.new()
    s.text = subtitle
    s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    s.add_theme_font_size_override("font_size", 12)
    s.add_theme_color_override("font_color", Color("a9bbd3"))
    box.add_child(s)
    return box

func _mark(node: Node) -> void:
    node.set_meta("bf_art_integration", true)

func _insert_after_header(body: Node, node: Node) -> void:
    body.add_child(node)
    body.move_child(node, mini(2, body.get_child_count()-1))

func _insert_after_node(body: Node, anchor: Node, node: Node) -> void:
    body.add_child(node)
    var idx := anchor.get_index() + 1
    body.move_child(node, mini(idx, body.get_child_count()-1))

func _insert_after_heading(body: Node, heading_text: String, node: Node) -> void:
    body.add_child(node)
    for c in body.get_children():
        if c is Label and c.text.contains(heading_text):
            body.move_child(node, mini(c.get_index()+2, body.get_child_count()-1))
            return
    body.move_child(node, 0)

func _insert_after_first_panel(body: Node, node: Node) -> void:
    body.add_child(node)
    for c in body.get_children():
        if c is PanelContainer and not c.has_meta("bf_art_integration"):
            body.move_child(node, mini(c.get_index()+1, body.get_child_count()-1))
            return
    body.move_child(node, 0)

func _insert_after_battle_log(body: Node, node: Node) -> void:
    body.add_child(node)
    var panel_seen := false
    for c in body.get_children():
        if c is PanelContainer:
            panel_seen = true
        elif panel_seen and c is Label:
            body.move_child(node, mini(c.get_index()+1, body.get_child_count()-1))
            return
    body.move_child(node, 1)

func _element_color(element: String) -> Color:
    match element:
        "Fire": return Color("d95145")
        "Water": return Color("348dd1")
        "Earth": return Color("4c9b58")
        "Thunder": return Color("d5ad38")
        "Light": return Color("d8c97d")
        "Dark": return Color("8a5aac")
        _: return Color("52677e")
