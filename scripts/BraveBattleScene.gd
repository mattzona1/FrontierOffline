extends Control

# Full-screen battle presentation owned outside BraveMain's stage tree.
# BraveMain remains the rules/state authority; this scene handles presentation and input.

var game: Node
var battlefield: Control
var enemy_art: TextureRect
var enemy_hp_bar: ProgressBar
var enemy_name: Label
var wave_label: Label
var message_label: Label
var unit_nodes: Array = []
var unit_buttons: Array = []
var unit_hp_bars: Array = []
var unit_bb_bars: Array = []
var unit_origins: Array = []
var busy := false
var visible_page := ""
var last_enemy_key := ""
var t := 0.0

const GOLD := Color("f2c14e")
const WHITE := Color("f5f7ff")
const HP_GREEN := Color("62d979")
const BB_BLUE := Color("35aeea")
const SPARK := Color("ffe36d")

const ENEMY_ART := {
    "Ash Slime":"enemy_moerus.png", "Moerus":"enemy_moerus.png",
    "Boiling Wisp":"enemy_mizurus.png", "Mizurus":"enemy_mizurus.png",
    "Scoria Brute":"enemy_morirus.png", "Briar Pup":"enemy_morirus.png", "Morirus":"enemy_morirus.png",
    "Storm Idol":"enemy_rairus.png", "Spark Mite":"enemy_rairus.png", "Rairus":"enemy_rairus.png",
    "Cinder Imp":"enemy_imp.png", "Gloom Bat":"enemy_imp.png", "Shade Monk":"enemy_imp.png", "Imp":"enemy_imp.png",
    "Coalback Hound":"enemy_caitsith.png", "Cloud Raptor":"enemy_caitsith.png", "Moonfang":"enemy_caitsith.png", "Cait Sith":"enemy_caitsith.png"
}

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 500
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
    t += delta
    if game == null or not is_instance_valid(game): return
    var page := _page()
    var in_battle := page == "BATTLE" or page == "TRAINING"
    if in_battle and not visible:
        _enter_battle()
    elif not in_battle and visible and not busy:
        _leave_battle()
    if not visible: return
    if not busy:
        _sync_state()
        _idle_motion()

func _page() -> String:
    var p = game.get("page_title")
    return str(p.text) if p != null and is_instance_valid(p) else ""

func _enter_battle() -> void:
    visible = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    _rebuild()
    modulate.a = 0.0
    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 1.0, 0.22)

func _leave_battle() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _clear_children()

func _clear_children() -> void:
    for child in get_children(): child.queue_free()
    battlefield = null
    enemy_art = null
    enemy_hp_bar = null
    enemy_name = null
    wave_label = null
    message_label = null
    unit_nodes.clear(); unit_buttons.clear(); unit_hp_bars.clear(); unit_bb_bars.clear(); unit_origins.clear()

func _rebuild() -> void:
    _clear_children()
    battlefield = Control.new()
    battlefield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    battlefield.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(battlefield)
    _build_backdrop()
    _build_top_hud()
    _build_enemy()
    _build_units()
    _build_bottom_hud()
    _sync_state()

func _build_backdrop() -> void:
    var base := ColorRect.new()
    base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    base.color = Color("111827")
    base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    battlefield.add_child(base)

    # Try an original/preserved background sheet if the build bundled one.
    var bg_tex := _load_texture_any(["battle_backgrounds.png", "bfm_backgrounds.png", "backgrounds.png"])
    if bg_tex != null:
        var bg := TextureRect.new()
        bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        bg.texture = bg_tex
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        bg.modulate = Color(1,1,1,0.48)
        bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        battlefield.add_child(bg)

    var area := _area_name()
    var sky := ColorRect.new(); sky.position=Vector2(0,0); sky.size=Vector2(720,610); sky.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var horizon := Polygon2D.new()
    var ground := ColorRect.new(); ground.position=Vector2(0,535); ground.size=Vector2(720,745); ground.mouse_filter=Control.MOUSE_FILTER_IGNORE
    if area == "Mossvale":
        sky.color=Color(0.05,0.20,0.24,0.80); ground.color=Color(0.05,0.16,0.09,0.88)
        horizon.polygon=PackedVector2Array([Vector2(0,520),Vector2(95,300),Vector2(170,440),Vector2(285,235),Vector2(380,440),Vector2(535,270),Vector2(720,510)])
        horizon.color=Color("1d4c35")
    elif area == "Training":
        sky.color=Color(0.08,0.16,0.27,0.88); ground.color=Color(0.16,0.18,0.22,0.94)
        horizon.polygon=PackedVector2Array([Vector2(0,530),Vector2(120,430),Vector2(250,485),Vector2(390,390),Vector2(530,485),Vector2(720,420),Vector2(720,560)])
        horizon.color=Color("36495f")
    else:
        sky.color=Color(0.24,0.08,0.10,0.82); ground.color=Color(0.19,0.08,0.06,0.94)
        horizon.polygon=PackedVector2Array([Vector2(0,520),Vector2(115,300),Vector2(230,465),Vector2(385,220),Vector2(510,455),Vector2(625,310),Vector2(720,520)])
        horizon.color=Color("67362d")
    battlefield.add_child(sky); battlefield.add_child(horizon); battlefield.add_child(ground)
    battlefield.move_child(sky, 1 if bg_tex != null else 1)

    # Ground platform and depth bands.
    var platform := Polygon2D.new()
    platform.polygon=PackedVector2Array([Vector2(15,830),Vector2(705,830),Vector2(640,1170),Vector2(80,1170)])
    platform.color=Color(0.08,0.08,0.10,0.72)
    battlefield.add_child(platform)
    for y in [850, 925, 1000, 1075]:
        var line:=ColorRect.new(); line.position=Vector2(60,y); line.size=Vector2(600,2); line.color=Color(1,1,1,0.08); line.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(line)

    # Ambient motes give the field motion even between actions.
    for i in range(18):
        var mote := Label.new()
        mote.text = "•"
        mote.position = Vector2(20 + (i*79)%680, 120 + (i*113)%780)
        mote.add_theme_font_size_override("font_size", 18 + (i%3)*5)
        mote.add_theme_color_override("font_color", Color(1,0.78,0.35,0.12 if area != "Mossvale" else 0.08))
        mote.mouse_filter=Control.MOUSE_FILTER_IGNORE
        mote.set_meta("mote_phase", float(i)*0.53)
        battlefield.add_child(mote)

    var shade:=ColorRect.new(); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.color=Color(0,0,0,0.10); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(shade)

func _build_top_hud() -> void:
    var strip := ColorRect.new(); strip.position=Vector2(0,0); strip.size=Vector2(720,108); strip.color=Color(0.025,0.035,0.055,0.92); strip.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(strip)
    wave_label=Label.new(); wave_label.position=Vector2(18,18); wave_label.size=Vector2(180,45); wave_label.add_theme_font_size_override("font_size",20); wave_label.add_theme_color_override("font_color",WHITE); battlefield.add_child(wave_label)
    var retreat:=Button.new(); retreat.text="RETREAT"; retreat.position=Vector2(575,16); retreat.size=Vector2(125,48); retreat.add_theme_font_size_override("font_size",14); retreat.pressed.connect(_retreat); battlefield.add_child(retreat)
    message_label=Label.new(); message_label.position=Vector2(110,65); message_label.size=Vector2(500,34); message_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; message_label.add_theme_font_size_override("font_size",15); message_label.add_theme_color_override("font_color",Color("d7e6ff")); message_label.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(message_label)

func _build_enemy() -> void:
    enemy_art=TextureRect.new(); enemy_art.position=Vector2(205,155); enemy_art.size=Vector2(310,390); enemy_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; enemy_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; enemy_art.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(enemy_art)
    enemy_name=Label.new(); enemy_name.position=Vector2(80,555); enemy_name.size=Vector2(560,38); enemy_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; enemy_name.add_theme_font_size_override("font_size",22); enemy_name.add_theme_color_override("font_color",Color("fff2c7")); enemy_name.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(enemy_name)
    enemy_hp_bar=ProgressBar.new(); enemy_hp_bar.position=Vector2(110,598); enemy_hp_bar.size=Vector2(500,28); enemy_hp_bar.show_percentage=false; enemy_hp_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(enemy_hp_bar)

func _build_units() -> void:
    var positions := [Vector2(65,700),Vector2(260,680),Vector2(455,700),Vector2(65,920),Vector2(260,900),Vector2(455,920)]
    for slot in range(6):
        var holder:=Control.new(); holder.position=positions[slot]; holder.size=Vector2(200,205); holder.mouse_filter=Control.MOUSE_FILTER_IGNORE; holder.set_meta("slot",slot); battlefield.add_child(holder)
        unit_nodes.append(holder); unit_origins.append(positions[slot])
        var unit:Dictionary=_unit(slot); var def:Dictionary=_definition(unit)
        var art:=TextureRect.new(); art.position=Vector2(5,-10); art.size=Vector2(190,150); art.texture=_unit_texture(def); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.mouse_filter=Control.MOUSE_FILTER_IGNORE; holder.add_child(art)
        var shadow:=ColorRect.new(); shadow.position=Vector2(35,132); shadow.size=Vector2(130,10); shadow.color=Color(0,0,0,0.34); shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE; holder.add_child(shadow); holder.move_child(shadow,0)
        var name:=Label.new(); name.text=str(def.get("name","Unit")); name.position=Vector2(0,138); name.size=Vector2(200,24); name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; name.add_theme_font_size_override("font_size",14); name.add_theme_color_override("font_color",WHITE); name.mouse_filter=Control.MOUSE_FILTER_IGNORE; holder.add_child(name)
        var hp:=ProgressBar.new(); hp.position=Vector2(12,165); hp.size=Vector2(176,16); hp.show_percentage=false; hp.mouse_filter=Control.MOUSE_FILTER_IGNORE; holder.add_child(hp); unit_hp_bars.append(hp)
        var bb:=ProgressBar.new(); bb.position=Vector2(12,184); bb.size=Vector2(176,14); bb.max_value=10; bb.show_percentage=false; bb.mouse_filter=Control.MOUSE_FILTER_IGNORE; holder.add_child(bb); unit_bb_bars.append(bb)
        var tap:=Button.new(); tap.flat=true; tap.position=Vector2(0,0); tap.size=Vector2(200,165); tap.focus_mode=Control.FOCUS_NONE; tap.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND; tap.pressed.connect(func(s=slot): _attack_pressed(s)); holder.add_child(tap); unit_buttons.append(tap)
        var bb_button:=Button.new(); bb_button.text=""; bb_button.flat=true; bb_button.position=Vector2(8,178); bb_button.size=Vector2(184,28); bb_button.focus_mode=Control.FOCUS_NONE; bb_button.pressed.connect(func(s=slot): _bb_pressed(s)); holder.add_child(bb_button); holder.set_meta("bb_button",bb_button)

func _build_bottom_hud() -> void:
    var hint:=Label.new(); hint.position=Vector2(85,1190); hint.size=Vector2(550,55); hint.text="TAP A UNIT TO ATTACK   •   TAP A FULL BB GAUGE TO BURST"; hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; hint.add_theme_font_size_override("font_size",13); hint.add_theme_color_override("font_color",Color("aebed4")); hint.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(hint)

func _sync_state() -> void:
    if battlefield == null or not is_instance_valid(battlefield): return
    var enemy:=_enemy(); var key:="%s|%s"%[enemy.get("name","Enemy"),str(game.get("current_wave"))]
    if key != last_enemy_key:
        last_enemy_key=key
        enemy_art.texture=_enemy_texture(enemy)
        enemy_art.modulate=Color(1,1,1,0)
        enemy_art.scale=Vector2(0.82,0.82)
        var intro:=create_tween(); intro.set_parallel(true); intro.tween_property(enemy_art,"modulate:a",1.0,0.25); intro.tween_property(enemy_art,"scale",Vector2.ONE,0.32).set_trans(Tween.TRANS_BACK)
    enemy_name.text="%s  •  %s"%[enemy.get("name","Enemy"),enemy.get("element","Neutral")]
    var hp:=int(game.get("enemy_hp")); var max_hp:=maxi(1,int(game.get("enemy_max_hp"))); enemy_hp_bar.max_value=max_hp; enemy_hp_bar.value=hp
    var wave:=int(game.get("current_wave"))+1
    wave_label.text="TRAINING" if bool(game.get("training_mode")) else "WAVE %d"%wave
    for slot in range(mini(6,unit_nodes.size())):
        var unit:=_unit(slot); var maxu:=_unit_max_hp(unit); var current:=_battle_hp(slot)
        unit_hp_bars[slot].max_value=maxu; unit_hp_bars[slot].value=current
        unit_bb_bars[slot].value=int(unit.get("bb",0))
        var dead:=current<=0
        unit_nodes[slot].modulate=Color(0.35,0.35,0.35,0.75) if dead else Color.WHITE
        unit_buttons[slot].disabled=dead or busy
        var b=unit_nodes[slot].get_meta("bb_button")
        if b!=null and is_instance_valid(b): b.disabled=dead or busy or int(unit.get("bb",0))<10
        if int(unit.get("bb",0))>=10 and not dead:
            unit_bb_bars[slot].modulate=Color(0.7+0.3*sin(t*7.0),0.9,1.0,1.0)
        else: unit_bb_bars[slot].modulate=Color.WHITE

func _idle_motion() -> void:
    if battlefield==null:return
    for i in range(unit_nodes.size()):
        var n:Control=unit_nodes[i]
        if not is_instance_valid(n):continue
        var origin:Vector2=unit_origins[i]
        n.position.y=origin.y+sin(t*2.2+i*0.8)*3.5
    if enemy_art!=null and is_instance_valid(enemy_art):
        enemy_art.position.y=155+sin(t*1.65)*5.0
    for child in battlefield.get_children():
        if child.has_meta("mote_phase"):
            child.position.y -= 0.12
            child.modulate.a=0.45+0.45*sin(t*0.8+float(child.get_meta("mote_phase")))
            if child.position.y < 80: child.position.y=1050

func _attack_pressed(slot:int)->void:
    if busy:return
    var current:=_battle_hp(slot)
    if current<=0:return
    busy=true; _set_inputs(false)
    var attacker:Control=unit_nodes[slot]; var origin:Vector2=unit_origins[slot]
    message_label.text=""
    var windup:=create_tween(); windup.set_parallel(true); windup.tween_property(attacker,"scale",Vector2(1.08,1.08),0.10); windup.tween_property(attacker,"position",origin+Vector2(0,-12),0.10)
    await windup.finished
    var rush:=create_tween(); rush.set_parallel(true); rush.tween_property(attacker,"position",Vector2(260,505),0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN); rush.tween_property(attacker,"scale",Vector2(1.18,1.18),0.16)
    await rush.finished
    var hp_before:=int(game.get("enemy_hp")); var ally_before:=_battle_hp_snapshot(); var spark_before:=int(game.get("spark_chain"))
    game.call("_attack",slot)
    await get_tree().process_frame
    var dealt:=maxi(0,hp_before-int(game.get("enemy_hp")))
    _enemy_impact(dealt, int(game.get("spark_chain"))>spark_before)
    await get_tree().create_timer(0.18).timeout
    var back:=create_tween(); back.set_parallel(true); back.tween_property(attacker,"position",origin,0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT); back.tween_property(attacker,"scale",Vector2.ONE,0.20)
    await back.finished
    await _animate_enemy_retaliation(ally_before)
    busy=false; _set_inputs(true); _post_action_sync()

func _bb_pressed(slot:int)->void:
    if busy:return
    var unit:=_unit(slot)
    if int(unit.get("bb",0))<10:return
    busy=true; _set_inputs(false)
    var def:=_definition(unit); var attacker:Control=unit_nodes[slot]; var origin:Vector2=unit_origins[slot]
    var veil:=ColorRect.new(); veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); veil.color=Color(0.01,0.02,0.06,0.78); veil.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(veil); battlefield.move_child(veil,battlefield.get_child_count()-1)
    var title:=Label.new(); title.text="BRAVE BURST"; title.position=Vector2(60,300); title.size=Vector2(600,80); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",44); title.add_theme_color_override("font_color",Color("8ae5ff")); title.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(title)
    var name:=Label.new(); name.text=str(def.get("bb_name","Brave Burst")); name.position=Vector2(70,380); name.size=Vector2(580,55); name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; name.add_theme_font_size_override("font_size",25); name.add_theme_color_override("font_color",WHITE); name.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(name)
    for i in range(10):
        var glyph:=Label.new(); glyph.text="✦"; glyph.position=Vector2(80+(i*61)%560,520+(i%3)*55); glyph.add_theme_font_size_override("font_size",28+(i%2)*10); glyph.add_theme_color_override("font_color",Color(0.4,0.85,1.0,0.0)); glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(glyph)
        var gt:=create_tween(); gt.set_parallel(true); gt.tween_property(glyph,"modulate:a",1.0,0.18).set_delay(i*0.025); gt.tween_property(glyph,"position",Vector2(325,505),0.55).set_delay(i*0.025); gt.tween_callback(glyph.queue_free).set_delay(0.62+i*0.025)
    attacker.z_index=20
    var charge:=create_tween(); charge.set_parallel(true); charge.tween_property(attacker,"position",Vector2(260,520),0.34).set_trans(Tween.TRANS_BACK); charge.tween_property(attacker,"scale",Vector2(1.5,1.5),0.34); charge.tween_property(title,"scale",Vector2(1.08,1.08),0.25)
    await charge.finished
    var flash:=ColorRect.new(); flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); flash.color=Color(0.55,0.90,1.0,0.0); flash.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(flash)
    var ft:=create_tween(); ft.tween_property(flash,"color:a",0.78,0.06); ft.tween_property(flash,"color:a",0.0,0.20)
    var hp_before:=int(game.get("enemy_hp")); var ally_before:=_battle_hp_snapshot(); game.call("_bb",slot); await get_tree().process_frame
    var dealt:=maxi(0,hp_before-int(game.get("enemy_hp"))); _enemy_impact(dealt,true,true)
    await get_tree().create_timer(0.42).timeout
    veil.queue_free();title.queue_free();name.queue_free();flash.queue_free()
    var back:=create_tween(); back.set_parallel(true); back.tween_property(attacker,"position",origin,0.28); back.tween_property(attacker,"scale",Vector2.ONE,0.25); await back.finished; attacker.z_index=0
    await _animate_enemy_retaliation(ally_before)
    busy=false; _set_inputs(true); _post_action_sync()

func _enemy_impact(damage:int,sparked:bool,burst:bool=false)->void:
    if enemy_art==null:return
    var base:=enemy_art.position
    var shake:=create_tween(); shake.tween_property(enemy_art,"position:x",base.x-18,0.04); shake.tween_property(enemy_art,"position:x",base.x+14,0.04); shake.tween_property(enemy_art,"position:x",base.x-8,0.04); shake.tween_property(enemy_art,"position:x",base.x,0.06)
    var hits:=5 if burst else 3
    for i in range(hits):
        var pop:=Label.new(); pop.text=str(maxi(1,int(float(damage)/hits)+randi_range(-3,3))); pop.position=Vector2(275+randi_range(-55,55),330+randi_range(-35,35)); pop.size=Vector2(170,55); pop.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; pop.add_theme_font_size_override("font_size",32 if burst else 26); pop.add_theme_color_override("font_color",Color("fff0a1")); pop.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(pop)
        var pt:=create_tween(); pt.set_parallel(true); pt.tween_property(pop,"position:y",pop.position.y-55,0.42).set_delay(i*0.045); pt.tween_property(pop,"modulate:a",0.0,0.46).set_delay(i*0.045); pt.tween_callback(pop.queue_free).set_delay(0.50+i*0.045)
    if sparked:
        var s:=Label.new(); s.text="SPARK!!"; s.position=Vector2(235,455); s.size=Vector2(250,65); s.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; s.add_theme_font_size_override("font_size",34); s.add_theme_color_override("font_color",SPARK); s.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(s)
        var st:=create_tween(); st.tween_property(s,"scale",Vector2(1.24,1.24),0.10); st.tween_property(s,"scale",Vector2.ONE,0.10); st.tween_property(s,"modulate:a",0.0,0.35); st.tween_callback(s.queue_free)

func _animate_enemy_retaliation(before:Array)->void:
    var after:=_battle_hp_snapshot(); var target:=-1; var amount:=0
    for i in range(mini(before.size(),after.size())):
        if int(after[i])<int(before[i]): target=i;amount=int(before[i])-int(after[i]);break
    if target<0 or target>=unit_nodes.size():return
    var target_node:Control=unit_nodes[target]
    var strike:=create_tween(); strike.tween_property(enemy_art,"scale",Vector2(1.10,1.10),0.08); strike.tween_property(enemy_art,"scale",Vector2.ONE,0.10)
    await strike.finished
    var flash:=ColorRect.new(); flash.position=target_node.position+Vector2(20,35); flash.size=Vector2(160,125); flash.color=Color(1,0.18,0.12,0.55); flash.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(flash)
    var label:=Label.new(); label.text="-%d"%amount; label.position=target_node.position+Vector2(40,40); label.size=Vector2(120,50); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",26); label.add_theme_color_override("font_color",Color("ffb0a5")); label.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(label)
    var tw:=create_tween(); tw.set_parallel(true); tw.tween_property(target_node,"position:x",target_node.position.x+12,0.05); tw.tween_property(flash,"modulate:a",0.0,0.28); tw.tween_property(label,"position:y",label.position.y-40,0.35); tw.tween_property(label,"modulate:a",0.0,0.35); await tw.finished; flash.queue_free();label.queue_free();target_node.position=unit_origins[target]

func _post_action_sync()->void:
    var p:=_page()
    if p=="BATTLE" or p=="TRAINING":
        _sync_state()
        var enemy:=_enemy(); var key:="%s|%s"%[enemy.get("name","Enemy"),str(game.get("current_wave"))]
        if key!=last_enemy_key:
            last_enemy_key="";_sync_state()
    else:
        _leave_battle()

func _set_inputs(enabled:bool)->void:
    for b in unit_buttons:
        if is_instance_valid(b): b.disabled=not enabled
    for n in unit_nodes:
        if is_instance_valid(n):
            var bb=n.get_meta("bb_button")
            if bb!=null and is_instance_valid(bb): bb.disabled=not enabled

func _retreat()->void:
    if busy:return
    busy=true; visible=false; mouse_filter=Control.MOUSE_FILTER_IGNORE; game.call("_home"); busy=false

func _enemy()->Dictionary:
    var v=game.call("_enemy") if game.has_method("_enemy") else {}
    return v if typeof(v)==TYPE_DICTIONARY else {"name":"Enemy","element":"Neutral"}

func _unit(slot:int)->Dictionary:
    var inv=game.get("inventory"); var squad=game.get("squad")
    if typeof(inv)!=TYPE_ARRAY or typeof(squad)!=TYPE_ARRAY or slot>=squad.size():return {}
    var idx=int(squad[slot]); return inv[idx] if idx>=0 and idx<inv.size() else {}

func _definition(unit:Dictionary)->Dictionary:
    var defs=game.get("unit_defs"); var id=int(unit.get("def_id",0)); return defs[id] if typeof(defs)==TYPE_ARRAY and id>=0 and id<defs.size() else {}

func _unit_max_hp(unit:Dictionary)->int:
    return int(game.call("_unit_hp",unit)) if game.has_method("_unit_hp") else 1

func _battle_hp(slot:int)->int:
    var a=game.get("battle_hp"); return int(a[slot]) if typeof(a)==TYPE_ARRAY and slot<a.size() else 0

func _battle_hp_snapshot()->Array:
    var out:Array=[]; var a=game.get("battle_hp"); if typeof(a)==TYPE_ARRAY:
        for v in a: out.append(int(v))
    return out

func _unit_texture(def:Dictionary)->Texture2D:
    var filename:=str(def.get("cache","")); if filename!="":
        var tex:=_load_texture_any([filename]); if tex!=null:return tex
    return _fallback_texture(str(def.get("element","Neutral")))

func _enemy_texture(enemy:Dictionary)->Texture2D:
    var name:=str(enemy.get("name","")); var filename:=str(ENEMY_ART.get(name,_element_enemy(str(enemy.get("element","Neutral"))))); var tex:=_load_texture_any([filename]); return tex if tex!=null else _fallback_texture(str(enemy.get("element","Neutral")))

func _load_texture_any(names:Array)->Texture2D:
    for filename in names:
        var user:="user://bf_assets/%s"%filename
        if FileAccess.file_exists(user):
            var img:=Image.new(); if img.load(ProjectSettings.globalize_path(user))==OK:return ImageTexture.create_from_image(img)
        var res:="res://assets/bf/%s"%filename
        if ResourceLoader.exists(res):
            var r=load(res); if r is Texture2D:return r
    return null

func _fallback_texture(element:String)->Texture2D:
    var gt:=GradientTexture2D.new();var g:=Gradient.new();g.colors=PackedColorArray([_element_color(element),Color("10151f")]);gt.gradient=g;gt.width=256;gt.height=256;return gt

func _element_enemy(element:String)->String:
    match element:
        "Fire":return "enemy_moerus.png"
        "Water":return "enemy_mizurus.png"
        "Earth":return "enemy_morirus.png"
        "Thunder":return "enemy_rairus.png"
        "Dark":return "enemy_imp.png"
        _:return "enemy_caitsith.png"

func _element_color(element:String)->Color:
    match element:
        "Fire":return Color("c84b3c")
        "Water":return Color("3982c7")
        "Earth":return Color("5ca357")
        "Thunder":return Color("d5b13f")
        "Light":return Color("e5d77b")
        "Dark":return Color("8857ad")
        _:return Color("65758a")

func _area_name()->String:
    if bool(game.get("training_mode")):return "Training"
    var idx:=int(game.get("current_quest"));var qs=game.get("quests")
    if typeof(qs)==TYPE_ARRAY and idx>=0 and idx<qs.size():return str(qs[idx].get("area","Ashen Coast"))
    return "Ashen Coast"
