extends Control

# Full-screen Brave Frontier-style battle presentation.
# BraveMain remains the progression/save authority. This scene owns combat presentation,
# player action cadence, Spark timing, and enemy phase while a battle is active.

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
var acted_slots: Array = []
var action_queue: Array = []
var queue_running := false
var last_tap_ms := 0
var last_tap_slot := -1
var last_enemy_key := ""
var t := 0.0

const GOLD := Color("f2c14e")
const WHITE := Color("f5f7ff")
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
    elif not in_battle and visible and not queue_running:
        _leave_battle()
    if not visible: return
    _sync_state()
    if not queue_running:
        _idle_motion()

func _page() -> String:
    var p = game.get("page_title")
    return str(p.text) if p != null and is_instance_valid(p) else ""

func _enter_battle() -> void:
    visible = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    acted_slots.clear(); action_queue.clear(); queue_running = false
    last_tap_ms = 0; last_tap_slot = -1; last_enemy_key = ""
    _rebuild()
    modulate.a = 0.0
    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 1.0, 0.22)

func _leave_battle() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    action_queue.clear(); acted_slots.clear(); queue_running = false
    _clear_children()

func _clear_children() -> void:
    for child in get_children(): child.queue_free()
    battlefield = null; enemy_art = null; enemy_hp_bar = null; enemy_name = null
    wave_label = null; message_label = null
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
    var base := ColorRect.new(); base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); base.color = Color("101722"); base.mouse_filter=Control.MOUSE_FILTER_IGNORE; battlefield.add_child(base)
    var area := _area_name()
    var sky := ColorRect.new(); sky.position=Vector2(0,0); sky.size=Vector2(720,620); sky.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var far := Polygon2D.new(); var near := Polygon2D.new()
    var ground := ColorRect.new(); ground.position=Vector2(0,535); ground.size=Vector2(720,745); ground.mouse_filter=Control.MOUSE_FILTER_IGNORE
    if area == "Mossvale":
        sky.color=Color("123844"); ground.color=Color("102b1b")
        far.polygon=PackedVector2Array([Vector2(0,530),Vector2(90,320),Vector2(180,455),Vector2(300,250),Vector2(405,450),Vector2(545,290),Vector2(720,515)]); far.color=Color("24543d")
        near.polygon=PackedVector2Array([Vector2(0,570),Vector2(115,470),Vector2(245,540),Vector2(360,430),Vector2(500,535),Vector2(620,455),Vector2(720,545)]); near.color=Color("183d2b")
    elif area == "Training":
        sky.color=Color("182c45"); ground.color=Color("292d36")
        far.polygon=PackedVector2Array([Vector2(0,535),Vector2(140,420),Vector2(270,495),Vector2(420,385),Vector2(565,495),Vector2(720,425),Vector2(720,560)]); far.color=Color("3c536b")
        near.polygon=PackedVector2Array([Vector2(0,570),Vector2(170,515),Vector2(330,550),Vector2(500,500),Vector2(720,560)]); near.color=Color("303c4d")
    else:
        sky.color=Color("4a2028"); ground.color=Color("321814")
        far.polygon=PackedVector2Array([Vector2(0,525),Vector2(105,305),Vector2(220,465),Vector2(390,225),Vector2(515,455),Vector2(625,315),Vector2(720,520)]); far.color=Color("72372d")
        near.polygon=PackedVector2Array([Vector2(0,570),Vector2(130,475),Vector2(250,545),Vector2(390,440),Vector2(545,540),Vector2(660,470),Vector2(720,535)]); near.color=Color("4e2a24")
    battlefield.add_child(sky); battlefield.add_child(far); battlefield.add_child(near); battlefield.add_child(ground)

    if area == "Mossvale":
        for x in [35,105,595,665]:
            var trunk:=ColorRect.new();trunk.position=Vector2(x,385);trunk.size=Vector2(20,190);trunk.color=Color("4b3525");trunk.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(trunk)
            var crown:=Polygon2D.new();crown.polygon=PackedVector2Array([Vector2(x-65,430),Vector2(x+10,270),Vector2(x+80,430)]);crown.color=Color("2d7048");battlefield.add_child(crown)
    elif area != "Training":
        var lava:=ColorRect.new();lava.position=Vector2(0,558);lava.size=Vector2(720,12);lava.color=Color("d66232");lava.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(lava)
        var glow:=ColorRect.new();glow.position=Vector2(0,570);glow.size=Vector2(720,36);glow.color=Color(0.95,0.25,0.08,0.12);glow.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(glow)

    var platform:=Polygon2D.new();platform.polygon=PackedVector2Array([Vector2(18,820),Vector2(702,820),Vector2(642,1178),Vector2(78,1178)]);platform.color=Color(0.04,0.045,0.06,0.75);battlefield.add_child(platform)
    for y in [850,925,1000,1075,1150]:
        var line:=ColorRect.new();line.position=Vector2(60,y);line.size=Vector2(600,2);line.color=Color(1,1,1,0.065);line.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(line)
    for i in range(20):
        var mote:=Label.new();mote.text="•";mote.position=Vector2(15+(i*83)%690,130+(i*109)%930);mote.add_theme_font_size_override("font_size",16+(i%4)*4);mote.add_theme_color_override("font_color",Color(1,0.78,0.35,0.12 if area!="Mossvale" else 0.09));mote.mouse_filter=Control.MOUSE_FILTER_IGNORE;mote.set_meta("mote_phase",float(i)*0.47);battlefield.add_child(mote)
    var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,0.09);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(shade)

func _build_top_hud() -> void:
    var strip:=ColorRect.new();strip.position=Vector2(0,0);strip.size=Vector2(720,112);strip.color=Color(0.02,0.03,0.05,0.92);strip.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(strip)
    wave_label=Label.new();wave_label.position=Vector2(18,18);wave_label.size=Vector2(190,45);wave_label.add_theme_font_size_override("font_size",20);wave_label.add_theme_color_override("font_color",WHITE);battlefield.add_child(wave_label)
    var retreat:=Button.new();retreat.text="RETREAT";retreat.position=Vector2(575,16);retreat.size=Vector2(125,48);retreat.add_theme_font_size_override("font_size",14);retreat.pressed.connect(_retreat);battlefield.add_child(retreat)
    message_label=Label.new();message_label.position=Vector2(100,66);message_label.size=Vector2(520,34);message_label.text="PLAYER PHASE";message_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;message_label.add_theme_font_size_override("font_size",15);message_label.add_theme_color_override("font_color",Color("d7e6ff"));message_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(message_label)

func _build_enemy() -> void:
    enemy_art=TextureRect.new();enemy_art.position=Vector2(205,150);enemy_art.size=Vector2(310,390);enemy_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;enemy_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;enemy_art.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(enemy_art)
    enemy_name=Label.new();enemy_name.position=Vector2(80,548);enemy_name.size=Vector2(560,38);enemy_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;enemy_name.add_theme_font_size_override("font_size",22);enemy_name.add_theme_color_override("font_color",Color("fff2c7"));enemy_name.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(enemy_name)
    enemy_hp_bar=ProgressBar.new();enemy_hp_bar.position=Vector2(110,592);enemy_hp_bar.size=Vector2(500,28);enemy_hp_bar.show_percentage=false;enemy_hp_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(enemy_hp_bar)

func _build_units() -> void:
    var positions:=[Vector2(55,690),Vector2(260,675),Vector2(465,690),Vector2(55,915),Vector2(260,900),Vector2(465,915)]
    for slot in range(6):
        var holder:=Control.new();holder.position=positions[slot];holder.size=Vector2(200,205);holder.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.set_meta("slot",slot);battlefield.add_child(holder)
        unit_nodes.append(holder);unit_origins.append(positions[slot])
        var unit:Dictionary=_unit(slot);var def:Dictionary=_definition(unit)
        var shadow:=ColorRect.new();shadow.position=Vector2(35,132);shadow.size=Vector2(130,10);shadow.color=Color(0,0,0,0.34);shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(shadow)
        var art:=TextureRect.new();art.position=Vector2(5,-12);art.size=Vector2(190,154);art.texture=_unit_texture(def);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(art)
        var name:=Label.new();name.text=str(def.get("name","Unit"));name.position=Vector2(0,138);name.size=Vector2(200,24);name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name.add_theme_font_size_override("font_size",14);name.add_theme_color_override("font_color",WHITE);name.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(name)
        var hp:=ProgressBar.new();hp.position=Vector2(12,165);hp.size=Vector2(176,16);hp.show_percentage=false;hp.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(hp);unit_hp_bars.append(hp)
        var bb:=ProgressBar.new();bb.position=Vector2(12,184);bb.size=Vector2(176,14);bb.max_value=10;bb.show_percentage=false;bb.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(bb);unit_bb_bars.append(bb)
        var tap:=Button.new();tap.flat=true;tap.position=Vector2(0,0);tap.size=Vector2(200,165);tap.focus_mode=Control.FOCUS_NONE;tap.pressed.connect(func(s=slot):_attack_pressed(s));holder.add_child(tap);unit_buttons.append(tap)
        var bb_button:=Button.new();bb_button.text="";bb_button.flat=true;bb_button.position=Vector2(8,177);bb_button.size=Vector2(184,29);bb_button.focus_mode=Control.FOCUS_NONE;bb_button.pressed.connect(func(s=slot):_bb_pressed(s));holder.add_child(bb_button);holder.set_meta("bb_button",bb_button)

func _build_bottom_hud() -> void:
    var hint:=Label.new();hint.position=Vector2(70,1190);hint.size=Vector2(580,55);hint.text="TAP UNITS TO QUEUE ATTACKS   •   FULL BLUE GAUGE = BRAVE BURST";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;hint.add_theme_font_size_override("font_size",13);hint.add_theme_color_override("font_color",Color("aebed4"));hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(hint)

func _sync_state() -> void:
    if battlefield==null or not is_instance_valid(battlefield):return
    var enemy:=_enemy();var key:="%s|%s"%[enemy.get("name","Enemy"),str(game.get("current_wave"))]
    if key!=last_enemy_key:
        last_enemy_key=key;enemy_art.texture=_enemy_texture(enemy);enemy_art.modulate=Color(1,1,1,0);enemy_art.scale=Vector2(0.82,0.82)
        var intro:=create_tween();intro.set_parallel(true);intro.tween_property(enemy_art,"modulate:a",1.0,0.25);intro.tween_property(enemy_art,"scale",Vector2.ONE,0.32).set_trans(Tween.TRANS_BACK)
    enemy_name.text="%s  •  %s"%[enemy.get("name","Enemy"),enemy.get("element","Neutral")]
    var hp:=int(game.get("enemy_hp"));var max_hp:=maxi(1,int(game.get("enemy_max_hp")));enemy_hp_bar.max_value=max_hp;enemy_hp_bar.value=hp
    var wave:=int(game.get("current_wave"))+1;wave_label.text="TRAINING" if bool(game.get("training_mode")) else "WAVE %d"%wave
    for slot in range(mini(6,unit_nodes.size())):
        var unit:=_unit(slot);var maxu:=_unit_max_hp(unit);var current:=_battle_hp(slot);var dead:=current<=0
        unit_hp_bars[slot].max_value=maxu;unit_hp_bars[slot].value=current;unit_bb_bars[slot].value=int(unit.get("bb",0))
        var spent:=acted_slots.has(slot) or _slot_pending(slot)
        unit_nodes[slot].modulate=Color(0.35,0.35,0.35,0.70) if dead else (Color(0.72,0.72,0.82,0.86) if spent else Color.WHITE)
        unit_buttons[slot].disabled=dead or spent or not _eligible_slot(slot)
        var b=unit_nodes[slot].get_meta("bb_button")
        if b!=null and is_instance_valid(b):b.disabled=dead or spent or int(unit.get("bb",0))<10 or not _eligible_slot(slot)
        if int(unit.get("bb",0))>=10 and not dead and not spent:unit_bb_bars[slot].modulate=Color(0.7+0.3*sin(t*7.0),0.9,1.0,1.0)
        else:unit_bb_bars[slot].modulate=Color.WHITE

func _idle_motion() -> void:
    if battlefield==null:return
    for i in range(unit_nodes.size()):
        var n:Control=unit_nodes[i]
        if not is_instance_valid(n):continue
        var origin:Vector2=unit_origins[i];n.position.y=origin.y+sin(t*2.2+i*0.8)*3.5
    if enemy_art!=null and is_instance_valid(enemy_art):enemy_art.position.y=150+sin(t*1.65)*5.0
    for child in battlefield.get_children():
        if child.has_meta("mote_phase"):
            child.position.y-=0.16;child.modulate.a=0.35+0.35*sin(t*0.8+float(child.get_meta("mote_phase"))); 
            if child.position.y<85:child.position.y=1110

func _attack_pressed(slot:int)->void:
    if not _can_queue(slot,false):return
    _queue_action(slot,false)

func _bb_pressed(slot:int)->void:
    if not _can_queue(slot,true):return
    _queue_action(slot,true)

func _can_queue(slot:int,burst:bool)->bool:
    if not visible or slot<0 or slot>=6:return false
    if _battle_hp(slot)<=0 or acted_slots.has(slot) or _slot_pending(slot) or not _eligible_slot(slot):return false
    if burst and int(_unit(slot).get("bb",0))<10:return false
    return true

func _queue_action(slot:int,burst:bool)->void:
    var item:={"slot":slot,"burst":burst,"tap_ms":Time.get_ticks_msec()}
    action_queue.append(item)
    _queue_pulse(slot,burst)
    _sync_state()
    if not queue_running:call_deferred("_run_action_queue")

func _queue_pulse(slot:int,burst:bool)->void:
    if slot>=unit_nodes.size():return
    var n:Control=unit_nodes[slot];var tw:=create_tween();tw.tween_property(n,"scale",Vector2(1.08,1.08),0.08);tw.tween_property(n,"scale",Vector2.ONE,0.08)
    message_label.text="BRAVE BURST QUEUED" if burst else "ATTACK QUEUED"

func _run_action_queue()->void:
    if queue_running:return
    queue_running=true
    while not action_queue.is_empty() and visible:
        var item:Dictionary=action_queue.pop_front()
        await _play_action(item)
        if _page()!="BATTLE" and _page()!="TRAINING":break
        if int(game.get("enemy_hp"))<=0:break
    queue_running=false
    if not visible:return
    if _page()!="BATTLE" and _page()!="TRAINING":return
    if _all_eligible_acted():
        if bool(game.get("training_mode")):await _training_cycle_reset()
        else:await _enemy_phase()
    _sync_state()

func _play_action(item:Dictionary)->void:
    var slot:=int(item.get("slot",0));var burst:=bool(item.get("burst",false));var tap_ms:=int(item.get("tap_ms",0))
    if _battle_hp(slot)<=0:return
    var sparked:=last_tap_ms>0 and tap_ms-last_tap_ms<=650 and last_tap_slot!=slot
    last_tap_ms=tap_ms;last_tap_slot=slot
    acted_slots.append(slot)
    if burst:await _play_bb_action(slot,sparked)
    else:await _play_normal_action(slot,sparked)

func _play_normal_action(slot:int,sparked:bool)->void:
    var attacker:Control=unit_nodes[slot];var origin:Vector2=unit_origins[slot];var def:=_definition(_unit(slot))
    message_label.text=str(def.get("name","Unit"))+" attacks!"
    var windup:=create_tween();windup.set_parallel(true);windup.tween_property(attacker,"scale",Vector2(1.08,1.08),0.09);windup.tween_property(attacker,"position",origin+Vector2(0,-14),0.09);await windup.finished
    var rush:=create_tween();rush.set_parallel(true);rush.tween_property(attacker,"position",Vector2(260,495),0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN);rush.tween_property(attacker,"scale",Vector2(1.18,1.18),0.16);await rush.finished
    var damage:=_apply_player_damage(slot,false,sparked)
    _enemy_impact(damage,sparked,false,clampi(int(def.get("hits",3)),2,8))
    await get_tree().create_timer(0.20).timeout
    var back:=create_tween();back.set_parallel(true);back.tween_property(attacker,"position",origin,0.21).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT);back.tween_property(attacker,"scale",Vector2.ONE,0.18);await back.finished
    await _check_enemy_defeated()

func _play_bb_action(slot:int,sparked:bool)->void:
    var unit:=_unit(slot);var def:=_definition(unit);var attacker:Control=unit_nodes[slot];var origin:Vector2=unit_origins[slot]
    var veil:=ColorRect.new();veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.color=Color(0.005,0.015,0.055,0.82);veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(veil)
    var title:=Label.new();title.text="BRAVE BURST";title.position=Vector2(55,270);title.size=Vector2(610,86);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",46);title.add_theme_color_override("font_color",Color("82e1ff"));title.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(title)
    var name:=Label.new();name.text=str(def.get("bb_name","Brave Burst"));name.position=Vector2(70,355);name.size=Vector2(580,58);name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name.add_theme_font_size_override("font_size",27);name.add_theme_color_override("font_color",WHITE);name.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(name)
    for i in range(14):
        var glyph:=Label.new();glyph.text="✦";glyph.position=Vector2(65+(i*73)%600,470+(i%4)*62);glyph.add_theme_font_size_override("font_size",24+(i%3)*8);glyph.add_theme_color_override("font_color",Color(0.4,0.88,1.0,0.0));glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(glyph)
        var gt:=create_tween();gt.set_parallel(true);gt.tween_property(glyph,"modulate:a",1.0,0.16).set_delay(i*0.022);gt.tween_property(glyph,"position",Vector2(325,500),0.52).set_delay(i*0.022);gt.tween_property(glyph,"scale",Vector2(0.35,0.35),0.52).set_delay(i*0.022);gt.tween_callback(glyph.queue_free).set_delay(0.58+i*0.022)
    attacker.z_index=20
    var charge:=create_tween();charge.set_parallel(true);charge.tween_property(attacker,"position",Vector2(260,505),0.32).set_trans(Tween.TRANS_BACK);charge.tween_property(attacker,"scale",Vector2(1.55,1.55),0.32);charge.tween_property(title,"scale",Vector2(1.12,1.12),0.24);await charge.finished
    var flash:=ColorRect.new();flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);flash.color=Color(0.55,0.92,1.0,0.0);flash.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(flash)
    var ft:=create_tween();ft.tween_property(flash,"color:a",0.88,0.06);ft.tween_property(flash,"color:a",0.0,0.23)
    var damage:=_apply_player_damage(slot,true,sparked)
    _enemy_impact(damage,true,true,clampi(int(def.get("hits",5))+2,5,10))
    await get_tree().create_timer(0.44).timeout
    veil.queue_free();title.queue_free();name.queue_free();flash.queue_free()
    var back:=create_tween();back.set_parallel(true);back.tween_property(attacker,"position",origin,0.27);back.tween_property(attacker,"scale",Vector2.ONE,0.24);await back.finished;attacker.z_index=0
    await _check_enemy_defeated()

func _apply_player_damage(slot:int,burst:bool,sparked:bool)->int:
    var unit:=_unit(slot);var def:=_definition(unit);var enemy:=_enemy()
    var atk:=int(game.call("_unit_atk",unit)) if game.has_method("_unit_atk") else int(def.get("base_atk",100))
    var mult:=1.0
    if game.has_method("_element_multiplier"):mult=float(game.call("_element_multiplier",str(def.get("element","Neutral")),str(enemy.get("element","Neutral"))))
    var damage:=int(atk*randf_range(1.65,2.0)*mult) if burst else int(atk*randf_range(0.60,0.82)*mult)
    if sparked:
        var chain:=int(game.get("spark_chain"))+1;game.set("spark_chain",chain);damage=int(damage*(1.18+minf(0.04*chain,0.25)))
    else:game.set("spark_chain",0)
    game.set("enemy_hp",maxi(0,int(game.get("enemy_hp"))-damage))
    unit["bb"]=0 if burst else mini(10,int(unit.get("bb",0))+2+(1 if sparked else 0))
    return damage

func _check_enemy_defeated()->void:
    _sync_state()
    if int(game.get("enemy_hp"))>0:return
    message_label.text="ENEMY DEFEATED!"
    await get_tree().create_timer(0.36).timeout
    acted_slots.clear();action_queue.clear();last_tap_ms=0;last_tap_slot=-1
    if bool(game.get("training_mode")):
        game.call("_training_reset")
    elif game.has_method("_finish_wave"):
        game.call("_finish_wave")
    await get_tree().process_frame
    if _page()=="BATTLE" or _page()=="TRAINING":
        last_enemy_key="";message_label.text="PLAYER PHASE";_sync_state()

func _enemy_phase()->void:
    if _page()!="BATTLE":return
    message_label.text="ENEMY PHASE"
    var banner:=Label.new();banner.text="ENEMY TURN";banner.position=Vector2(80,620);banner.size=Vector2(560,90);banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;banner.add_theme_font_size_override("font_size",36);banner.add_theme_color_override("font_color",Color("ff9b91"));banner.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(banner)
    var bt:=create_tween();bt.tween_property(banner,"modulate:a",0.0,0.55);bt.tween_callback(banner.queue_free)
    await get_tree().create_timer(0.28).timeout
    var alive:Array=[]
    for slot in range(6):
        if _battle_hp(slot)>0:alive.append(slot)
    if alive.is_empty():
        game.call("_defeat");return
    var target:=int(alive[randi()%alive.size()]);var damage:=maxi(1,int(_enemy().get("atk",1))+randi_range(-10,15))
    var hp_array=game.get("battle_hp");var before:=int(hp_array[target]);hp_array[target]=maxi(0,before-damage);game.set("battle_hp",hp_array)
    await _animate_enemy_hit(target,damage)
    var any_alive:=false
    for hp in hp_array:
        if int(hp)>0:any_alive=true
    if not any_alive:
        game.call("_defeat");return
    acted_slots.clear();last_tap_ms=0;last_tap_slot=-1;game.set("spark_chain",0)
    message_label.text="PLAYER PHASE"
    _sync_state()

func _training_cycle_reset()->void:
    message_label.text="TRAINING CYCLE COMPLETE"
    await get_tree().create_timer(0.22).timeout
    acted_slots.clear();last_tap_ms=0;last_tap_slot=-1;game.set("spark_chain",0)
    message_label.text="PLAYER PHASE"

func _enemy_impact(damage:int,sparked:bool,burst:bool,hits:int)->void:
    if enemy_art==null:return
    var base:=enemy_art.position;var shake:=create_tween();shake.tween_property(enemy_art,"position:x",base.x-18,0.035);shake.tween_property(enemy_art,"position:x",base.x+14,0.035);shake.tween_property(enemy_art,"position:x",base.x-8,0.035);shake.tween_property(enemy_art,"position:x",base.x,0.055)
    for i in range(hits):
        var pop:=Label.new();pop.text=str(maxi(1,int(float(damage)/hits)+randi_range(-3,3)));pop.position=Vector2(270+randi_range(-65,65),320+randi_range(-45,45));pop.size=Vector2(180,55);pop.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;pop.add_theme_font_size_override("font_size",32 if burst else 25);pop.add_theme_color_override("font_color",Color("fff0a1"));pop.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(pop)
        var pt:=create_tween();pt.set_parallel(true);pt.tween_property(pop,"position:y",pop.position.y-58,0.40).set_delay(i*0.038);pt.tween_property(pop,"modulate:a",0.0,0.44).set_delay(i*0.038);pt.tween_callback(pop.queue_free).set_delay(0.48+i*0.038)
    if sparked:
        var s:=Label.new();s.text="SPARK!!";s.position=Vector2(230,445);s.size=Vector2(260,68);s.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;s.add_theme_font_size_override("font_size",36);s.add_theme_color_override("font_color",SPARK);s.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(s)
        var st:=create_tween();st.tween_property(s,"scale",Vector2(1.25,1.25),0.09);st.tween_property(s,"scale",Vector2.ONE,0.10);st.tween_property(s,"modulate:a",0.0,0.34);st.tween_callback(s.queue_free)

func _animate_enemy_hit(target:int,damage:int)->void:
    if target<0 or target>=unit_nodes.size():return
    var target_node:Control=unit_nodes[target];var origin:Vector2=unit_origins[target]
    var lunge:=create_tween();lunge.set_parallel(true);lunge.tween_property(enemy_art,"position",Vector2(250,420),0.15).set_trans(Tween.TRANS_QUAD);lunge.tween_property(enemy_art,"scale",Vector2(1.10,1.10),0.15);await lunge.finished
    var flash:=ColorRect.new();flash.position=target_node.position+Vector2(20,35);flash.size=Vector2(160,125);flash.color=Color(1,0.18,0.12,0.58);flash.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(flash)
    var label:=Label.new();label.text="-%d"%damage;label.position=target_node.position+Vector2(40,40);label.size=Vector2(120,50);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",27);label.add_theme_color_override("font_color",Color("ffb0a5"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(label)
    var hit:=create_tween();hit.set_parallel(true);hit.tween_property(target_node,"position:x",origin.x+14,0.05);hit.tween_property(flash,"modulate:a",0.0,0.28);hit.tween_property(label,"position:y",label.position.y-42,0.34);hit.tween_property(label,"modulate:a",0.0,0.34);await hit.finished;flash.queue_free();label.queue_free();target_node.position=origin
    var back:=create_tween();back.set_parallel(true);back.tween_property(enemy_art,"position",Vector2(205,150),0.18);back.tween_property(enemy_art,"scale",Vector2.ONE,0.18);await back.finished

func _all_eligible_acted()->bool:
    var eligible:=_eligible_slots()
    if eligible.is_empty():return false
    for slot in eligible:
        if not acted_slots.has(slot):return false
    return true

func _eligible_slots()->Array:
    var out:Array=[];var single:=int(game.get("training_single_slot")) if bool(game.get("training_mode")) else -1
    for slot in range(6):
        if _battle_hp(slot)<=0:continue
        if single>=0 and slot!=single:continue
        out.append(slot)
    return out

func _eligible_slot(slot:int)->bool:
    var single:=int(game.get("training_single_slot")) if bool(game.get("training_mode")) else -1
    return _battle_hp(slot)>0 and (single<0 or slot==single)

func _slot_pending(slot:int)->bool:
    for item in action_queue:
        if int(item.get("slot",-1))==slot:return true
    return false

func _retreat()->void:
    if queue_running:return
    visible=false;mouse_filter=Control.MOUSE_FILTER_IGNORE;game.call("_home")

func _enemy()->Dictionary:
    var v=game.call("_enemy") if game.has_method("_enemy") else {}
    return v if typeof(v)==TYPE_DICTIONARY else {"name":"Enemy","element":"Neutral"}

func _unit(slot:int)->Dictionary:
    var inv=game.get("inventory");var squad=game.get("squad")
    if typeof(inv)!=TYPE_ARRAY or typeof(squad)!=TYPE_ARRAY or slot>=squad.size():return {}
    var idx:=int(squad[slot]);return inv[idx] if idx>=0 and idx<inv.size() else {}

func _definition(unit:Dictionary)->Dictionary:
    var defs=game.get("unit_defs");var id:=int(unit.get("def_id",0));return defs[id] if typeof(defs)==TYPE_ARRAY and id>=0 and id<defs.size() else {}

func _unit_max_hp(unit:Dictionary)->int:
    return int(game.call("_unit_hp",unit)) if game.has_method("_unit_hp") else 1

func _battle_hp(slot:int)->int:
    var a=game.get("battle_hp");return int(a[slot]) if typeof(a)==TYPE_ARRAY and slot<a.size() else 0

func _unit_texture(def:Dictionary)->Texture2D:
    var filename:=str(def.get("cache",""))
    if filename!="":
        var tex:=_load_texture_any([filename]);if tex!=null:return tex
    return _fallback_texture(str(def.get("element","Neutral")))

func _enemy_texture(enemy:Dictionary)->Texture2D:
    var name:=str(enemy.get("name",""));var filename:=str(ENEMY_ART.get(name,_element_enemy(str(enemy.get("element","Neutral")))));var tex:=_load_texture_any([filename]);return tex if tex!=null else _fallback_texture(str(enemy.get("element","Neutral")))

func _load_texture_any(names:Array)->Texture2D:
    for filename in names:
        var user:="user://bf_assets/%s"%filename
        if FileAccess.file_exists(user):
            var img:=Image.new();if img.load(ProjectSettings.globalize_path(user))==OK:return ImageTexture.create_from_image(img)
        var res:="res://assets/bf/%s"%filename
        if ResourceLoader.exists(res):
            var r=load(res);if r is Texture2D:return r
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
