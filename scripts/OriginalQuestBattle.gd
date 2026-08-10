extends Control

var game: Node
var active := false
var busy := false
var root: Control
var unit_cards: Array = []
var hp_bars: Array = []
var bb_bars: Array = []
var touch_start: Dictionary = {}
var acted: Array = []
var turn_no := 1

const TEXT := Color("f7f7f7")
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
    z_index = 900
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
    if game == null or not is_instance_valid(game):
        return
    var show := _page() == "BATTLE" and int(game.get("current_quest")) == 0
    if show and not active:
        _enter()
    elif not show and active and not busy:
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
    mouse_filter = Control.MOUSE_FILTER_PASS
    acted.clear()
    turn_no = 1
    _build()

func _leave() -> void:
    active = false
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _clear()

func _clear() -> void:
    for c in get_children():
        c.queue_free()
    root = null
    unit_cards.clear()
    hp_bars.clear()
    bb_bars.clear()
    touch_start.clear()

func _build() -> void:
    _clear()
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(root)
    _build_original_header()
    _build_field()
    _build_enemies()
    _build_target_strip()
    _build_original_hud()
    _build_unit_cards()
    _build_items()
    _sync()

func _build_original_header() -> void:
    var header := TextureRect.new()
    header.position = Vector2(0,0)
    header.size = Vector2(720,82)
    header.texture = _original_texture("battle_header.png")
    header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    header.stretch_mode = TextureRect.STRETCH_SCALE
    header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(header)
    _label("● %05d" % int(game.get("gold")),Vector2(18,9),Vector2(200,52),19,Color("ffe18a"))
    _label("● %05d" % int(game.get("rank_xp")),Vector2(245,9),Vector2(200,52),19,Color("70cfff"))
    _label("▣ %02d" % (int(game.get("current_wave"))+1),Vector2(468,9),Vector2(105,52),19,TEXT)
    var menu := Button.new()
    menu.text = "MENU"
    menu.position = Vector2(590,10)
    menu.size = Vector2(115,55)
    menu.pressed.connect(func(): game.call("_home"))
    root.add_child(menu)

func _build_field() -> void:
    var bg := TextureRect.new()
    bg.position = Vector2(0,82)
    bg.size = Vector2(720,545)
    bg.texture = _asset_texture("bfm_backgrounds.png")
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(bg)
    var veil := ColorRect.new()
    veil.position = Vector2(0,82)
    veil.size = Vector2(720,545)
    veil.color = Color(0,0,0,0.08)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(veil)
    _label("MISTRAL  •  ADVENTURER'S PRAIRIE",Vector2(16,88),Vector2(470,32),15,TEXT)

func _build_enemies() -> void:
    var active_name := str(_enemy().get("name","Enemy"))
    var names := _support_names(active_name)
    names.insert(1,active_name)
    var positions := [Vector2(58,245),Vector2(225,145),Vector2(498,250)]
    var sizes := [Vector2(150,185),Vector2(270,330),Vector2(150,185)]
    for i in range(3):
        var art := TextureRect.new()
        art.position = positions[i]
        art.size = sizes[i]
        art.texture = _enemy_texture(str(names[i]))
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(art)

func _support_names(name: String) -> Array:
    match name:
        "Burny": return ["Squirty","Mossy"]
        "Squirty": return ["Burny","Mossy"]
        "Mossy": return ["Squirty","Sparky"]
        "Glowy": return ["Gloomy","Sparky"]
        _: return ["Sparky","Glowy"]

func _build_target_strip() -> void:
    var mark := TextureRect.new()
    mark.position = Vector2(8,555)
    mark.size = Vector2(82,82)
    mark.texture = _original_texture("battle_target_mark.png")
    mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(mark)
    _label("TURN %d" % turn_no,Vector2(250,555),Vector2(220,28),15,TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    _label(str(_enemy().get("name","Enemy")),Vector2(92,580),Vector2(340,32),21,TEXT)
    var hp := ProgressBar.new()
    hp.name = "EnemyHP"
    hp.position = Vector2(92,612)
    hp.size = Vector2(500,18)
    hp.show_percentage = false
    hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(hp)
    _label("HP %d/%d"%[int(game.get("enemy_hp")),int(game.get("enemy_max_hp"))],Vector2(430,580),Vector2(160,30),13,TEXT,HORIZONTAL_ALIGNMENT_RIGHT)
    var auto := TextureButton.new()
    auto.position = Vector2(594,566)
    auto.size = Vector2(116,56)
    auto.texture_normal = _original_texture("battle_auto_up.png")
    auto.texture_pressed = _original_texture("battle_auto_down.png")
    auto.ignore_texture_size = true
    auto.stretch_mode = TextureButton.STRETCH_SCALE
    auto.pressed.connect(_auto_attack)
    root.add_child(auto)

func _build_original_hud() -> void:
    var hud := TextureRect.new()
    hud.position = Vector2(0,635)
    hud.size = Vector2(720,506)
    hud.texture = _original_texture("battle_ui.png")
    hud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hud.stretch_mode = TextureRect.STRETCH_SCALE
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.modulate = Color(1,1,1,0.96)
    root.add_child(hud)

func _build_unit_cards() -> void:
    var positions := [Vector2(4,650),Vector2(362,650),Vector2(4,808),Vector2(362,808),Vector2(4,966),Vector2(362,966)]
    for slot in range(6):
        var card := Control.new()
        card.position = positions[slot]
        card.size = Vector2(354,150)
        card.mouse_filter = Control.MOUSE_FILTER_STOP
        card.z_index = 30
        root.add_child(card)
        unit_cards.append(card)
        var unit := _unit(slot)
        var def := _def(unit)
        var portrait := TextureRect.new()
        portrait.position = Vector2(8,8)
        portrait.size = Vector2(108,132)
        portrait.texture = _unit_texture(int(unit.get("def_id",0)))
        portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(portrait)
        _card_label(card,str(def.get("title",def.get("name","Unit"))),Vector2(118,8),Vector2(228,25),14)
        var hp_text := _card_label(card,"",Vector2(118,34),Vector2(228,22),14)
        hp_text.name = "HPText"
        var hp := ProgressBar.new()
        hp.position = Vector2(118,59)
        hp.size = Vector2(224,19)
        hp.show_percentage = false
        hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(hp)
        hp_bars.append(hp)
        var bb := ProgressBar.new()
        bb.position = Vector2(118,88)
        bb.size = Vector2(224,24)
        bb.max_value = 10
        bb.show_percentage = false
        bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(bb)
        bb_bars.append(bb)
        _card_label(card,"BRAVE BURST",Vector2(123,88),Vector2(160,22),11,Color("71dcff"))
        var hint := _card_label(card,"TAP: ATTACK   ↑ SWIPE: BB",Vector2(118,116),Vector2(224,22),10,Color("d9d9d9"))
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        card.gui_input.connect(func(event, s=slot): _card_input(event,s))

func _card_input(event: InputEvent, slot: int) -> void:
    if busy or acted.has(slot) or _hp(slot) <= 0:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_start[slot] = event.position
            _press_feedback(slot)
        else:
            var start: Vector2 = touch_start.get(slot,event.position)
            touch_start.erase(slot)
            var dy: float = float(event.position.y - start.y)
            if dy < -45.0:
                _burst(slot)
            elif start.distance_to(event.position) < 55.0:
                _normal_attack(slot)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _press_feedback(slot)
        _normal_attack(slot)
        accept_event()

func _press_feedback(slot: int) -> void:
    if slot < 0 or slot >= unit_cards.size(): return
    var c: Control = unit_cards[slot]
    var tw := create_tween()
    tw.tween_property(c,"modulate",Color(1.15,1.15,1.15,1),0.05)
    tw.tween_property(c,"modulate",Color.WHITE,0.08)

func _build_items() -> void:
    var footer := TextureRect.new()
    footer.position = Vector2(0,1135)
    footer.size = Vector2(720,145)
    footer.texture = _original_texture("battle_footer.png")
    footer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    footer.stretch_mode = TextureRect.STRETCH_SCALE
    footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(footer)
    _label("ITEMS",Vector2(0,1139),Vector2(720,26),15,TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    var names := ["Cure","High Cure","Atk Potion","Holy Water","Stimulant"]
    var counts := [10,7,5,10,10]
    for i in range(5):
        _label("×%d\n%s"%[counts[i],names[i]],Vector2(4+i*143,1170),Vector2(138,90),13,TEXT,HORIZONTAL_ALIGNMENT_CENTER)

func _normal_attack(slot: int) -> void:
    if busy or acted.has(slot) or _hp(slot) <= 0: return
    busy = true
    acted.append(slot)
    var card: Control = unit_cards[slot]
    var start: Vector2 = card.position
    var tw := create_tween()
    tw.tween_property(card,"position",start+Vector2(-18,-8),0.07)
    tw.tween_property(card,"position",start,0.10)
    await tw.finished
    var unit := _unit(slot)
    var atk := int(game.call("_unit_atk",unit))
    var damage := maxi(1,int(atk*randf_range(0.58,0.76)))
    game.set("enemy_hp",maxi(0,int(game.get("enemy_hp"))-damage))
    unit["bb"] = mini(10,int(unit.get("bb",0))+randi_range(1,3))
    _damage_popup(damage)
    _sync()
    if int(game.get("enemy_hp")) <= 0:
        await _defeated()
    busy = false
    if active and acted.size() >= _alive_count() and int(game.get("enemy_hp")) > 0:
        await _enemy_phase()

func _burst(slot: int) -> void:
    if busy or acted.has(slot) or _hp(slot) <= 0: return
    var unit := _unit(slot)
    if int(unit.get("bb",0)) < 10: return
    busy = true
    acted.append(slot)
    unit["bb"] = 0
    var def := _def(unit)
    var cut := TextureRect.new()
    cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cut.texture = _original_texture("battle_ui.png")
    cut.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    cut.stretch_mode = TextureRect.STRETCH_SCALE
    cut.modulate = Color(0.15,0.35,0.65,0.72)
    cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cut.z_index = 80
    root.add_child(cut)
    var title := _label("BRAVE BURST\n%s"%str(def.get("bb_name","Brave Burst")),Vector2(60,300),Vector2(600,160),34,Color("d8f5ff"),HORIZONTAL_ALIGNMENT_CENTER)
    title.z_index = 90
    await get_tree().create_timer(0.28).timeout
    var atk := int(game.call("_unit_atk",unit))
    var damage := maxi(1,int(atk*randf_range(1.65,2.05)))
    game.set("enemy_hp",maxi(0,int(game.get("enemy_hp"))-damage))
    _damage_popup(damage,true)
    await get_tree().create_timer(0.30).timeout
    cut.queue_free()
    title.queue_free()
    _sync()
    if int(game.get("enemy_hp")) <= 0:
        await _defeated()
    busy = false
    if active and acted.size() >= _alive_count() and int(game.get("enemy_hp")) > 0:
        await _enemy_phase()

func _auto_attack() -> void:
    if busy: return
    for slot in range(6):
        if active and not busy and not acted.has(slot) and _hp(slot)>0:
            _normal_attack(slot)
            await get_tree().create_timer(0.22).timeout

func _enemy_phase() -> void:
    busy = true
    await get_tree().create_timer(0.25).timeout
    var alive: Array = []
    for i in range(6):
        if _hp(i)>0: alive.append(i)
    if alive.is_empty():
        game.call("_defeat")
        busy=false
        return
    var target := int(alive[randi()%alive.size()])
    var arr = game.get("battle_hp")
    arr[target] = maxi(0,int(arr[target])-maxi(1,int(_enemy().get("atk",1))+randi_range(-8,12)))
    game.set("battle_hp",arr)
    acted.clear()
    turn_no += 1
    busy=false
    _sync()

func _defeated() -> void:
    await get_tree().create_timer(0.25).timeout
    acted.clear()
    if game.has_method("_finish_wave"):
        game.call("_finish_wave")
    await get_tree().process_frame
    if _page()=="BATTLE" and int(game.get("current_quest"))==0:
        turn_no=1
        _build()

func _sync() -> void:
    if root == null or not is_instance_valid(root): return
    var enemy_hp := root.find_child("EnemyHP",true,false)
    if enemy_hp is ProgressBar:
        enemy_hp.max_value = maxi(1,int(game.get("enemy_max_hp")))
        enemy_hp.value = int(game.get("enemy_hp"))
    for i in range(mini(6,unit_cards.size())):
        var u := _unit(i)
        var maxhp := int(game.call("_unit_hp",u))
        hp_bars[i].max_value=maxhp
        hp_bars[i].value=_hp(i)
        bb_bars[i].value=int(u.get("bb",0))
        var t=unit_cards[i].find_child("HPText",true,false)
        if t is Label: t.text="HP %d/%d"%[_hp(i),maxhp]
        unit_cards[i].modulate.a = 0.42 if _hp(i)<=0 or acted.has(i) else 1.0

func _damage_popup(amount:int, burst:=false) -> void:
    var l := _label(str(amount),Vector2(268,350),Vector2(190,70),34 if burst else 28,Color("fff0a3"),HORIZONTAL_ALIGNMENT_CENTER)
    l.z_index=70
    var tw:=create_tween()
    tw.set_parallel(true)
    tw.tween_property(l,"position:y",300,0.36)
    tw.tween_property(l,"modulate:a",0.0,0.42)
    tw.tween_callback(l.queue_free).set_delay(0.45)

func _enemy() -> Dictionary:
    var qs=game.get("quests")
    return qs[int(game.get("current_quest"))]["waves"][int(game.get("current_wave"))]

func _unit(slot:int)->Dictionary:
    var inv=game.get("inventory")
    var squad=game.get("squad")
    return inv[int(squad[slot])]

func _def(unit:Dictionary)->Dictionary:
    var defs=game.get("unit_defs")
    return defs[int(unit.get("def_id",0))]

func _hp(slot:int)->int:
    var arr=game.get("battle_hp")
    if slot>=0 and slot<arr.size(): return int(arr[slot])
    return 0

func _alive_count()->int:
    var n:=0
    for i in range(6):
        if _hp(i)>0: n+=1
    return n

func _enemy_texture(name:String)->Texture2D:
    return _asset_texture(str(ENEMY_TEX.get(name,"enemy_rairus.png")))

func _unit_texture(id:int)->Texture2D:
    var defs=game.get("unit_defs")
    if typeof(defs)!=TYPE_ARRAY or id<0 or id>=defs.size(): return null
    return _asset_texture(str(defs[id].get("cache","")))

func _asset_texture(filename:String)->Texture2D:
    if filename=="": return null
    var path:="res://assets/bf/%s"%filename
    if ResourceLoader.exists(path): return load(path)
    var user:="user://bf_assets/%s"%filename
    if FileAccess.file_exists(user):
        var img:=Image.new()
        if img.load(ProjectSettings.globalize_path(user))==OK: return ImageTexture.create_from_image(img)
    return null

func _original_texture(filename:String)->Texture2D:
    var path:="res://assets/bf/original/%s"%filename
    if ResourceLoader.exists(path): return load(path)
    return null

func _label(text:String,pos:Vector2,size:Vector2,fs:int,color:=TEXT,align:=HORIZONTAL_ALIGNMENT_LEFT)->Label:
    var l:=Label.new()
    l.text=text
    l.position=pos
    l.size=size
    l.add_theme_font_size_override("font_size",fs)
    l.add_theme_color_override("font_color",color)
    l.horizontal_alignment=align
    l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter=Control.MOUSE_FILTER_IGNORE
    root.add_child(l)
    return l

func _card_label(parent:Node,text:String,pos:Vector2,size:Vector2,fs:int,color:=TEXT)->Label:
    var l:=Label.new()
    l.text=text
    l.position=pos
    l.size=size
    l.add_theme_font_size_override("font_size",fs)
    l.add_theme_color_override("font_color",color)
    l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(l)
    return l
