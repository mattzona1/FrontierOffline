extends Control

const SAVE_VERSION := 5
const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("9fb0ca")
const BG := Color("08101c")
const PANEL := Color("132237")
const PANEL2 := Color("213a5a")
const GREEN := Color("6fe0a4")
const RED := Color("ff7777")

var gems := 20
var gold := 1000
var rank := 1
var rank_xp := 0
var unlocked_quest := 0
var cleared_quests: Array = []
var materials := {"Ember":0,"Tide":0,"Verdant":0,"Volt":0,"Lumen":0,"Dusk":0}
var inventory: Array = []
var squad: Array = [0,1,2,3,4,5]
var selected := 0
var units_page := 0
var current_quest := -1
var current_wave := 0
var enemy_hp := 0
var enemy_max_hp := 0
var battle_hp: Array = []
var training_mode := false
var training_element := "Neutral"
var training_max_hp := 25000
var training_single_slot := -1
var last_attack_ms := 0
var last_attacker := -1
var spark_chain := 0

var header_status: Label
var page_title: Label
var stage: Control
var footer: HBoxContainer
var toast: Label

var unit_defs: Array = [
{"name":"Vargas","title":"Fencer Vargas","element":"Fire","rarity":3,"base_hp":920,"base_atk":410,"hits":5,"bb_name":"Blazing Arc","leader":"Fire units gain 15% ATK.","cache":"vargas_official.png"},
{"name":"Selena","title":"Ice Selena","element":"Water","rarity":3,"base_hp":870,"base_atk":350,"hits":4,"bb_name":"Cresting Surge","leader":"Squad gains 10% max HP.","cache":"selena_official.png"},
{"name":"Lance","title":"Lancer Lance","element":"Earth","rarity":3,"base_hp":1080,"base_atk":330,"hits":3,"bb_name":"Stonewake","leader":"Earth units gain 20% HP.","cache":"lance_official.png"},
{"name":"Eze","title":"Warrior Eze","element":"Thunder","rarity":3,"base_hp":820,"base_atk":445,"hits":6,"bb_name":"Volt Rush","leader":"Spark damage increases by 20%.","cache":"eze_official.png"},
{"name":"Atro","title":"Light Atro","element":"Light","rarity":3,"base_hp":890,"base_atk":390,"hits":5,"bb_name":"Radiant Choir","leader":"Light/Dark damage taken reduced by 12%.","cache":"atro_official.png"},
{"name":"Magress","title":"Iron Magress","element":"Dark","rarity":3,"base_hp":900,"base_atk":430,"hits":5,"bb_name":"Nightfall Edge","leader":"BB damage increases by 18%.","cache":"magress_official.png"},
{"name":"Toren","title":"Ashblade","element":"Fire","rarity":3,"base_hp":960,"base_atk":425,"hits":4,"bb_name":"Pyre Break","leader":"Fire units gain 10% HP and ATK."},
{"name":"Neris","title":"Deepcurrent","element":"Water","rarity":4,"base_hp":1010,"base_atk":455,"hits":7,"bb_name":"Abyssal Tide","leader":"Water units gain 20% ATK."},
{"name":"Oryn","title":"Rootbound","element":"Earth","rarity":4,"base_hp":1220,"base_atk":405,"hits":4,"bb_name":"Worldroot Crash","leader":"Squad gains 15% max HP."},
{"name":"Lyra","title":"Stormstep","element":"Thunder","rarity":4,"base_hp":930,"base_atk":500,"hits":8,"bb_name":"Skybreaker","leader":"Spark damage increases by 30%."},
{"name":"Aurel","title":"Dawn Warden","element":"Light","rarity":4,"base_hp":1050,"base_atk":470,"hits":6,"bb_name":"Solar Verdict","leader":"BB gauge fills faster."},
{"name":"Nyx","title":"Umbral Witch","element":"Dark","rarity":4,"base_hp":940,"base_atk":515,"hits":7,"bb_name":"Black Halo","leader":"BB damage increases by 25%."}
]

var quests := [
{"name":"Cinders on the Road","area":"Ashen Coast","gold":300,"gems":1,"xp":35,"drop":"Ember","waves":[{"name":"Ash Slime","element":"Fire","hp":540,"atk":55},{"name":"Cinder Imp","element":"Fire","hp":700,"atk":70},{"name":"Scoria Brute","element":"Earth","hp":1050,"atk":90}]},
{"name":"Tide Against Flame","area":"Ashen Coast","gold":450,"gems":1,"xp":45,"drop":"Tide","waves":[{"name":"Boiling Wisp","element":"Water","hp":720,"atk":75},{"name":"Coalback Hound","element":"Fire","hp":900,"atk":85},{"name":"Magma Warden","element":"Fire","hp":1350,"atk":105}]},
{"name":"The Broken Beacon","area":"Ashen Coast","gold":650,"gems":2,"xp":60,"drop":"Lumen","waves":[{"name":"Gloom Bat","element":"Dark","hp":780,"atk":80},{"name":"Storm Idol","element":"Thunder","hp":1050,"atk":100},{"name":"Beacon Tyrant","element":"Light","hp":1750,"atk":125}]},
{"name":"Verdant Crossing","area":"Mossvale","gold":800,"gems":1,"xp":75,"drop":"Verdant","waves":[{"name":"Briar Pup","element":"Earth","hp":1100,"atk":110},{"name":"Moss Knight","element":"Earth","hp":1450,"atk":130},{"name":"Thorn Matron","element":"Earth","hp":2200,"atk":155}]},
{"name":"Storm Over Mossvale","area":"Mossvale","gold":1000,"gems":2,"xp":90,"drop":"Volt","waves":[{"name":"Spark Mite","element":"Thunder","hp":1250,"atk":125},{"name":"Cloud Raptor","element":"Thunder","hp":1700,"atk":150},{"name":"Tempest Stag","element":"Thunder","hp":2550,"atk":180}]},
{"name":"Night at the Shrine","area":"Mossvale","gold":1400,"gems":3,"xp":120,"drop":"Dusk","waves":[{"name":"Shade Monk","element":"Dark","hp":1500,"atk":145},{"name":"Moonfang","element":"Dark","hp":2050,"atk":175},{"name":"Shrine Devourer","element":"Dark","hp":3200,"atk":215}]}
]

func _ready() -> void:
    randomize()
    _seed_inventory()
    _load_save()
    _repair_state()
    _build_shell()
    _home()

func _build_shell() -> void:
    var bg := ColorRect.new(); bg.color = BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
    var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.offset_left=10; root.offset_right=-10; root.offset_top=10; root.offset_bottom=-10; root.add_theme_constant_override("separation",6); add_child(root)
    var top := HBoxContainer.new(); top.custom_minimum_size=Vector2(0,60); root.add_child(top)
    var brand := Label.new(); brand.text="BRAVE FRONTIER • OFFLINE"; brand.size_flags_horizontal=Control.SIZE_EXPAND_FILL; brand.add_theme_font_size_override("font_size",24); brand.add_theme_color_override("font_color",GOLD); top.add_child(brand)
    header_status = Label.new(); header_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; header_status.add_theme_font_size_override("font_size",16); top.add_child(header_status)
    page_title = Label.new(); page_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; page_title.add_theme_font_size_override("font_size",24); page_title.add_theme_color_override("font_color",TEXT); root.add_child(page_title)
    var frame := PanelContainer.new(); frame.size_flags_vertical=Control.SIZE_EXPAND_FILL; var fs:=StyleBoxFlat.new(); fs.bg_color=Color("0d1828"); fs.corner_radius_top_left=18;fs.corner_radius_top_right=18;fs.corner_radius_bottom_left=18;fs.corner_radius_bottom_right=18; frame.add_theme_stylebox_override("panel",fs); root.add_child(frame)
    stage = Control.new(); stage.size_flags_vertical=Control.SIZE_EXPAND_FILL; stage.clip_contents=true; frame.add_child(stage)
    toast = Label.new(); toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; toast.add_theme_font_size_override("font_size",15); toast.add_theme_color_override("font_color",GREEN); toast.custom_minimum_size=Vector2(0,26); root.add_child(toast)
    footer = HBoxContainer.new(); footer.custom_minimum_size=Vector2(0,82); footer.add_theme_constant_override("separation",5); root.add_child(footer)
    _refresh_header()

func _clear_stage() -> void:
    for c in stage.get_children(): c.queue_free()
    for c in footer.get_children(): c.queue_free()
    toast.text=""

func _refresh_header() -> void:
    if header_status: header_status.text="R%d   %dG   💎%d"%[rank,gold,gems]

func _nav() -> void:
    footer.add_child(_nav_btn("HOME",_home))
    footer.add_child(_nav_btn("QUEST",_quests))
    footer.add_child(_nav_btn("UNITS",_units))
    footer.add_child(_nav_btn("SUMMON",_summon))
    footer.add_child(_nav_btn("MORE",_more))

func _nav_btn(t:String,cb:Callable)->Button:
    var b:=Button.new();b.text=t;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.add_theme_font_size_override("font_size",15);b.pressed.connect(cb);return b

func _home() -> void:
    training_mode=false; _clear_stage(); page_title.text="GRAND GAIA"; _refresh_header()
    var hero:=PanelContainer.new();hero.position=Vector2(18,18);hero.size=Vector2(664,350);var hs:=StyleBoxFlat.new();hs.bg_color=Color("143758");hs.corner_radius_top_left=20;hs.corner_radius_top_right=20;hs.corner_radius_bottom_left=20;hs.corner_radius_bottom_right=20;hero.add_theme_stylebox_override("panel",hs);stage.add_child(hero)
    var artrow:=HBoxContainer.new();artrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);artrow.offset_left=8;artrow.offset_right=-8;artrow.offset_top=10;artrow.offset_bottom=-45;artrow.add_theme_constant_override("separation",3);hero.add_child(artrow)
    for s in range(6): artrow.add_child(_unit_portrait(int(inventory[int(squad[s])]["def_id"]),Vector2(104,260),false))
    var caption:=Label.new();caption.text="Your squad awaits. Choose your next move.";caption.position=Vector2(20,305);caption.size=Vector2(620,38);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",17);hero.add_child(caption)
    var grid:=GridContainer.new();grid.columns=2;grid.position=Vector2(18,390);grid.size=Vector2(664,390);grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);stage.add_child(grid)
    grid.add_child(_menu_btn("⚔ QUESTS\nContinue the journey",_quests))
    grid.add_child(_menu_btn("✦ SUMMON\nOpen the gate",_summon))
    grid.add_child(_menu_btn("👥 SQUAD\nArrange your heroes",_squad))
    grid.add_child(_menu_btn("🎯 TRAINING\nTest damage & BB",_training))
    _nav()

func _menu_btn(t:String,cb:Callable)->Button:
    var b:=Button.new();b.text=t;b.custom_minimum_size=Vector2(325,180);b.add_theme_font_size_override("font_size",20);var s:=StyleBoxFlat.new();s.bg_color=PANEL2;s.corner_radius_top_left=16;s.corner_radius_top_right=16;s.corner_radius_bottom_left=16;s.corner_radius_bottom_right=16;b.add_theme_stylebox_override("normal",s);b.pressed.connect(cb);return b

func _quests() -> void:
    _clear_stage();page_title.text="QUESTS";_refresh_header()
    var grid:=GridContainer.new();grid.columns=2;grid.position=Vector2(18,20);grid.size=Vector2(664,760);grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);stage.add_child(grid)
    for i in range(6):
        var q:Dictionary=quests[i];var locked:=i>unlocked_quest;var mark:="✓ " if cleared_quests.has(i) else ""
        var b:=Button.new();b.text=("🔒 " if locked else mark)+"%d-%d  %s\n%s\n%d Gold"%[(i/3)+1,(i%3)+1,q["name"],q["area"],q["gold"]];b.custom_minimum_size=Vector2(325,235);b.add_theme_font_size_override("font_size",17);b.disabled=locked
        if not locked:b.pressed.connect(func(idx=i):_start_quest(idx))
        grid.add_child(b)
    _nav()

func _start_quest(idx:int)->void:
    current_quest=idx;current_wave=0;training_mode=false;_prepare_battle();_load_wave()

func _prepare_battle()->void:
    battle_hp.clear();last_attack_ms=0;last_attacker=-1;spark_chain=0
    for s in squad:
        var u:Dictionary=inventory[int(s)];u["bb"]=0;battle_hp.append(_unit_hp(u))

func _load_wave()->void:
    var e:Dictionary=quests[current_quest]["waves"][current_wave];enemy_max_hp=int(e["hp"]);enemy_hp=enemy_max_hp;_battle("Wave %d"%(current_wave+1))

func _battle(message:String="")->void:
    _clear_stage();page_title.text="TRAINING" if training_mode else "BATTLE";_refresh_header()
    var e:=_enemy();var enemy:=PanelContainer.new();enemy.position=Vector2(25,12);enemy.size=Vector2(650,190);var es:=StyleBoxFlat.new();es.bg_color=_element_color(str(e["element"])).darkened(0.55);es.corner_radius_top_left=18;es.corner_radius_top_right=18;es.corner_radius_bottom_left=18;es.corner_radius_bottom_right=18;enemy.add_theme_stylebox_override("panel",es);stage.add_child(enemy)
    var et:=Label.new();et.text="%s\n%s   HP %d / %d"%[e["name"],e["element"],enemy_hp,enemy_max_hp];et.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);et.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;et.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;et.add_theme_font_size_override("font_size",24);enemy.add_child(et)
    var log:=Label.new();log.text=message;log.position=Vector2(20,208);log.size=Vector2(660,45);log.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;log.add_theme_font_size_override("font_size",15);stage.add_child(log)
    var grid:=GridContainer.new();grid.columns=3;grid.position=Vector2(18,260);grid.size=Vector2(664,525);grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);stage.add_child(grid)
    for s in range(6):grid.add_child(_battle_card(s))
    if training_mode:
        footer.add_child(_nav_btn("REFILL",_training_refill));footer.add_child(_nav_btn("FILL BB",_training_fill));footer.add_child(_nav_btn("RESET",_training_reset));footer.add_child(_nav_btn("TRAINING",_training));footer.add_child(_nav_btn("HOME",_home))
    else:
        footer.add_child(_nav_btn("RETREAT",_home));footer.add_child(_nav_btn("QUESTS",_quests));footer.add_child(_nav_btn("HOME",_home))

func _battle_card(slot:int)->Control:
    var u:Dictionary=inventory[int(squad[slot])];var d:Dictionary=unit_defs[int(u["def_id"])]
    var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(216,250)
    box.add_child(_unit_portrait(int(u["def_id"]),Vector2(216,125),false))
    var a:=Button.new();a.text="%s\nHP %d/%d"%[d["name"],maxi(0,int(battle_hp[slot])),_unit_hp(u)];a.custom_minimum_size=Vector2(0,67);a.disabled=int(battle_hp[slot])<=0 or (training_mode and training_single_slot>=0 and slot!=training_single_slot);a.pressed.connect(func(s=slot):_attack(s));box.add_child(a)
    var bb:=Button.new();bb.text="BB %d/10"%int(u["bb"]);bb.custom_minimum_size=Vector2(0,48);bb.disabled=int(u["bb"])<10 or a.disabled;bb.pressed.connect(func(s=slot):_bb(s));box.add_child(bb)
    return box

func _enemy()->Dictionary:
    if training_mode:return {"name":"Training Golem","element":training_element,"atk":0}
    return quests[current_quest]["waves"][current_wave]

func _attack(slot:int)->void:
    var u:Dictionary=inventory[int(squad[slot])];var d:Dictionary=unit_defs[int(u["def_id"])];var e:=_enemy();var now:=Time.get_ticks_msec();var sparked:=last_attack_ms>0 and now-last_attack_ms<=650 and last_attacker!=slot;spark_chain=spark_chain+1 if sparked else 0;last_attack_ms=now;last_attacker=slot
    var dmg:=int(_unit_atk(u)*randf_range(0.60,0.82)*_element_multiplier(str(d["element"]),str(e["element"])));if sparked:dmg=int(dmg*(1.18+minf(0.04*spark_chain,0.25)));enemy_hp=maxi(0,enemy_hp-dmg);u["bb"]=mini(10,int(u["bb"])+2+(1 if sparked else 0));var msg:="%s • %d damage"%[d["name"],dmg];if sparked:msg+=" • SPARK x%d"%(spark_chain+1)
    if training_mode:_battle(msg);elif enemy_hp<=0:_finish_wave();else:_enemy_turn(msg)

func _bb(slot:int)->void:
    var u:Dictionary=inventory[int(squad[slot])];if int(u["bb"])<10:return
    var d:Dictionary=unit_defs[int(u["def_id"])];var e:=_enemy();var dmg:=int(_unit_atk(u)*randf_range(1.65,2.0)*_element_multiplier(str(d["element"]),str(e["element"])));u["bb"]=0;enemy_hp=maxi(0,enemy_hp-dmg);var msg:="✦ %s • %d"%[d["bb_name"],dmg]
    if training_mode:_battle(msg);elif enemy_hp<=0:_finish_wave();else:_enemy_turn(msg)

func _enemy_turn(msg:String)->void:
    var alive:=[];for i in range(6):
        if int(battle_hp[i])>0:alive.append(i)
    if alive.is_empty():_defeat();return
    var slot:=int(alive[randi()%alive.size()]);var dmg:=maxi(1,int(_enemy()["atk"])+randi_range(-10,15));battle_hp[slot]=maxi(0,int(battle_hp[slot])-dmg)
    var any:=false;for hp in battle_hp:
        if int(hp)>0:any=true
    if not any:_defeat();return
    _battle(msg+" • enemy hits %d"%dmg)

func _finish_wave()->void:
    var waves:Array=quests[current_quest]["waves"]
    if current_wave+1<waves.size():current_wave+=1;_load_wave();return
    var q:Dictionary=quests[current_quest];var first:=not cleared_quests.has(current_quest);gold+=int(q["gold"]);rank_xp+=int(q["xp"]);materials[q["drop"]]=int(materials.get(q["drop"],0))+randi_range(1,3)
    if first:gems+=int(q["gems"]);cleared_quests.append(current_quest);unlocked_quest=maxi(unlocked_quest,mini(quests.size()-1,current_quest+1))
    _rank_up();_save();_clear_stage();page_title.text="QUEST CLEAR";_refresh_header();var l:=Label.new();l.text="VICTORY\n+%d Gold%s"%[q["gold"],"  +%d Gems"%q["gems"] if first else ""];l.position=Vector2(60,250);l.size=Vector2(600,250);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.add_theme_font_size_override("font_size",32);l.add_theme_color_override("font_color",GOLD);stage.add_child(l);footer.add_child(_nav_btn("QUESTS",_quests));footer.add_child(_nav_btn("HOME",_home))

func _defeat()->void:_clear_stage();page_title.text="DEFEAT";var l:=Label.new();l.text="Your squad was overwhelmed.";l.position=Vector2(60,300);l.size=Vector2(600,120);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.add_theme_font_size_override("font_size",26);stage.add_child(l);footer.add_child(_nav_btn("RETRY",func():_start_quest(current_quest)));footer.add_child(_nav_btn("HOME",_home))

func _units()->void:
    _clear_stage();page_title.text="UNITS";_refresh_header();var start:=units_page*6;var grid:=GridContainer.new();grid.columns=3;grid.position=Vector2(18,20);grid.size=Vector2(664,700);grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);stage.add_child(grid)
    for i in range(start,mini(start+6,inventory.size())):
        var u:Dictionary=inventory[i];var d:Dictionary=unit_defs[int(u["def_id"])];var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(216,330);box.add_child(_unit_portrait(int(u["def_id"]),Vector2(216,225),true));var b:=Button.new();b.text="Lv.%d • %d★\nHP %d • ATK %d"%[u["level"],_rarity(u),_unit_hp(u),_unit_atk(u)];b.custom_minimum_size=Vector2(0,88);b.pressed.connect(func(idx=i):_unit_details(idx));box.add_child(b);grid.add_child(box)
    footer.add_child(_nav_btn("◀",func():units_page=maxi(0,units_page-1);_units()));footer.add_child(_nav_btn("HOME",_home));footer.add_child(_nav_btn("▶",func():units_page=mini(maxi(0,(inventory.size()-1)/6),units_page+1);_units()))

func _unit_details(idx:int)->void:
    selected=idx;_clear_stage();var u:Dictionary=inventory[idx];var d:Dictionary=unit_defs[int(u["def_id"])];page_title.text=d["name"];_refresh_header();var art:=_unit_portrait(int(u["def_id"]),Vector2(360,500),true);art.position=Vector2(180,30);stage.add_child(art);var info:=Label.new();info.text="%s • %d★ • Lv.%d\nHP %d   ATK %d   Hits %d\nBB: %s\nLeader: %s"%[d["element"],_rarity(u),u["level"],_unit_hp(u),_unit_atk(u),d["hits"],d["bb_name"],d["leader"]];info.position=Vector2(40,555);info.size=Vector2(640,150);info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_theme_font_size_override("font_size",18);stage.add_child(info);var train:=Button.new();train.text="TRAIN • 300 GOLD";train.position=Vector2(80,720);train.size=Vector2(260,70);train.pressed.connect(func():_train(idx));stage.add_child(train);var evo:=Button.new();evo.text="EVOLVE";evo.position=Vector2(380,720);evo.size=Vector2(260,70);evo.pressed.connect(func():_evolve(idx));stage.add_child(evo);footer.add_child(_nav_btn("BACK",_units));footer.add_child(_nav_btn("HOME",_home))

func _train(idx:int)->void:
    if gold<300:toast.text="Not enough Gold";return
    gold-=300;var u:Dictionary=inventory[idx];u["xp"]=int(u["xp"])+120;while int(u["level"])<40 and int(u["xp"])>=80+int(u["level"])*20:u["xp"]-=80+int(u["level"])*20;u["level"]+=1;_save();_unit_details(idx)

func _evolve(idx:int)->void:
    var u:Dictionary=inventory[idx];var d:Dictionary=unit_defs[int(u["def_id"])];if int(u["evo"])>=2:toast.text="Evolution cap reached";return
    var mat:=_mat(str(d["element"]));var need:=2+int(u["evo"]);var cost:=1000+int(u["evo"])*750;if int(materials.get(mat,0))<need or gold<cost:toast.text="Need %d %s + %d Gold"%[need,mat,cost];return
    materials[mat]-=need;gold-=cost;u["evo"]+=1;u["level"]=1;u["xp"]=0;_save();_unit_details(idx)

func _summon()->void:
    _clear_stage();page_title.text="SUMMON GATE";_refresh_header();var bg:=PanelContainer.new();bg.position=Vector2(35,30);bg.size=Vector2(650,560);var s:=StyleBoxFlat.new();s.bg_color=Color("281746");s.corner_radius_top_left=24;s.corner_radius_top_right=24;s.corner_radius_bottom_left=24;s.corner_radius_bottom_right=24;bg.add_theme_stylebox_override("panel",s);stage.add_child(bg);var crystal:=Label.new();crystal.text="✦\n◇\n✦";crystal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);crystal.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;crystal.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;crystal.add_theme_font_size_override("font_size",92);crystal.add_theme_color_override("font_color",Color("c49cff"));bg.add_child(crystal)
    var pull:=Button.new();pull.text="SUMMON • 5 GEMS";pull.position=Vector2(120,630);pull.size=Vector2(480,90);pull.add_theme_font_size_override("font_size",24);pull.pressed.connect(_do_summon);stage.add_child(pull)
    var test:=HBoxContainer.new();test.position=Vector2(105,735);test.size=Vector2(510,65);stage.add_child(test);for n in [5,50,500]:test.add_child(_gem_btn(n))
    _nav()

func _gem_btn(n:int)->Button:
    var b:=Button.new();b.text="+%d"%n;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.pressed.connect(func():gems+=n;_save();_summon());return b

func _do_summon()->void:
    if gems<5:toast.text="Not enough Gems";return
    gems-=5;var chosen:=randi()%unit_defs.size();var owned:=false;for u in inventory:
        if int(u["def_id"])==chosen:owned=true;break
    if owned:gems+=5;_save();_summon_result(chosen,true);return
    inventory.append(_new_unit(chosen));_save();_summon_result(chosen,false)

func _summon_result(def_id:int,duplicate:bool)->void:
    _clear_stage();var d:Dictionary=unit_defs[def_id];page_title.text="SUMMON RESULT";_refresh_header();var art:=_unit_portrait(def_id,Vector2(420,570),true);art.position=Vector2(150,40);stage.add_child(art);var l:=Label.new();l.text=("DUPLICATE • 5 GEMS REFUNDED" if duplicate else "%s joined your party!"%d["name"]);l.position=Vector2(50,640);l.size=Vector2(620,80);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.add_theme_font_size_override("font_size",22);l.add_theme_color_override("font_color",GREEN if duplicate else GOLD);stage.add_child(l);footer.add_child(_nav_btn("AGAIN",_summon));footer.add_child(_nav_btn("UNITS",_units));footer.add_child(_nav_btn("HOME",_home))

func _squad()->void:
    _clear_stage();page_title.text="SQUAD";_refresh_header();var grid:=GridContainer.new();grid.columns=3;grid.position=Vector2(18,20);grid.size=Vector2(664,760);grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);stage.add_child(grid)
    for s in range(6):
        var idx:=int(squad[s]);var u:Dictionary=inventory[idx];var box:=VBoxContainer.new();box.custom_minimum_size=Vector2(216,350);box.add_child(_unit_portrait(int(u["def_id"]),Vector2(216,245),true));var b:=Button.new();b.text=("★ LEADER" if s==0 else "SLOT %d"%(s+1));b.custom_minimum_size=Vector2(0,80);b.pressed.connect(func(slot=s):_choose_squad(slot));box.add_child(b);grid.add_child(box)
    _nav()

func _choose_squad(slot:int)->void:
    _clear_stage();page_title.text="CHOOSE SLOT %d"%(slot+1);var grid:=GridContainer.new();grid.columns=3;grid.position=Vector2(18,20);grid.size=Vector2(664,760);stage.add_child(grid);for i in range(mini(6,inventory.size())):
        var u:Dictionary=inventory[i];var b:=Button.new();b.custom_minimum_size=Vector2(216,240);b.text="%s\nLv.%d"%[unit_defs[int(u["def_id"])]["name"],u["level"]];b.icon=_texture(int(u["def_id"]));b.expand_icon=true;b.pressed.connect(func(idx=i,s=slot):squad[s]=idx;_save();_squad());grid.add_child(b)
    footer.add_child(_nav_btn("BACK",_squad));footer.add_child(_nav_btn("HOME",_home))

func _training()->void:
    training_mode=false;_clear_stage();page_title.text="TRAINING HALL";_refresh_header();var title:=Label.new();title.text="TRAINING GOLEM\nNo rewards • No costs";title.position=Vector2(80,35);title.size=Vector2(560,100);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",28);stage.add_child(title)
    var hp:=HBoxContainer.new();hp.position=Vector2(75,165);hp.size=Vector2(570,70);stage.add_child(hp);for n in [5000,25000,100000]:var b:=Button.new();b.text="%dK"%(n/1000);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.pressed.connect(func(v=n):training_max_hp=v;toast.text="Target HP: %d"%v);hp.add_child(b)
    var el:=GridContainer.new();el.columns=3;el.position=Vector2(75,260);el.size=Vector2(570,180);stage.add_child(el);for e in ["Fire","Water","Earth","Thunder","Light","Dark"]:var b:=Button.new();b.text=e;b.custom_minimum_size=Vector2(185,80);b.pressed.connect(func(v=e):training_element=v;toast.text="Element: %s"%v);el.add_child(b)
    var modes:=VBoxContainer.new();modes.position=Vector2(120,485);modes.size=Vector2(480,270);stage.add_child(modes);var all:=Button.new();all.text="TEST FULL SQUAD";all.custom_minimum_size=Vector2(0,80);all.pressed.connect(func():_start_training(-1));modes.add_child(all);var single:=Button.new();single.text="TEST LEADER ONLY";single.custom_minimum_size=Vector2(0,80);single.pressed.connect(func():_start_training(0));modes.add_child(single)
    _nav()

func _start_training(slot:int)->void:
    training_mode=true;training_single_slot=slot;enemy_max_hp=training_max_hp;enemy_hp=enemy_max_hp;_prepare_battle();_battle("Training ready")
func _training_refill()->void:
    for s in range(6):battle_hp[s]=_unit_hp(inventory[int(squad[s])]);_battle("HP restored")
func _training_fill()->void:
    for s in range(6):inventory[int(squad[s])]["bb"]=10;_battle("BB charged")
func _training_reset()->void:enemy_hp=training_max_hp;enemy_max_hp=training_max_hp;_battle("Target restored")

func _more()->void:
    _clear_stage();page_title.text="MORE";_refresh_header();var grid:=GridContainer.new();grid.columns=2;grid.position=Vector2(70,120);grid.size=Vector2(580,520);stage.add_child(grid);grid.add_child(_menu_btn("MATERIALS\nEvolution stock",_materials));grid.add_child(_menu_btn("TRAINING\nDamage sandbox",_training));grid.add_child(_menu_btn("+50 GEMS\nTester shortcut",func():gems+=50;_save();_more()));grid.add_child(_menu_btn("HOME\nReturn",_home));_nav()

func _materials()->void:
    _clear_stage();page_title.text="MATERIALS";var grid:=GridContainer.new();grid.columns=2;grid.position=Vector2(100,100);grid.size=Vector2(520,560);stage.add_child(grid);for k in materials.keys():var l:=Label.new();l.text="%s\n× %d"%[k,materials[k]];l.custom_minimum_size=Vector2(250,170);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.add_theme_font_size_override("font_size",24);grid.add_child(l);_nav()

func _unit_portrait(def_id:int,size:Vector2,show_name:bool)->VBoxContainer:
    var box:=VBoxContainer.new();box.custom_minimum_size=size;box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;var tex:=TextureRect.new();tex.custom_minimum_size=Vector2(size.x,maxf(80,size.y-(32 if show_name else 0)));tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;tex.texture=_texture(def_id);box.add_child(tex);if show_name:var l:=Label.new();l.text=unit_defs[def_id]["name"] if def_id>=0 and def_id<unit_defs.size() else "Unit";l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.add_theme_font_size_override("font_size",15);box.add_child(l);return box

func _texture(def_id:int)->Texture2D:
    if def_id>=0 and def_id<6:
        var p:="user://bf_assets/%s"%unit_defs[def_id]["cache"];if FileAccess.file_exists(p):var img:=Image.new();if img.load(ProjectSettings.globalize_path(p))==OK:return ImageTexture.create_from_image(img)
    var gt:=GradientTexture2D.new();var g:=Gradient.new();var c:=_element_color(unit_defs[def_id]["element"] if def_id>=0 and def_id<unit_defs.size() else "Neutral");g.colors=PackedColorArray([c,Color("0a1220")]);gt.gradient=g;gt.width=256;gt.height=256;return gt

func _new_unit(id:int)->Dictionary:return {"def_id":id,"level":1,"xp":0,"evo":0,"bb":0,"locked":false}
func _seed_inventory()->void:
    if inventory.is_empty():for i in range(6):inventory.append(_new_unit(i))
func _repair_state()->void:
    if inventory.size()<6:inventory.clear();_seed_inventory()
    if squad.size()!=6:squad=[0,1,2,3,4,5]
    for i in range(6):squad[i]=clampi(int(squad[i]),0,inventory.size()-1)
func _unit_hp(u:Dictionary)->int:return int(float(unit_defs[int(u["def_id"])]["base_hp"])*(1.0+(int(u["level"])-1)*0.035+int(u["evo"])*0.22))
func _unit_atk(u:Dictionary)->int:return int(float(unit_defs[int(u["def_id"])]["base_atk"])*(1.0+(int(u["level"])-1)*0.032+int(u["evo"])*0.20))
func _rarity(u:Dictionary)->int:return mini(6,int(unit_defs[int(u["def_id"])]["rarity"])+int(u["evo"]))
func _rank_up()->void:
    var need:=100+rank*25;while rank_xp>=need:rank_xp-=need;rank+=1;need=100+rank*25
func _mat(e:String)->String:
    match e:
        "Fire":return "Ember"
        "Water":return "Tide"
        "Earth":return "Verdant"
        "Thunder":return "Volt"
        "Light":return "Lumen"
        _:return "Dusk"
func _element_color(e:String)->Color:
    match e:
        "Fire":return Color("d95145")
        "Water":return Color("348dd1")
        "Earth":return Color("4c9b58")
        "Thunder":return Color("d5ad38")
        "Light":return Color("d8c97d")
        "Dark":return Color("8a5aac")
        _:return Color("52677e")
func _element_multiplier(a:String,d:String)->float:
    if d=="Neutral":return 1.0
    if (a=="Fire" and d=="Earth") or (a=="Earth" and d=="Thunder") or (a=="Thunder" and d=="Water") or (a=="Water" and d=="Fire") or (a=="Light" and d=="Dark") or (a=="Dark" and d=="Light"):return 1.35
    if (d=="Fire" and a=="Earth") or (d=="Earth" and a=="Thunder") or (d=="Thunder" and a=="Water") or (d=="Water" and a=="Fire"):return 0.75
    return 1.0
func _save()->void:
    var f:=FileAccess.open("user://save.json",FileAccess.WRITE);if f:f.store_string(JSON.stringify({"save_version":SAVE_VERSION,"gems":gems,"gold":gold,"rank":rank,"rank_xp":rank_xp,"unlocked_quest":unlocked_quest,"cleared_quests":cleared_quests,"materials":materials,"squad":squad,"inventory":inventory,"selected":selected}))
func _load_save()->void:
    if not FileAccess.file_exists("user://save.json"):return
    var f:=FileAccess.open("user://save.json",FileAccess.READ);if not f:return
    var d=JSON.parse_string(f.get_as_text());if typeof(d)!=TYPE_DICTIONARY:return
    gems=maxi(0,int(d.get("gems",gems)));gold=maxi(0,int(d.get("gold",gold)));rank=maxi(1,int(d.get("rank",rank)));rank_xp=maxi(0,int(d.get("rank_xp",0)));unlocked_quest=clampi(int(d.get("unlocked_quest",0)),0,quests.size()-1);selected=maxi(0,int(d.get("selected",0)))
    if typeof(d.get("cleared_quests",[]))==TYPE_ARRAY:cleared_quests=d.get("cleared_quests",[])
    if typeof(d.get("inventory",null))==TYPE_ARRAY and d["inventory"].size()>=6:inventory=d["inventory"]
    if typeof(d.get("squad",null))==TYPE_ARRAY and d["squad"].size()==6:squad=d["squad"]
    if typeof(d.get("materials",null))==TYPE_DICTIONARY:
        for k in materials.keys():materials[k]=maxi(0,int(d["materials"].get(k,0)))
