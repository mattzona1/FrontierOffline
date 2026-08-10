extends Node

var game: Node
var overlay: Control
var last_page := ""

const GOLD := Color("e8bd56")
const STONE := Color("1b2c3c")
const TEXT := Color("f7f2e6")

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_refresh")

func _process(_delta: float) -> void:
    if game == null or not is_instance_valid(game):
        return
    var page := _page()
    if page != last_page:
        last_page = page
        call_deferred("_refresh")

func _page() -> String:
    var p = game.get("page_title")
    if p != null and is_instance_valid(p):
        return str(p.text)
    return ""

func _refresh() -> void:
    await get_tree().process_frame
    _clear_overlay()
    var page := _page()
    if page == "GRAND GAIA":
        _home_overlay()
    elif page in ["Vargas","Selena","Lance","Eze","Atro","Magress","Zelgal","Zephu","Lario","Weiss","Luna","Mifune"]:
        _unit_overlay(int(game.get("selected")))

func _clear_overlay() -> void:
    if overlay != null and is_instance_valid(overlay):
        overlay.queue_free()
    overlay = null

func _root() -> Control:
    var node := Control.new()
    node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    node.z_index = 300
    node.mouse_filter = Control.MOUSE_FILTER_STOP
    game.add_child(node)
    overlay = node
    return node

func _box(parent: Node, pos: Vector2, size: Vector2, color: Color) -> PanelContainer:
    var p := PanelContainer.new()
    p.position = pos
    p.size = size
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.border_width_left = 3
    s.border_width_right = 3
    s.border_width_top = 3
    s.border_width_bottom = 3
    s.border_color = Color("7a561a")
    s.corner_radius_top_left = 10
    s.corner_radius_top_right = 10
    s.corner_radius_bottom_left = 10
    s.corner_radius_bottom_right = 10
    p.add_theme_stylebox_override("panel", s)
    parent.add_child(p)
    return p

func _text(parent: Node, value: String, pos: Vector2, size: Vector2, font_size: int, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := Label.new()
    l.text = value
    l.position = pos
    l.size = size
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = align
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(l)
    return l

func _btn(parent: Node, value: String, pos: Vector2, size: Vector2, callback: Callable, font_size := 16) -> Button:
    var b := Button.new()
    b.text = value
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", font_size)
    var s := StyleBoxFlat.new()
    s.bg_color = Color("3d2a13")
    s.border_width_left = 3
    s.border_width_right = 3
    s.border_width_top = 3
    s.border_width_bottom = 3
    s.border_color = GOLD
    s.corner_radius_top_left = 10
    s.corner_radius_top_right = 10
    s.corner_radius_bottom_left = 10
    s.corner_radius_bottom_right = 10
    b.add_theme_stylebox_override("normal", s)
    b.pressed.connect(callback)
    parent.add_child(b)
    return b

func _home_overlay() -> void:
    var root := _root()
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("15120c")
    root.add_child(bg)

    _box(root, Vector2(0,0), Vector2(720,205), STONE)
    _text(root, "SUMMONER", Vector2(20,10), Vector2(250,28), 13, Color("b8c8d8"))
    _text(root, "Frontier", Vector2(20,38), Vector2(260,40), 26)
    _text(root, "Lv  %d" % int(game.get("rank")), Vector2(20,80), Vector2(130,32), 18)
    _text(root, "EXP", Vector2(20,118), Vector2(60,24), 13, Color("ffbd55"))
    var exp := ProgressBar.new()
    exp.position = Vector2(78,120)
    exp.size = Vector2(215,22)
    exp.max_value = 100
    exp.value = int(game.get("rank_xp")) % 100
    exp.show_percentage = false
    root.add_child(exp)
    _text(root, "Energy", Vector2(20,150), Vector2(70,24), 13, Color("77ec80"))
    var energy := ProgressBar.new()
    energy.position = Vector2(90,152)
    energy.size = Vector2(203,22)
    energy.max_value = 30
    energy.value = 30
    energy.show_percentage = false
    root.add_child(energy)

    _text(root, "BRAVE FRONTIER", Vector2(278,20), Vector2(270,56), 29, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
    _text(root, "OFFLINE", Vector2(330,76), Vector2(165,25), 13, Color("d6b96f"), HORIZONTAL_ALIGNMENT_CENTER)
    _text(root, "💎  %d" % int(game.get("gems")), Vector2(545,30), Vector2(160,35), 19)
    _text(root, "●  %d" % int(game.get("gold")), Vector2(545,72), Vector2(160,35), 19, Color("ffd77b"))
    _text(root, "ARENA   ● ● ●", Vector2(525,122), Vector2(178,30), 15, Color("dcb975"))

    var field := ColorRect.new()
    field.position = Vector2(0,205)
    field.size = Vector2(720,755)
    field.color = Color("251f13")
    root.add_child(field)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(0,228)
    scroll.size = Vector2(720,490)
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    root.add_child(scroll)
    var row := HBoxContainer.new()
    row.custom_minimum_size = Vector2(1900,470)
    row.add_theme_constant_override("separation", 14)
    scroll.add_child(row)
    row.add_child(_feature("ARENA", "PVP BATTLES", Color("264b72"), func(): _toast("Arena comes after the core quest loop.")))
    row.add_child(_feature("QUEST", "ENTER GRAND GAIA", Color("6b3218"), func(): game.call("_quests")))
    row.add_child(_feature("VORTEX", "SPECIAL DUNGEONS", Color("4b205f"), func(): _toast("Vortex comes after Quest 1.")))
    row.add_child(_feature("TOWN", "UPGRADES", Color("3d5a2d"), func(): game.call("_more")))
    row.add_child(_feature("SUMMON", "OPEN THE GATE", Color("1f5075"), func(): game.call("_summon")))
    row.add_child(_feature("SHOP", "ITEMS & GEMS", Color("6a4a1e"), func(): _toast("Shop is planned as a scrolling screen.")))
    _text(root, "Swipe left / right", Vector2(220,722), Vector2(280,32), 14, Color("c9b98d"), HORIZONTAL_ALIGNMENT_CENTER)

    var promo := _box(root, Vector2(18,770), Vector2(684,180), Color("241523"))
    _text(promo, "FEATURED SUMMON", Vector2(10,6), Vector2(660,28), 14, Color("c894ff"), HORIZONTAL_ALIGNMENT_CENTER)
    for i in range(6):
        var tex := TextureRect.new()
        tex.position = Vector2(12 + i * 109, 38)
        tex.size = Vector2(102, 126)
        tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        tex.texture = _unit_texture(6 + i)
        tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
        promo.add_child(tex)

    _bottom_nav(root)

func _feature(title: String, subtitle: String, color: Color, callback: Callable) -> Control:
    var p := PanelContainer.new()
    p.custom_minimum_size = Vector2(300,450)
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.border_width_left = 4
    s.border_width_right = 4
    s.border_width_top = 4
    s.border_width_bottom = 4
    s.border_color = GOLD
    s.corner_radius_top_left = 18
    s.corner_radius_top_right = 18
    s.corner_radius_bottom_left = 18
    s.corner_radius_bottom_right = 18
    p.add_theme_stylebox_override("panel", s)
    var b := Button.new()
    b.flat = true
    b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    b.pressed.connect(callback)
    p.add_child(b)
    _text(p, "✦", Vector2(20,60), Vector2(260,170), 98, Color("ffe272"), HORIZONTAL_ALIGNMENT_CENTER)
    _text(p, title, Vector2(8,250), Vector2(284,90), 45, Color("fff0b4"), HORIZONTAL_ALIGNMENT_CENTER)
    _text(p, subtitle, Vector2(10,342), Vector2(280,42), 14, Color("e8deca"), HORIZONTAL_ALIGNMENT_CENTER)
    return p

func _bottom_nav(root: Control) -> void:
    var bar := _box(root, Vector2(0,980), Vector2(720,300), Color("101722"))
    _text(bar, "Select a Menu.", Vector2(16,4), Vector2(680,30), 14, Color("d4dbe4"))
    var callbacks := [
        func(): game.call("_home"),
        func(): game.call("_units"),
        func(): game.call("_more"),
        func(): _toast("Shop coming soon"),
        func(): game.call("_summon"),
        func(): _toast("Social is disabled offline")
    ]
    var names := ["HOME","UNIT","TOWN","SHOP","SUMMON","SOCIAL"]
    for i in range(6):
        _btn(bar, names[i], Vector2(7 + i * 118, 48), Vector2(112,120), callbacks[i], 14)

func _unit_overlay(index: int) -> void:
    var inventory = game.get("inventory")
    var defs = game.get("unit_defs")
    if typeof(inventory) != TYPE_ARRAY or index < 0 or index >= inventory.size():
        return
    var unit: Dictionary = inventory[index]
    var id := int(unit.get("def_id",0))
    var def: Dictionary = defs[id]
    var root := _root()
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("1a160d")
    root.add_child(bg)
    _box(root, Vector2(0,0), Vector2(720,118), STONE)
    _btn(root, "Back", Vector2(14,18), Vector2(110,74), func(): game.call("_units"), 18)
    _text(root, "Unit No.%03d" % (id + 1), Vector2(145,10), Vector2(260,34), 17)
    _text(root, "%s  %s" % [_stars(int(def.get("rarity",3))), str(def.get("title",def.get("name","Unit")))], Vector2(145,44), Vector2(540,52), 22, Color("fff0b5"))

    var type_box := _box(root, Vector2(18,145), Vector2(250,155), Color("211a10"))
    _text(type_box, "TYPE  Breaker", Vector2(16,10), Vector2(220,40), 20, Color("ffc450"))
    _text(type_box, "Lv. %d / 60" % int(unit.get("level",1)), Vector2(16,56), Vector2(220,34), 22)
    _text(type_box, "Next Lv. %d" % maxi(0,1000-int(unit.get("xp",0))), Vector2(16,96), Vector2(220,34), 18)

    var art := TextureRect.new()
    art.position = Vector2(245,112)
    art.size = Vector2(455,610)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.texture = _unit_texture(id)
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(art)

    var stats := _box(root, Vector2(18,325), Vector2(245,350), Color("16120c"))
    _stat(stats,"HP",int(game.call("_unit_hp",unit)),18)
    _stat(stats,"ATK",int(game.call("_unit_atk",unit)),82)
    _stat(stats,"DEF",int(float(game.call("_unit_hp",unit))*0.23),146)
    _stat(stats,"REC",int(float(game.call("_unit_hp",unit))*0.14),210)
    _text(stats, "COST  %d" % (6 + int(def.get("rarity",3))*2), Vector2(16,280), Vector2(205,42), 18, Color("ffd679"), HORIZONTAL_ALIGNMENT_RIGHT)

    var leader := _box(root, Vector2(18,705), Vector2(684,142), Color("0d1118"))
    _text(leader,"Leader Skill",Vector2(12,6),Vector2(180,36),18,Color("ffba4b"))
    _text(leader,str(def.get("leader","")),Vector2(18,46),Vector2(648,82),16)
    var bb := _box(root, Vector2(18,862), Vector2(684,170), Color("0b1421"))
    _text(bb,"Brave Burst",Vector2(12,6),Vector2(180,36),18,Color("62c4ff"))
    _text(bb,str(def.get("bb_name","Brave Burst")),Vector2(190,6),Vector2(460,36),18,Color("ffd679"))
    _text(bb,"%d combo %s elemental attack." % [int(def.get("hits",3)),str(def.get("element","Neutral"))],Vector2(18,50),Vector2(648,80),16)
    _btn(root,"TRAIN",Vector2(18,1055),Vector2(325,75),func():game.call("_train",index),18)
    _btn(root,"EVOLVE",Vector2(377,1055),Vector2(325,75),func():game.call("_evolve",index),18)

func _stat(parent: Node, name: String, value: int, y: int) -> void:
    _text(parent,name,Vector2(16,y),Vector2(80,46),19,Color("d9d0bb"))
    _text(parent,str(value),Vector2(95,y),Vector2(125,46),28,TEXT,HORIZONTAL_ALIGNMENT_RIGHT)

func _stars(n: int) -> String:
    var out := ""
    for _i in range(clampi(n,1,6)):
        out += "★"
    return out

func _toast(value: String) -> void:
    var t = game.get("toast")
    if t != null and is_instance_valid(t):
        t.text = value

func _unit_texture(id: int) -> Texture2D:
    var defs = game.get("unit_defs")
    if typeof(defs) != TYPE_ARRAY or id < 0 or id >= defs.size():
        return null
    var filename := str(defs[id].get("cache",""))
    if filename == "":
        return null
    var path := "user://bf_assets/%s" % filename
    if not FileAccess.file_exists(path):
        path = "res://assets/bf/%s" % filename
    if not FileAccess.file_exists(path):
        return null
    var image := Image.new()
    if image.load(ProjectSettings.globalize_path(path)) != OK:
        return null
    return ImageTexture.create_from_image(image)
