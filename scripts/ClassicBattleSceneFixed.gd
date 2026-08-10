extends Control

var game: Node
var active := false
var busy := false
var battlefield: Control
var unit_cards: Array = []
var hp_bars: Array = []
var bb_bars: Array = []
var acted: Array = []
var turn_no := 1

const TEXT := Color("f7f2e6")
const GOLD := Color("d9aa42")
const ENEMY_TEX := {
    "Burny":"enemy_moerus.png",
    "Squirty":"enemy_mizurus.png",
    "Mossy":"enemy_morirus.png",
    "Sparky":"enemy_rairus.png",
    "Glowy":"enemy_caitsith.png",
    "Gloomy":"enemy_imp.png",
    "King Sparky":"enemy_rairus.png"
}

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 700
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
    if game == null or not is_instance_valid(game):
        return
    var should_show := _page() == "BATTLE" and int(game.get("current_quest")) == 0
    if should_show and not active:
        _enter()
    elif not should_show and active and not busy:
        _leave()
    if active and not busy:
        _sync()

func _page() -> String:
    var p = game.get("page_title")
    if p != null and is_instance_valid(p):
        return str(p.text)
    return ""

func _enter() -> void:
    active = true
    visible = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    acted.clear()
    turn_no = 1
    _build()

func _leave() -> void:
    active = false
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _clear()

func _clear() -> void:
    for child in get_children():
        child.queue_free()
    battlefield = null
    unit_cards.clear()
    hp_bars.clear()
    bb_bars.clear()

func _build() -> void:
    _clear()
    battlefield = Control.new()
    battlefield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battlefield.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(battlefield)
    _header()
    _prairie()
    _enemies()
    _target_bar()
    _unit_grid()
    _items()
    _sync()

func _header() -> void:
    var bg := ColorRect.new()
    bg.position = Vector2(0,0)
    bg.size = Vector2(720,82)
    bg.color = Color("22384b")
    battlefield.add_child(bg)
    _text("● %05d" % int(game.get("gold")), Vector2(18,8), Vector2(210,54), 20, Color("ffe28a"))
    _text("● %05d" % int(game.get("rank_xp")), Vector2(250,8), Vector2(210,54), 20, Color("72cfff"))
    _text("▣ %02d" % (int(game.get("current_wave"))+1), Vector2(470,8), Vector2(110,54), 20, TEXT)
    _button("MENU", Vector2(590,10), Vector2(115,55), func(): game.call("_home"), 17)

func _prairie() -> void:
    var sky := ColorRect.new()
    sky.position = Vector2(0,82)
    sky.size = Vector2(720,300)
    sky.color = Color("72bce7")
    battlefield.add_child(sky)
    var hills := Polygon2D.new()
    hills.polygon = PackedVector2Array([
        Vector2(0,360),Vector2(80,250),Vector2(160,330),Vector2(245,225),
        Vector2(340,325),Vector2(455,215),Vector2(555,315),Vector2(650,245),
        Vector2(720,330),Vector2(720,410),Vector2(0,410)
    ])
    hills.color = Color("4c814a")
    battlefield.add_child(hills)
    var grass := ColorRect.new()
    grass.position = Vector2(0,360)
    grass.size = Vector2(720,350)
    grass.color = Color("719b41")
    battlefield.add_child(grass)
    for i in range(22):
        var mote := Label.new()
        mote.text = "✦"
        mote.position = Vector2((i*79)%690, 350 + (i*61)%300)
        mote.add_theme_font_size_override("font_size", 10 + (i%3)*3)
        mote.add_theme_color_override("font_color", Color(0.9,1.0,0.55,0.2))
        mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
        battlefield.add_child(mote)
    _text("MISTRAL • ADVENTURER'S PRAIRIE", Vector2(18,88), Vector2(500,38), 16, Color("fff6ce"))

func _enemies() -> void:
    var active_name := str(_enemy().get("name","Enemy"))
    var supports := _support(active_name)
    var names := [supports[0], active_name, supports[1]]
    var positions := [Vector2(70,250),Vector2(235,160),Vector2(500,255)]
    var sizes := [Vector2(150,180),Vector2(250,300),Vector2(150,180)]
    for i in range(3):
        var art := TextureRect.new()
        art.position = positions[i]
        art.size = sizes[i]
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.texture = _enemy_texture(names[i])
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        battlefield.add_child(art)

func _support(active_name: String) -> Array:
    if active_name == "Burny":
        return ["Squirty","Mossy"]
    if active_name == "Squirty":
        return ["Burny","Mossy"]
    if active_name == "Mossy":
        return ["Squirty","Sparky"]
    if active_name == "Glowy":
        return ["Gloomy","Sparky"]
    return ["Sparky","Glowy"]

func _target_bar() -> void:
    _text("TURN %d" % turn_no, Vector2(250,592), Vector2(220,30), 16, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
    var panel := PanelContainer.new()
    panel.position = Vector2(10,625)
    panel.size = Vector2(700,92)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("172331")
    style.border_width_top = 3
    style.border_width_bottom = 3
    style.border_color = GOLD
    panel.add_theme_stylebox_override("panel",style)
    battlefield.add_child(panel)
    var enemy := _enemy()
    _text(str(enemy.get("name","Enemy")), Vector2(85,633), Vector2(350,34), 22, TEXT)
    _text("●", Vector2(24,633), Vector2(50,40), 30, _element(str(enemy.get("element","Neutral"))))
    var hp := ProgressBar.new()
    hp.name = "EnemyHP"
    hp.position = Vector2(28,677)
    hp.size = Vector2(650,24)
    hp.max_value = maxi(1,int(game.get("enemy_max_hp")))
    hp.value = int(game.get("enemy_hp"))
    hp.show_percentage = false
    battlefield.add_child(hp)
    _text("HP:%d/%d" % [int(game.get("enemy_hp")),int(game.get("enemy_max_hp"))], Vector2(430,637), Vector2(245,30), 15, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
    _button("AUTO", Vector2(590,570), Vector2(112,52), func(): _auto(), 16)

func _unit_grid() -> void:
    unit_cards.clear()
    hp_bars.clear()
    bb_bars.clear()
    var positions := [Vector2(8,730),Vector2(366,730),Vector2(8,866),Vector2(366,866),Vector2(8,1002),Vector2(366,1002)]
    for slot in range(6):
        var card := PanelContainer.new()
        card.position = positions[slot]
        card.size = Vector2(346,124)
        var style := StyleBoxFlat.new()
        style.bg_color = Color("251c14")
        style.border_width_left = 3
        style.border_width_right = 3
        style.border_width_top = 3
        style.border_width_bottom = 3
        style.border_color = Color("c89945")
        style.corner_radius_top_left = 9
        style.corner_radius_top_right = 9
        style.corner_radius_bottom_left = 9
        style.corner_radius_bottom_right = 9
        card.add_theme_stylebox_override("panel",style)
        battlefield.add_child(card)
        unit_cards.append(card)

        var unit := _unit(slot)
        var def := _definition(unit)
        var portrait := TextureRect.new()
        portrait.position = Vector2(6,5)
        portrait.size = Vector2(108,112)
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.texture = _unit_texture(int(unit.get("def_id",0)))
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(portrait)
        _text_in(card,str(def.get("title",def.get("name","Unit"))),Vector2(118,4),Vector2(216,27),14,TEXT)
        var hp_text := _text_in(card,"",Vector2(118,29),Vector2(216,23),14,TEXT)
        hp_text.name = "HPText"
        var hp := ProgressBar.new()
        hp.position = Vector2(118,54)
        hp.size = Vector2(214,19)
        hp.show_percentage = false
        card.add_child(hp)
        hp_bars.append(hp)
        var bb := ProgressBar.new()
        bb.position = Vector2(118,80)
        bb.size = Vector2(214,22)
        bb.max_value = 10
        bb.show_percentage = false
        card.add_child(bb)
        bb_bars.append(bb)
        _text_in(card,"BRAVE BURST",Vector2(122,79),Vector2(150,22),11,Color("79d9ff"))
        var attack := Button.new()
        attack.flat = true
        attack.position = Vector2(0,0)
        attack.size = Vector2(346,76)
        attack.focus_mode = Control.FOCUS_NONE
        attack.pressed.connect(func(s=slot): _normal_attack(s))
        card.add_child(attack)
        card.set_meta("attack",attack)
        var burst := Button.new()
        burst.flat = true
        burst.position = Vector2(115,77)
        burst.size = Vector2(220,42)
        burst.focus_mode = Control.FOCUS_NONE
        burst.pressed.connect(func(s=slot): _burst(s))
        card.add_child(burst)
        card.set_meta("burst",burst)

func _items() -> void:
    _text("ITEMS", Vector2(0,1134), Vector2(720,30), 16, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
    var names := ["Cure","High Cure","Atk Potion","Holy Water","Stimulant"]
    var counts := [10,7,5,10,10]
    var colors := [Color("7fe38c"),Color("65d67c"),Color("e26464"),Color("e1ba55"),Color("a9b1c0")]
    for i in range(5):
        var p := PanelContainer.new()
        p.position = Vector2(5+i*143,1165)
        p.size = Vector2(137,108)
        var style := StyleBoxFlat.new()
        style.bg_color = Color("111923")
        style.border_width_left = 2
        style.border_width_right = 2
        style.border_width_top = 2
        style.border_width_bottom = 2
        style.border_color = Color("5c7084")
        p.add_theme_stylebox_override("panel",style)
        battlefield.add_child(p)
        _text_in(p,"×%d"%counts[i],Vector2(5,3),Vector2(127,24),13,TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        _text_in(p,"◆",Vector2(34,24),Vector2(70,40),30,colors[i],HORIZONTAL_ALIGNMENT_CENTER)
        _text_in(p,names[i],Vector2(4,72),Vector2(129,25),12,TEXT,HORIZONTAL_ALIGNMENT_CENTER)

func _normal_attack(slot: int) -> void:
    if busy or acted.has(slot) or _hp(slot) <= 0:
        return
    busy = true
    acted.append(slot)
    var card: Control = unit_cards[slot]
    var origin_y := card.position.y
    var tween := create_tween()
    tween.tween_property(card,"position:y",origin_y-14,0.07)
    tween.tween_property(card,"position:y",origin_y,0.10)
    await tween.finished
    var unit := _unit(slot)
    var atk := int(game.call("_unit_atk",unit))
    var damage := maxi(1,int(atk*randf_range(0.55,0.72)))
    game.set("enemy_hp",maxi(0,int(game.get("enemy_hp"))-damage))
    _damage_number(damage,false)
    await _battle_crystals(slot,randi_range(1,3))
    if int(game.get("enemy_hp")) <= 0:
        await _defeated()
        busy = false
        return
    busy = false
    _sync()
    if acted.size() >= _alive_count():
        await _enemy_phase()

func _burst(slot: int) -> void:
    if busy or acted.has(slot) or _hp(slot) <= 0:
        return
    var unit := _unit(slot)
    if int(unit.get("bb",0)) < 10:
        return
    busy = true
    acted.append(slot)
    unit["bb"] = 0
    var veil := ColorRect.new()
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(0.02,0.05,0.13,0.84)
    battlefield.add_child(veil)
    var def := _definition(unit)
    var title := _text("BRAVE BURST",Vector2(40,270),Vector2(640,80),44,Color("8fe8ff"),HORIZONTAL_ALIGNMENT_CENTER)
    var name := _text(str(def.get("bb_name","Brave Burst")),Vector2(40,350),Vector2(640,55),25,TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    for i in range(10):
        var spark := Label.new()
        spark.text = "✦"
        spark.position = Vector2(80+(i*59)%570,430+(i%4)*55)
        spark.add_theme_font_size_override("font_size",30)
        spark.add_theme_color_override("font_color",Color("65dfff"))
        battlefield.add_child(spark)
        var st := create_tween()
        st.set_parallel(true)
        st.tween_property(spark,"position",Vector2(350,500),0.42)
        st.tween_property(spark,"modulate:a",0.0,0.45)
        st.tween_callback(spark.queue_free).set_delay(0.47)
    await get_tree().create_timer(0.35).timeout
    var atk := int(game.call("_unit_atk",unit))
    var damage := maxi(1,int(atk*randf_range(1.6,2.05)))
    game.set("enemy_hp",maxi(0,int(game.get("enemy_hp"))-damage))
    _damage_number(damage,true)
    await get_tree().create_timer(0.28).timeout
    veil.queue_free()
    title.queue_free()
    name.queue_free()
    if int(game.get("enemy_hp")) <= 0:
        await _defeated()
        busy = false
        return
    busy = false
    _sync()
    if acted.size() >= _alive_count():
        await _enemy_phase()

func _battle_crystals(slot: int, count: int) -> void:
    var unit := _unit(slot)
    for i in range(count):
        var crystal := Label.new()
        crystal.text = "◆"
        crystal.position = Vector2(335+randi_range(-40,40),450+randi_range(-30,30))
        crystal.size = Vector2(40,40)
        crystal.add_theme_font_size_override("font_size",28)
        crystal.add_theme_color_override("font_color",Color("5fd3ff"))
        battlefield.add_child(crystal)
        var target := unit_cards[slot].position + Vector2(250,92)
        var tween := create_tween()
        tween.tween_property(crystal,"position",target,0.25+0.04*i)
        await tween.finished
        crystal.queue_free()
        unit["bb"] = mini(10,int(unit.get("bb",0))+1)
    _sync()

func _enemy_phase() -> void:
    busy = true
    await get_tree().create_timer(0.18).timeout
    var alive: Array = []
    for slot in range(6):
        if _hp(slot) > 0:
            alive.append(slot)
    if alive.is_empty():
        game.call("_defeat")
        busy = false
        return
    var target := int(alive[randi()%alive.size()])
    var hp_array = game.get("battle_hp")
    var damage := maxi(1,int(_enemy().get("atk",20))+randi_range(-5,8))
    hp_array[target] = maxi(0,int(hp_array[target])-damage)
    game.set("battle_hp",hp_array)
    var card: Control = unit_cards[target]
    var ox := card.position.x
    var tween := create_tween()
    tween.tween_property(card,"position:x",ox+12,0.05)
    tween.tween_property(card,"position:x",ox-9,0.05)
    tween.tween_property(card,"position:x",ox,0.06)
    await tween.finished
    acted.clear()
    turn_no += 1
    busy = false
    _sync()

func _defeated() -> void:
    _text("ENEMY DEFEATED!",Vector2(190,360),Vector2(340,70),32,Color("fff0a1"),HORIZONTAL_ALIGNMENT_CENTER)
    await get_tree().create_timer(0.35).timeout
    acted.clear()
    if game.has_method("_finish_wave"):
        game.call("_finish_wave")
    await get_tree().process_frame
    if _page() == "BATTLE":
        _build()

func _auto() -> void:
    if busy:
        return
    for slot in range(6):
        if not acted.has(slot) and _hp(slot) > 0:
            _normal_attack(slot)
            return

func _sync() -> void:
    if battlefield == null or not is_instance_valid(battlefield):
        return
    var hpnode := battlefield.get_node_or_null("EnemyHP")
    if hpnode != null:
        hpnode.max_value = maxi(1,int(game.get("enemy_max_hp")))
        hpnode.value = int(game.get("enemy_hp"))
    for slot in range(mini(6,unit_cards.size())):
        var unit := _unit(slot)
        var max_hp := int(game.call("_unit_hp",unit))
        var current := _hp(slot)
        hp_bars[slot].max_value = max_hp
        hp_bars[slot].value = current
        bb_bars[slot].value = int(unit.get("bb",0))
        var hp_text = unit_cards[slot].get_node_or_null("HPText")
        if hp_text != null:
            hp_text.text = "HP %d/%d" % [current,max_hp]
        var attack = unit_cards[slot].get_meta("attack")
        var burst = unit_cards[slot].get_meta("burst")
        if attack != null:
            attack.disabled = busy or acted.has(slot) or current <= 0
        if burst != null:
            burst.disabled = busy or acted.has(slot) or current <= 0 or int(unit.get("bb",0)) < 10

func _alive_count() -> int:
    var count := 0
    for slot in range(6):
        if _hp(slot) > 0:
            count += 1
    return count

func _damage_number(value: int, big: bool) -> void:
    var l := _text(str(value),Vector2(245,355),Vector2(230,70),40 if big else 30,Color("fff0a1"),HORIZONTAL_ALIGNMENT_CENTER)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(l,"position:y",l.position.y-50,0.38)
    tween.tween_property(l,"modulate:a",0.0,0.42)
    tween.tween_callback(l.queue_free).set_delay(0.44)

func _enemy() -> Dictionary:
    var quests = game.get("quests")
    var q := int(game.get("current_quest"))
    var wave := int(game.get("current_wave"))
    return quests[q]["waves"][wave]

func _unit(slot: int) -> Dictionary:
    var inventory = game.get("inventory")
    var squad = game.get("squad")
    return inventory[int(squad[slot])]

func _definition(unit: Dictionary) -> Dictionary:
    var defs = game.get("unit_defs")
    return defs[int(unit.get("def_id",0))]

func _hp(slot: int) -> int:
    var hp_array = game.get("battle_hp")
    if slot >= 0 and slot < hp_array.size():
        return int(hp_array[slot])
    return 0

func _enemy_texture(name: String) -> Texture2D:
    var filename := str(ENEMY_TEX.get(name,"enemy_rairus.png"))
    return _texture(filename)

func _unit_texture(id: int) -> Texture2D:
    var defs = game.get("unit_defs")
    if typeof(defs) != TYPE_ARRAY or id < 0 or id >= defs.size():
        return null
    return _texture(str(defs[id].get("cache","")))

func _texture(filename: String) -> Texture2D:
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

func _element(value: String) -> Color:
    match value:
        "Fire": return Color("ef5a37")
        "Water": return Color("42a9f5")
        "Earth": return Color("70bf52")
        "Thunder": return Color("edcd45")
        "Light": return Color("efe7a0")
        "Dark": return Color("8d59c8")
        _: return Color("aab4c0")

func _text(value: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := Label.new()
    l.text = value
    l.position = pos
    l.size = size
    l.add_theme_font_size_override("font_size",font_size)
    l.add_theme_color_override("font_color",color)
    l.horizontal_alignment = align
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    battlefield.add_child(l)
    return l

func _text_in(parent: Node, value: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := Label.new()
    l.text = value
    l.position = pos
    l.size = size
    l.add_theme_font_size_override("font_size",font_size)
    l.add_theme_color_override("font_color",color)
    l.horizontal_alignment = align
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(l)
    return l

func _button(value: String, pos: Vector2, size: Vector2, callback: Callable, font_size: int) -> Button:
    var b := Button.new()
    b.text = value
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size",font_size)
    b.pressed.connect(callback)
    battlefield.add_child(b)
    return b
