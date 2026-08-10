extends Node

var game: Node
var last_page := ""
var timer := 0.0

const ROSTER := [
    {"id":6,"name":"Zelgal","title":"Beastman Zelgal","element":"Fire","cache":"zelgal_official.png"},
    {"id":7,"name":"Zephu","title":"Dragon Knight Zephu","element":"Water","cache":"zephu_official.png"},
    {"id":8,"name":"Lario","title":"Archer Lario","element":"Earth","cache":"lario_official.png"},
    {"id":9,"name":"Weiss","title":"Strategist Weiss","element":"Thunder","cache":"weiss_official.png"},
    {"id":10,"name":"Luna","title":"Radiant Luna","element":"Light","cache":"luna_official.png"},
    {"id":11,"name":"Mifune","title":"Samurai Mifune","element":"Dark","cache":"mifune_official.png"}
]

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_initialize")

func _initialize() -> void:
    await get_tree().process_frame
    if game == null or not is_instance_valid(game): return
    _apply_roster()
    if game.has_method("_home"):
        game.call("_home")
    await get_tree().process_frame
    _refresh()

func _process(delta: float) -> void:
    timer += delta
    if timer < 0.25: return
    timer = 0.0
    if game == null or not is_instance_valid(game): return
    _apply_roster()
    var title := _page()
    if title != last_page:
        last_page = title
        call_deferred("_refresh")
    elif title in ["UNITS","SQUAD","BATTLE","TRAINING","SUMMON RESULT"]:
        _replace_visible_art()

func _apply_roster() -> void:
    var defs = game.get("unit_defs")
    if typeof(defs) != TYPE_ARRAY or defs.size() < 12: return
    for item in ROSTER:
        var d = defs[int(item["id"])]
        if typeof(d) != TYPE_DICTIONARY: continue
        d["name"] = item["name"]
        d["title"] = item["title"]
        d["element"] = item["element"]
        d["cache"] = item["cache"]

func _page() -> String:
    var label = game.get("page_title")
    if label != null and is_instance_valid(label): return str(label.text)
    return ""

func _refresh() -> void:
    await get_tree().process_frame
    _style_shell()
    _add_stage_atmosphere()
    _replace_visible_art()
    match _page():
        "GRAND GAIA": _decorate_home()
        "SUMMON GATE": _decorate_summon()
        "QUESTS": _decorate_quests()
        "TRAINING HALL": _decorate_training()

func _style_shell() -> void:
    var footer = game.get("footer")
    if footer != null and is_instance_valid(footer):
        for b in footer.get_children():
            if b is Button:
                b.add_theme_font_size_override("font_size", 14)
                var normal := StyleBoxFlat.new()
                normal.bg_color = Color("162941")
                normal.border_width_top = 2
                normal.border_color = Color("355b81")
                normal.corner_radius_top_left = 10
                normal.corner_radius_top_right = 10
                b.add_theme_stylebox_override("normal", normal)
                var pressed := normal.duplicate()
                pressed.bg_color = Color("315a85")
                pressed.border_color = Color("e3bd55")
                b.add_theme_stylebox_override("pressed", pressed)
    var title = game.get("page_title")
    if title != null and is_instance_valid(title):
        title.add_theme_font_size_override("font_size", 27)
        title.add_theme_color_override("font_color", Color("f4d875"))

func _add_stage_atmosphere() -> void:
    var stage = game.get("stage")
    if stage == null or not is_instance_valid(stage): return
    for child in stage.get_children():
        if child.has_meta("bf_theme_bg"):
            child.queue_free()
    var bg := ColorRect.new()
    bg.set_meta("bf_theme_bg", true)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    match _page():
        "GRAND GAIA": bg.color = Color("0c2235")
        "QUESTS": bg.color = Color("122334")
        "SUMMON GATE", "SUMMON RESULT": bg.color = Color("1f1235")
        "BATTLE", "TRAINING": bg.color = Color("0d1d27")
        "UNITS", "SQUAD": bg.color = Color("101c2a")
        _: bg.color = Color("0c1826")
    stage.add_child(bg)
    stage.move_child(bg, 0)

func _decorate_home() -> void:
    var stage = game.get("stage")
    if stage == null: return
    var ribbon := Label.new()
    ribbon.set_meta("bf_ui_extra", true)
    ribbon.text = "SUMMONER'S HOME  •  GRAND GAIA"
    ribbon.position = Vector2(28, 365)
    ribbon.size = Vector2(640, 32)
    ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ribbon.add_theme_font_size_override("font_size", 15)
    ribbon.add_theme_color_override("font_color", Color("9fc5df"))
    ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(ribbon)

func _decorate_summon() -> void:
    var stage = game.get("stage")
    if stage == null: return
    _clear_extras(stage)
    var banner := HBoxContainer.new()
    banner.set_meta("bf_ui_extra", true)
    banner.position = Vector2(78, 310)
    banner.size = Vector2(565, 190)
    banner.add_theme_constant_override("separation", 2)
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for id in range(6, 12):
        var tex := TextureRect.new()
        tex.custom_minimum_size = Vector2(92, 180)
        tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tex.texture = _cached_texture(id)
        tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
        banner.add_child(tex)
    stage.add_child(banner)
    var label := Label.new()
    label.set_meta("bf_ui_extra", true)
    label.text = "EARLY HEROES • FEATURED POOL"
    label.position = Vector2(120, 500)
    label.size = Vector2(480, 35)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", Color("d8b5ff"))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(label)

func _decorate_quests() -> void:
    var stage = game.get("stage")
    if stage == null: return
    _clear_extras(stage)
    var label := Label.new()
    label.set_meta("bf_ui_extra", true)
    label.text = "GRAND GAIA • AREA SELECT"
    label.position = Vector2(150, 0)
    label.size = Vector2(420, 28)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", Color("9fc5df"))
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(label)

func _decorate_training() -> void:
    var stage = game.get("stage")
    if stage == null: return
    _clear_extras(stage)
    var ring := Label.new()
    ring.set_meta("bf_ui_extra", true)
    ring.text = "◇  PRACTICE ARENA  ◇"
    ring.position = Vector2(180, 125)
    ring.size = Vector2(360, 34)
    ring.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ring.add_theme_font_size_override("font_size", 16)
    ring.add_theme_color_override("font_color", Color("8fe4c1"))
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage.add_child(ring)

func _clear_extras(stage: Node) -> void:
    for child in stage.get_children():
        if child.has_meta("bf_ui_extra"):
            child.queue_free()

func _replace_visible_art() -> void:
    var stage = game.get("stage")
    if stage == null or not is_instance_valid(stage): return
    var ids: Array = []
    match _page():
        "GRAND GAIA", "SQUAD", "BATTLE", "TRAINING":
            var squad = game.get("squad")
            var inventory = game.get("inventory")
            if typeof(squad) == TYPE_ARRAY and typeof(inventory) == TYPE_ARRAY:
                for slot in squad:
                    var idx := int(slot)
                    if idx >= 0 and idx < inventory.size(): ids.append(int(inventory[idx].get("def_id", -1)))
        "UNITS":
            var inventory = game.get("inventory")
            var page := int(game.get("units_page"))
            if typeof(inventory) == TYPE_ARRAY:
                for i in range(page * 6, mini(page * 6 + 6, inventory.size())):
                    ids.append(int(inventory[i].get("def_id", -1)))
        "SUMMON RESULT":
            ids.append(_result_id(stage))
        _:
            return
    var rects: Array = []
    _collect_texture_rects(stage, rects)
    var cursor := 0
    for rect in rects:
        if cursor >= ids.size(): break
        var id := int(ids[cursor])
        if id >= 6 and id < 12:
            var texture := _cached_texture(id)
            if texture != null: rect.texture = texture
        cursor += 1

func _result_id(stage: Node) -> int:
    var text := _collect_text(stage)
    for item in ROSTER:
        if text.contains(str(item["name"])): return int(item["id"])
    return -1

func _collect_text(node: Node) -> String:
    var out := ""
    if node is Label or node is Button: out += " " + str(node.text)
    for child in node.get_children(): out += _collect_text(child)
    return out

func _collect_texture_rects(node: Node, output: Array) -> void:
    if node is TextureRect and not node.has_meta("bf_ui_extra"): output.append(node)
    for child in node.get_children(): _collect_texture_rects(child, output)

func _cached_texture(def_id: int) -> Texture2D:
    var filename := ""
    if def_id >= 0 and def_id < 6:
        var defs = game.get("unit_defs")
        if typeof(defs) == TYPE_ARRAY and def_id < defs.size(): filename = str(defs[def_id].get("cache", ""))
    else:
        for item in ROSTER:
            if int(item["id"]) == def_id: filename = str(item["cache"])
    if filename == "": return null
    var path := "user://bf_assets/%s" % filename
    if not FileAccess.file_exists(path): return null
    var image := Image.new()
    if image.load(ProjectSettings.globalize_path(path)) != OK: return null
    return ImageTexture.create_from_image(image)
