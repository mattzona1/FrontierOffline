extends Control

var game: Node
var active := false
var battlefield: Control
var enemy_nodes: Array = []
var unit_cards: Array = []
var bb_bars: Array = []
var hp_bars: Array = []
var unit_buttons: Array = []
var busy := false
var acted: Array = []
var turn_no := 1

const GOLD:=Color("d9aa42")
const TEXT:=Color("f6f1e7")
const BLUE:=Color("53aee8")
const ENEMY_TEX={
    "Burny":"enemy_moerus.png",
    "Squirty":"enemy_mizurus.png",
    "Mossy":"enemy_morirus.png",
    "Sparky":"enemy_rairus.png",
    "Glowy":"enemy_caitsith.png",
    "Gloomy":"enemy_imp.png",
    "King Sparky":"enemy_rairus.png"
}

func _ready()->void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index=700
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    visible=false
    process_mode=Node.PROCESS_MODE_ALWAYS

func _process(_delta:float)->void:
    if game==null or not is_instance_valid(game):return
    var title=_page()
    var should=title=="BATTLE" and int(game.get("current_quest"))==0
    if should and not active:_enter()
    elif not should and active and not busy:_leave()
    if active and not busy:_sync()

func _page()->String:
    var p=game.get("page_title");return str(p.text) if p!=null and is_instance_valid(p) else ""

func _enter()->void:
    active=true;visible=true;mouse_filter=Control.MOUSE_FILTER_STOP;acted.clear();turn_no=1;_build()

func _leave()->void:
    active=false;visible=false;mouse_filter=Control.MOUSE_FILTER_IGNORE
    for c in get_children():c.queue_free()
    battlefield=null;enemy_nodes.clear();unit_cards.clear();bb_bars.clear();hp_bars.clear();unit_buttons.clear()

func _build()->void:
    for c in get_children():c.queue_free()
    battlefield=Control.new();battlefield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);battlefield.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(battlefield)
    _build_header();_build_prairie();_build_enemy_group();_build_target_bar();_build_unit_grid();_build_items()
    _sync()

func _build_header()->void:
    var bar:=ColorRect.new();bar.position=Vector2(0,0);bar.size=Vector2(720,82);bar.color=Color("22384b");battlefield.add_child(bar)
    _label("● %05d"%int(game.get("gold")),Vector2(18,8),Vector2(210,54),20,Color("ffe28a"))
    _label("● %05d"%int(game.get("rank_xp")),Vector2(250,8),Vector2(210,54),20,Color("72cfff"))
    _label("▣ %02d"%(int(game.get("current_wave"))+1),Vector2(470,8),Vector2(120,54),20,TEXT)
    _button("MENU",Vector2(590,9),Vector2(116,56),func():game.call("_home"),18)

func _build_prairie()->void:
    var sky:=ColorRect.new();sky.position=Vector2(0,82);sky.size=Vector2(720,350);sky.color=Color("6db9e7");battlefield.add_child(sky)
    var hills:=Polygon2D.new();hills.polygon=PackedVector2Array([Vector2(0,330),Vector2(70,260),Vector2(145,310),Vector2(230,235),Vector2(315,310),Vector2(420,220),Vector2(520,300),Vector2(615,245),Vector2(720,315),Vector2(720,430),Vector2(0,430)]);hills.color=Color("487f48");battlefield.add_child(hills)
    var ground:=ColorRect.new();ground.position=Vector2(0,350);ground.size=Vector2(720,390);ground.color=Color("6f9b3f");battlefield.add_child(ground)
    for i in range(18):
        var g:=Label.new();g.text="✦";g.position=Vector2((i*83)%690,360+(i*71)%320);g.add_theme_font_size_override("font_size",12+(i%3)*4);g.add_theme_color_override("font_color",Color(0.8,1.0,0.45,0.22));g.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(g)
    _label("MISTRAL • ADVENTURER'S PRAIRIE",Vector2(20,88),Vector2(500,40),17,Color("fff6ce"))

func _build_enemy_group()->void:
    enemy_nodes.clear()
    var active_name:=str(_enemy().get("name","Enemy"))
    var support:=_support_enemies(active_name)
    var names=[support[0],active_name,support[1]]
    var positions=[Vector2(75,245),Vector2(240,175),Vector2(490,260)]
    var sizes=[Vector2(150,180),Vector2(250,280),Vector2(150,180)]
    for i in range(3):
        var tex:=TextureRect.new();tex.position=positions[i];tex.size=sizes[i];tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;tex.texture=_enemy_texture(names[i]);tex.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(tex);enemy_nodes.append(tex)

func _support_enemies(active_name:String)->Array:
    match active_name:
        "Burny":return ["Squirty","Mossy"]
        "Squirty":return ["Burny","Mossy"]
        "Mossy":return ["Squirty","Sparky"]
        "Glowy":return ["Gloomy","Sparky"]
        _:return ["Sparky","Glowy"]

func _build_target_bar()->void:
    _label("TURN %d"%turn_no,Vector2(250,602),Vector2(220,30),17,TEXT,HORIZONTAL_ALIGNMENT_CENTER)
    var plate:=PanelContainer.new();plate.position=Vector2(12,632);plate.size=Vector2(696,92);var s:=StyleBoxFlat.new();s.bg_color=Color("172331");s.border_width_top=3;s.border_width_bottom=3;s.border_color=GOLD;plate.add_theme_stylebox_override("panel",s);battlefield.add_child(plate)
    var enemy:=_enemy();_label(str(enemy.get("name","Enemy")),Vector2(85,640),Vector2(380,34),22,TEXT)
    var elem:=Label.new();elem.text="●";elem.position=Vector2(24,641);elem.size=Vector2(50,40);elem.add_theme_font_size_override("font_size",30);elem.add_theme_color_override("font_color",_element_color(str(enemy.get("element","Neutral"))));battlefield.add_child(elem)
    var hp:=ProgressBar.new();hp.name="EnemyHP";hp.position=Vector2(28,682);hp.size=Vector2(650,24);hp.max_value=maxi(1,int(game.get("enemy_max_hp")));hp.value=int(game.get("enemy_hp"));hp.show_percentage=false;battlefield.add_child(hp)
    _label("HP:%d/%d"%[int(game.get("enemy_hp")),int(game.get("enemy_max_hp"))],Vector2(430,646),Vector2(245,30),16,TEXT,HORIZONTAL_ALIGNMENT_RIGHT)
    _button("AUTO",Vector2(592,576),Vector2(110,54),func():_auto_turn(),17)

func _build_unit_grid()->void:
    unit_cards.clear();bb_bars.clear();hp_bars.clear();unit_buttons.clear()
    var origins=[Vector2(8,742),Vector2(366,742),Vector2(8,880),Vector2(366,880),Vector2(8,1018),Vector2(366,1018)]
    for slot in range(6):
        var p:=PanelContainer.new();p.position=origins[slot];p.size=Vector2(346,126);var st:=StyleBoxFlat.new();st.bg_color=Color("241b14");st.border_width_left=3;st.border_width_right=3;st.border_width_top=3;st.border_width_bottom=3;st.border_color=Color("c89945");st.corner_radius_top_left=10;st.corner_radius_top_right=10;st.corner_radius_bottom_left=10;st.corner_radius_bottom_right=10;p.add_theme_stylebox_override("panel",st);battlefield.add_child(p);unit_cards.append(p)
        var unit:=_unit(slot);var def:=_def(unit)
        var portrait:=TextureRect.new();portrait.position=Vector2(6,6);portrait.size=Vector2(108,112);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture=_unit_texture(int(unit.get("def_id",0)));portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;p.add_child(portrait)
        var el:=Label.new();el.text="●";el.position=Vector2(6,88);el.size=Vector2(32,28);el.add_theme_font_size_override("font_size",24);el.add_theme_color_override("font_color",_element_color(str(def.get("element","Neutral"))));el.mouse_filter=Control.MOUSE_FILTER_IGNORE;p.add_child(el)
        var name:=Label.new();name.text=str(def.get("title",def.get("name","Unit")));name.position=Vector2(118,5);name.size=Vector2(216,28);name.add_theme_font_size_override("font_size",15);name.add_theme_color_override("font_color",TEXT);name.mouse_filter=Control.MOUSE_FILTER_IGNORE;p.add_child(name)
        var hptext:=Label.new();hptext.name="HPText";hptext.position=Vector2(118,30);hptext.size=Vector2(216,24);hptext.add_theme_font_size_override("font_size",14);hptext.add_theme_color_override("font_color",TEXT);p.add_child(hptext)
        var hp:=ProgressBar.new();hp.position=Vector2(118,55);hp.size=Vector2(214,20);hp.show_percentage=false;p.add_child(hp);hp_bars.append(hp)
        var bb:=ProgressBar.new();bb.position=Vector2(118,82);bb.size=Vector2(214,23);bb.max_value=10;bb.show_percentage=false;p.add_child(bb);bb_bars.append(bb)
        var bbl:=Label.new();bbl.text="BRAVE BURST";bbl.position=Vector2(122,82);bbl.size=Vector2(150,23);bbl.add_theme_font_size_override("font_size",12);bbl.add_theme_color_override("font_color",Color("79d9ff"));bbl.mouse_filter=Control.MOUSE_FILTER_IGNORE;p.add_child(bbl)
        var tap:=Button.new();tap.flat=true;tap.position=Vector2(0,0);tap.size=Vector2(346,78);tap.focus_mode=Control.FOCUS_NONE;tap.pressed.connect(func(s=slot):_normal_attack(s));p.add_child(tap);unit_buttons.append(tap)
        var burst:=Button.new();burst.flat=true;burst.position=Vector2(114,78);burst.size=Vector2(220,42);burst.focus_mode=Control.FOCUS_NONE;burst.pressed.connect(func(s=slot):_burst(s));p.add_child(burst);p.set_meta("burst",burst)

func _build_items()->void:
    var title:=Label.new();title.text="ITEMS";title.position=Vector2(0,1150);title.size=Vector2(720,34);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",17);title.add_theme_color_override("font_color",TEXT);battlefield.add_child(title)
    var names=["Cure","High Cure","Atk Potion","Holy Water","Stimulant"]
    var counts=[10,7,5,10,10]
    for i in range(5):
        var p:=PanelContainer.new();p.position=Vector2(5+i*143,1182);p.size=Vector2(137,94);var s:=StyleBoxFlat.new();s.bg_color=Color("111923");s.border_width_left=2;s.border_width_right=2;s.border_width_top=2;s.border_width_bottom=2;s.border_color=Color("5c7084");p.add_theme_stylebox_override("panel",s);battlefield.add_child(p)
        _label_in(p,"×%d"%counts[i],Vector2(6,4),Vector2(125,25),14,TEXT,HORIZONTAL_ALIGNMENT_CENTER)
        _label_in(p,"◆",Vector2(34,23),Vector2(70,40),30,[Color("7fe38c"),Color("65d67c"),Color("e26464"),Color("e1ba55"),Color("a9b1c0")][i],HORIZONTAL_ALIGNMENT_CENTER)
        _label_in(p,names[i],Vector2(4,64),Vector2(129,24),12,TEXT,HORIZONTAL_ALIGNMENT_CENTER)

func _normal_attack(slot:int)->void:
    if busy or acted.has(slot) or _hp(slot)<=0:return
    acted.append(slot);busy=true
    var card:Control=unit_cards[slot];var origin=card.position
    var tw=create_tween();tw.tween_property(card,"position:y",origin.y-14,0.07);tw.tween_property(card,"position:y",origin.y,0.10);await tw.finished
    var unit:=_unit(slot);var def:=_def(unit);var atk:=int(game.call("_unit_atk",unit));var damage:=maxi(1,int(atk*randf_range(0.55,0.72)))
    game.set("enemy_hp",maxi(0,int(game.get("enemy_hp"))-damage));_damage_pop(damage)
    await _drop_battle_crystals(slot,randi_range(1,3))
    if int(game.get("enemy_hp"))<=0:await _enemy_defeated();busy=false;return
    busy=false;_sync()
    if acted.size()>=_alive_count():await _enemy_phase()

func _burst(slot:int)->void:
    if busy or acted.has(slot) or _hp(slot)<=0:return
    var unit:=_unit(slot);if int(unit.get("bb",0))<10:return
    acted.append(slot);busy=true;unit["bb"]=0
    var veil:=ColorRect.new();veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.color=Color(0.02,0.05,0.13,0.82);battlefield.add_child(veil)
    var def:=_def(unit);var title:=Label.new();title.text="BRAVE BURST";title.position=Vector2(40,280);title.size=Vector2(640,80);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",44);title.add_theme_color_override("font_color",Color("8fe8ff"));battlefield.add_child(title)
    var name:=Label.new();name.text=str(def.get("bb_name","Brave Burst"));name.position=Vector2(40,360);name.size=Vector2(640,54);name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name.add_theme_font_size_override("font_size",25);name.add_theme_color_override("font_color",TEXT);battlefield.add_child(name)
    for i in range(8):
        var ray:=ColorRect.new();ray.position=Vector2(360,460);ray.size=Vector2(6,180);ray.rotation=float(i)*PI/4.0;ray.pivot_offset=Vector2(3,180);ray.color=Color(0.3,0.85,1.0,0.65);battlefield.add_child(ray)
        var rt=create_tween();rt.tween_property(ray,"modulate:a",0.0,0.48);rt.tween_callback(ray.queue_free)
    await get_tree().create_timer(0.36).timeout
    var atk:=int(game.call("_unit_atk",unit));var damage:=maxi(1,int(atk*randf_range(1.6,2.05)));game.set("enemy_hp",maxi(0,int(game.get("enemy_hp"))-damage));_damage_pop(damage,true)
    await get_tree().create_timer(0.28).timeout;veil.queue_free();title.queue_free();name.queue_free()
    if int(game.get("enemy_hp"))<=0:await _enemy_defeated();busy=false;return
    busy=false;_sync();if acted.size()>=_alive_count():await _enemy_phase()

func _drop_battle_crystals(slot:int,count:int)->void:
    var unit:=_unit(slot)
    for i in range(count):
        var crystal:=Label.new();crystal.text="◆";crystal.position=Vector2(330+randi_range(-45,45),470+randi_range(-35,35));crystal.size=Vector2(40,40);crystal.add_theme_font_size_override("font_size",28);crystal.add_theme_color_override("font_color",Color("5fd3ff"));crystal.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(crystal)
        var target:Vector2=unit_cards[slot].position+Vector2(250,95);var tw=create_tween();tw.tween_property(crystal,"position",target,0.28+0.04*i).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN);await tw.finished;crystal.queue_free();unit["bb"]=mini(10,int(unit.get("bb",0))+1)
    _sync()

func _enemy_phase()->void:
    busy=true
    await get_tree().create_timer(0.22).timeout
    var alive=[];for s in range(6):if _hp(s)>0:alive.append(s)
    if alive.is_empty():game.call("_defeat");busy=false;return
    var target=int(alive[randi()%alive.size()]);var arr=game.get("battle_hp");var dmg=maxi(1,int(_enemy().get("atk",20))+randi_range(-5,8));arr[target]=maxi(0,int(arr[target])-dmg);game.set("battle_hp",arr)
    var card:Control=unit_cards[target];var ox=card.position.x;var tw=create_tween();tw.tween_property(card,"position:x",ox+12,0.05);tw.tween_property(card,"position:x",ox-9,0.05);tw.tween_property(card,"position:x",ox,0.06);await tw.finished
    acted.clear();turn_no+=1;busy=false;_sync()

func _enemy_defeated()->void:
    busy=true;_damage_pop(0,false,true);await get_tree().create_timer(0.35).timeout;acted.clear()
    if game.has_method("_finish_wave"):game.call("_finish_wave")
    await get_tree().process_frame
    if _page()=="BATTLE":_build()
    busy=false

func _auto_turn()->void:
    if busy:return
    for s in range(6):
        if not acted.has(s) and _hp(s)>0:
            _normal_attack(s)
            break

func _sync()->void:
    if battlefield==null:return
    var hpnode=battlefield.get_node_or_null("EnemyHP")
    if hpnode!=null:hpnode.max_value=maxi(1,int(game.get("enemy_max_hp")));hpnode.value=int(game.get("enemy_hp"))
    for s in range(mini(6,unit_cards.size())):
        var unit:=_unit(s);var maxhp=int(game.call("_unit_hp",unit));var now=_hp(s);hp_bars[s].max_value=maxhp;hp_bars[s].value=now;bb_bars[s].value=int(unit.get("bb",0));unit_buttons[s].disabled=busy or acted.has(s) or now<=0
        var txt=unit_cards[s].get_node_or_null("HPText");if txt!=null:txt.text="HP %d/%d"%[now,maxhp]
        var burst=unit_cards[s].get_meta("burst");if burst!=null:burst.disabled=int(unit.get("bb",0))<10 or busy or acted.has(s) or now<=0

func _damage_pop(value:int,big:=false,defeated:=false)->void:
    var l:=Label.new();l.text="ENEMY DEFEATED!" if defeated else str(value);l.position=Vector2(245,365);l.size=Vector2(230,70);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.add_theme_font_size_override("font_size",40 if big else 30);l.add_theme_color_override("font_color",Color("fff0a1"));battlefield.add_child(l);var tw=create_tween();tw.set_parallel(true);tw.tween_property(l,"position:y",l.position.y-55,0.38);tw.tween_property(l,"modulate:a",0.0,0.42);tw.tween_callback(l.queue_free).set_delay(0.44)

func _enemy()->Dictionary:
    if bool(game.get("training_mode")):return {"name":"Training Golem","element":"Neutral","atk":0}
    var qs=game.get("quests");return qs[int(game.get("current_quest"))]["waves"][int(game.get("current_wave"))]
func _unit(slot:int)->Dictionary:
    var inv=game.get("inventory");var squad=game.get("squad");return inv[int(squad[slot])]
func _def(unit:Dictionary)->Dictionary:
    var defs=game.get("unit_defs");return defs[int(unit.get("def_id",0))]
func _hp(slot:int)->int:
    var arr=game.get("battle_hp");return int(arr[slot]) if slot<arr.size() else 0
func _alive_count()->int:
    var n=0;for s in range(6):if _hp(s)>0:n+=1;return n
func _enemy_texture(name:String)->Texture2D:
    var f=str(ENEMY_TEX.get(name,"enemy_rairus.png"));return _texture(f)
func _unit_texture(id:int)->Texture2D:
    var defs=game.get("unit_defs");if typeof(defs)!=TYPE_ARRAY or id<0 or id>=defs.size():return null
    return _texture(str(defs[id].get("cache","")))
func _texture(filename:String)->Texture2D:
    if filename=="":return null
    var path="user://bf_assets/%s"%filename;if not FileAccess.file_exists(path):path="res://assets/bf/%s"%filename
    if not FileAccess.file_exists(path):return null
    var img:=Image.new();if img.load(ProjectSettings.globalize_path(path))!=OK:return null
    return ImageTexture.create_from_image(img)
func _element_color(e:String)->Color:
    match e:
        "Fire":return Color("ef5a37")
        "Water":return Color("42a9f5")
        "Earth":return Color("70bf52")
        "Thunder":return Color("edcd45")
        "Light":return Color("efe7a0")
        "Dark":return Color("8d59c8")
        _:return Color("aab4c0")
func _label(text:String,pos:Vector2,size:Vector2,fs:int,color:Color,align:=HORIZONTAL_ALIGNMENT_LEFT)->Label:
    var l:=Label.new();l.text=text;l.position=pos;l.size=size;l.add_theme_font_size_override("font_size",fs);l.add_theme_color_override("font_color",color);l.horizontal_alignment=align;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;battlefield.add_child(l);return l
func _label_in(parent:Node,text:String,pos:Vector2,size:Vector2,fs:int,color:Color,align:=HORIZONTAL_ALIGNMENT_LEFT)->Label:
    var l:=Label.new();l.text=text;l.position=pos;l.size=size;l.add_theme_font_size_override("font_size",fs);l.add_theme_color_override("font_color",color);l.horizontal_alignment=align;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func _button(text:String,pos:Vector2,size:Vector2,cb:Callable,fs:int)->Button:
    var b:=Button.new();b.text=text;b.position=pos;b.size=size;b.add_theme_font_size_override("font_size",fs);b.pressed.connect(cb);battlefield.add_child(b);return b
