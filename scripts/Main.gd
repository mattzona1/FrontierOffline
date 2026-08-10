extends Control

const PANEL := Color("162238")
const PANEL_2 := Color("223451")
const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("9fb0ca")
const RED := Color("ff6b6b")
const GREEN := Color("6ee7a8")
const BLUE := Color("6eb6ff")
const SAVE_VERSION := 2

var gems := 20
var gold := 1000
var rank := 1
var rank_xp := 0
var selected := 0
var unlocked_quest := 0
var cleared_quests: Array = []
var materials := {"Ember":0,"Tide":0,"Verdant":0,"Volt":0,"Lumen":0,"Dusk":0}
var body: VBoxContainer
var status: Label
var current_quest: Dictionary = {}
var current_wave := 0
var enemy_hp := 0
var enemy_max_hp := 0
var battle_active := false
var last_attack_ms := 0
var last_attacker := -1
var spark_chain := 0
var battle_hp: Array = []
var squad: Array = [0,1,2,3,4,5]
var inventory: Array = []

var unit_defs := [
 {"name":"Kael","title":"Ember Squire","element":"Fire","rarity":3,"base_hp":920,"base_atk":410,"hits":5,"bb_name":"Blazing Arc","leader":"Fire units gain 15% ATK."},
 {"name":"Mira","title":"Tide Mender","element":"Water","rarity":3,"base_hp":870,"base_atk":350,"hits":4,"bb_name":"Cresting Surge","leader":"Squad gains 10% max HP."},
 {"name":"Bram","title":"Verdant Guard","element":"Earth","rarity":3,"base_hp":1080,"base_atk":330,"hits":3,"bb_name":"Stonewake","leader":"Earth units gain 20% HP."},
 {"name":"Rin","title":"Gale Runner","element":"Thunder","rarity":3,"base_hp":820,"base_atk":445,"hits":6,"bb_name":"Volt Rush","leader":"Spark damage increases by 20%."},
 {"name":"Sera","title":"Lumen Adept","element":"Light","rarity":3,"base_hp":890,"base_atk":390,"hits":5,"bb_name":"Radiant Choir","leader":"Light/Dark damage taken reduced by 12%."},
 {"name":"Veyr","title":"Dusk Reaver","element":"Dark","rarity":3,"base_hp":900,"base_atk":430,"hits":5,"bb_name":"Nightfall Edge","leader":"BB damage increases by 18%."},
 {"name":"Toren","title":"Ashblade","element":"Fire","rarity":3,"base_hp":960,"base_atk":425,"hits":4,"bb_name":"Pyre Break","leader":"Fire units gain 10% HP and ATK."},
 {"name":"Neris","title":"Deepcurrent","element":"Water","rarity":4,"base_hp":1010,"base_atk":455,"hits":7,"bb_name":"Abyssal Tide","leader":"Water units gain 20% ATK."},
 {"name":"Oryn","title":"Rootbound","element":"Earth","rarity":4,"base_hp":1220,"base_atk":405,"hits":4,"bb_name":"Worldroot Crash","leader":"Squad gains 15% max HP."},
 {"name":"Lyra","title":"Stormstep","element":"Thunder","rarity":4,"base_hp":930,"base_atk":500,"hits":8,"bb_name":"Skybreaker","leader":"Spark damage increases by 30%."},
 {"name":"Aurel","title":"Dawn Warden","element":"Light","rarity":4,"base_hp":1050,"base_atk":470,"hits":6,"bb_name":"Solar Verdict","leader":"BB gauge fills 1 point faster from attacks."},
 {"name":"Nyx","title":"Umbral Witch","element":"Dark","rarity":4,"base_hp":940,"base_atk":515,"hits":7,"bb_name":"Black Halo","leader":"BB damage increases by 25%."}
]

var quests := [
 {"name":"1-1 Cinders on the Road","area":"ASHEN COAST","reward_gold":300,"reward_gems":1,"rank_xp":35,"drop":"Ember","waves":[{"name":"Ash Slime","element":"Fire","hp":540,"atk":55},{"name":"Cinder Imp","element":"Fire","hp":700,"atk":70},{"name":"Scoria Brute","element":"Earth","hp":1050,"atk":90}]},
 {"name":"1-2 Tide Against Flame","area":"ASHEN COAST","reward_gold":450,"reward_gems":1,"rank_xp":45,"drop":"Tide","waves":[{"name":"Boiling Wisp","element":"Water","hp":720,"atk":75},{"name":"Coalback Hound","element":"Fire","hp":900,"atk":85},{"name":"Magma Warden","element":"Fire","hp":1350,"atk":105}]},
 {"name":"1-3 The Broken Beacon","area":"ASHEN COAST","reward_gold":650,"reward_gems":2,"rank_xp":60,"drop":"Lumen","waves":[{"name":"Gloom Bat","element":"Dark","hp":780,"atk":80},{"name":"Storm Idol","element":"Thunder","hp":1050,"atk":100},{"name":"Beacon Tyrant","element":"Light","hp":1750,"atk":125}]},
 {"name":"2-1 Verdant Crossing","area":"MOSSVALE","reward_gold":800,"reward_gems":1,"rank_xp":75,"drop":"Verdant","waves":[{"name":"Briar Pup","element":"Earth","hp":1100,"atk":110},{"name":"Moss Knight","element":"Earth","hp":1450,"atk":130},{"name":"Thorn Matron","element":"Earth","hp":2200,"atk":155}]},
 {"name":"2-2 Storm Over Mossvale","area":"MOSSVALE","reward_gold":1000,"reward_gems":2,"rank_xp":90,"drop":"Volt","waves":[{"name":"Spark Mite","element":"Thunder","hp":1250,"atk":125},{"name":"Cloud Raptor","element":"Thunder","hp":1700,"atk":150},{"name":"Tempest Stag","element":"Thunder","hp":2550,"atk":180}]},
 {"name":"2-3 Night at the Shrine","area":"MOSSVALE","reward_gold":1400,"reward_gems":3,"rank_xp":120,"drop":"Dusk","waves":[{"name":"Shade Monk","element":"Dark","hp":1500,"atk":145},{"name":"Moonfang","element":"Dark","hp":2050,"atk":175},{"name":"Shrine Devourer","element":"Dark","hp":3200,"atk":215}]}
]

func _ready() -> void:
 randomize()
 _seed_inventory()
 _load_save()
 var root := VBoxContainer.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.offset_left=16; root.offset_right=-16; root.offset_top=18; root.offset_bottom=-18
 root.add_theme_constant_override("separation",10)
 add_child(root)
 var title:=Label.new(); title.text="FRONTIER OFFLINE"; title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",34); title.add_theme_color_override("font_color",GOLD); root.add_child(title)
 status=Label.new(); status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; status.add_theme_font_size_override("font_size",17); status.add_theme_color_override("font_color",MUTED); root.add_child(status)
 var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; root.add_child(scroll)
 body=VBoxContainer.new(); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",10); scroll.add_child(body)
 _home()

func _seed_inventory() -> void:
 if inventory.size()>0: return
 for i in range(6): inventory.append(_new_unit(i))

func _new_unit(def_id:int) -> Dictionary:
 return {"def_id":def_id,"level":1,"xp":0,"evo":0,"bb":0,"locked":false}

func _home() -> void:
 battle_active=false; _clear(); _refresh()
 _heading("GRAND GAIA","Milestone build • progression systems online")
 _add_button("QUESTS",_quest_select)
 _add_button("SQUAD",_squad_menu)
 _add_button("UNITS",_units_menu)
 _add_button("SUMMON GATE",_summon)
 _add_button("MATERIALS",_materials)
 _add_button("SAVE GAME",func(): _save(); _home())

func _quest_select() -> void:
 _clear(); _heading("QUESTS","Clear quests to unlock the next route")
 for i in range(quests.size()):
  var q:Dictionary=quests[i]
  if i>unlocked_quest:
   var locked:=_button("LOCKED • %s"%q.name,func(): pass); locked.disabled=true; body.add_child(locked); continue
  var clear_mark:="CLEAR • " if cleared_quests.has(i) else ""
  body.add_child(_button("%s%s\n%s • %d Gold • %d Gem%s"%[clear_mark,q.name,q.area,q.reward_gold,q.reward_gems,"s" if q.reward_gems!=1 else ""],func(index=i): _start_quest(index)))
 _add_button("BACK",_home)

func _start_quest(index:int) -> void:
 current_quest=quests[index].duplicate(true); current_quest["index"]=index; current_wave=0; battle_active=true; last_attack_ms=0; last_attacker=-1; spark_chain=0; battle_hp.clear()
 for slot in squad:
  var inst:Dictionary=inventory[int(slot)]; inst.bb=0; battle_hp.append(_unit_hp(inst))
 _load_wave()

func _load_wave() -> void:
 var e:Dictionary=current_quest.waves[current_wave]; enemy_max_hp=int(e.hp); enemy_hp=enemy_max_hp; spark_chain=0; _render_battle("Wave %d begins!"%(current_wave+1))

func _render_battle(message:String="") -> void:
 _clear(); _refresh(); var e:Dictionary=current_quest.waves[current_wave]
 _heading("%s • WAVE %d/%d"%[current_quest.name,current_wave+1,current_quest.waves.size()],"%s • %s"%[e.name,e.element])
 var bar:=ProgressBar.new(); bar.max_value=enemy_max_hp; bar.value=enemy_hp; bar.custom_minimum_size=Vector2(0,34); bar.show_percentage=false; body.add_child(bar)
 var hp:=Label.new(); hp.text="Enemy HP %d / %d"%[enemy_hp,enemy_max_hp]; hp.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hp.add_theme_font_size_override("font_size",18); body.add_child(hp)
 var log:=Label.new(); log.text=message if message!="" else "Tap a unit to attack. Full BB gauges unlock Brave Burst."; log.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; log.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; log.custom_minimum_size=Vector2(0,70); log.add_theme_font_size_override("font_size",17); body.add_child(log)
 var grid:=GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",8); body.add_child(grid)
 for s in range(squad.size()):
  var inv_index:=int(squad[s]); var u:Dictionary=inventory[inv_index]; var d:Dictionary=unit_defs[int(u.def_id)]
  var wrap:=VBoxContainer.new(); wrap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  var dead:=int(battle_hp[s])<=0
  var atk:=_button("%s%s Lv.%d\n%s • HP %d/%d\nATK %d"%["LEADER • " if s==0 else "",d.name,u.level,d.element,maxi(0,int(battle_hp[s])),_unit_hp(u),_unit_atk(u)],func(slot=s): _attack_unit(slot)); atk.disabled=dead; atk.custom_minimum_size=Vector2(0,112); wrap.add_child(atk)
  var bb:=_button("BB %d/10 • %s"%[u.bb,d.bb_name],func(slot=s): _brave_burst(slot)); bb.disabled=dead or int(u.bb)<10; bb.custom_minimum_size=Vector2(0,60); wrap.add_child(bb); grid.add_child(wrap)
 _add_button("RETREAT",_home)

func _attack_unit(slot:int) -> void:
 if not battle_active or enemy_hp<=0 or int(battle_hp[slot])<=0: return
 var inv_index:=int(squad[slot]); var u:Dictionary=inventory[inv_index]; var d:Dictionary=unit_defs[int(u.def_id)]; var e:Dictionary=current_quest.waves[current_wave]
 var now:=Time.get_ticks_msec(); var sparked:=last_attack_ms>0 and now-last_attack_ms<=650 and last_attacker!=slot
 spark_chain=spark_chain+1 if sparked else 0; last_attack_ms=now; last_attacker=slot
 var damage:=int(_unit_atk(u)*randf_range(0.58,0.78)*_element_multiplier(str(d.element),str(e.element))*_leader_attack_multiplier(d.element,false))
 if sparked: damage=int(damage*(1.18+minf(float(spark_chain)*0.05,0.30))*_leader_spark_multiplier())
 enemy_hp=maxi(0,enemy_hp-damage); u.bb=mini(10,int(u.bb)+2+_leader_bb_bonus()+(1 if sparked else 0))
 var msg:="%s hits for %d"%[d.name,damage]; if sparked: msg+=" • SPARK x%d!"%(spark_chain+1)
 if enemy_hp<=0: _finish_wave(msg)
 else: _enemy_turn(msg)

func _brave_burst(slot:int) -> void:
 if not battle_active or enemy_hp<=0 or int(battle_hp[slot])<=0: return
 var inv_index:=int(squad[slot]); var u:Dictionary=inventory[inv_index]; if int(u.bb)<10: return
 var d:Dictionary=unit_defs[int(u.def_id)]; var e:Dictionary=current_quest.waves[current_wave]
 var damage:=int(_unit_atk(u)*randf_range(1.55,1.90)*_element_multiplier(str(d.element),str(e.element))*_leader_attack_multiplier(d.element,true)); u.bb=0; enemy_hp=maxi(0,enemy_hp-damage); spark_chain=0
 var msg:="%s unleashes %s! %d damage!"%[d.name,d.bb_name,damage]
 if enemy_hp<=0: _finish_wave(msg)
 else: _enemy_turn(msg)

func _enemy_turn(player_msg:String) -> void:
 var alive:Array=[]; for i in range(battle_hp.size()):
  if int(battle_hp[i])>0: alive.append(i)
 if alive.is_empty(): _battle_defeat(); return
 var e:Dictionary=current_quest.waves[current_wave]; var slot:=int(alive[randi()%alive.size()]); var inv_index:=int(squad[slot]); var u:Dictionary=inventory[inv_index]; var d:Dictionary=unit_defs[int(u.def_id)]
 var damage:=maxi(1,int(e.atk)+randi_range(-10,15)); damage=int(float(damage)*_leader_defense_multiplier(d.element)); battle_hp[slot]=maxi(0,int(battle_hp[slot])-damage)
 if int(battle_hp[slot])<=0: player_msg+="\n%s is knocked out!"%d.name
 else: u.bb=mini(10,int(u.bb)+1)
 var any_alive:=false; for value in battle_hp:
  if int(value)>0: any_alive=true
 if not any_alive: _battle_defeat(); return
 _render_battle("%s\n%s retaliates against %s for %d."%[player_msg,e.name,d.name,damage])

func _finish_wave(player_msg:String) -> void:
 if current_wave+1<current_quest.waves.size(): current_wave+=1; _load_wave(); return
 battle_active=false; var qi:=int(current_quest.index); var first_clear:=not cleared_quests.has(qi)
 gold+=int(current_quest.reward_gold); gems+=int(current_quest.reward_gems) if first_clear else 0; rank_xp+=int(current_quest.rank_xp); var drop:=str(current_quest.drop); materials[drop]=int(materials.get(drop,0))+randi_range(1,3)
 if first_clear: cleared_quests.append(qi); unlocked_quest=maxi(unlocked_quest,mini(quests.size()-1,qi+1))
 _apply_rank_xp(); for slot in squad: _add_unit_xp(int(slot),20+qi*8)
 _save(); _clear(); _refresh(); _heading("QUEST CLEAR",current_quest.name)
 var t:=Label.new(); t.text="%s\n\n+%d Gold\n%s\n+%d Rank XP\n+%s material"%[player_msg,current_quest.reward_gold,("+%d Gems"%current_quest.reward_gems) if first_clear else "Gem reward already claimed",current_quest.rank_xp,drop]; t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; t.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; t.add_theme_font_size_override("font_size",22); t.add_theme_color_override("font_color",GREEN); body.add_child(t)
 _add_button("CONTINUE",_quest_select); _add_button("HOME",_home)

func _battle_defeat() -> void:
 battle_active=false; _clear(); _heading("DEFEAT","The squad was overwhelmed."); var l:=Label.new(); l.text="No rewards were lost. Strengthen your units, change your leader, or adjust the squad and try again."; l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; l.add_theme_font_size_override("font_size",20); body.add_child(l); _add_button("RETURN",_quest_select)

func _squad_menu() -> void:
 _clear(); _heading("SQUAD","Slot 1 is the Leader and activates its Leader Skill")
 for s in range(squad.size()):
  var inv_index:=int(squad[s]); var u:Dictionary=inventory[inv_index]; var d:Dictionary=unit_defs[int(u.def_id)]
  body.add_child(_button("%sSLOT %d • %s Lv.%d\n%s"%["LEADER • " if s==0 else "",s+1,d.name,u.level,d.leader if s==0 else d.element],func(slot=s): _choose_squad_unit(slot)))
 _add_button("BACK",_home)

func _choose_squad_unit(slot:int) -> void:
 _clear(); _heading("CHOOSE UNIT","Replace squad slot %d"%(slot+1))
 for i in range(inventory.size()):
  if squad.has(i) and int(squad[slot])!=i: continue
  var u:Dictionary=inventory[i]; var d:Dictionary=unit_defs[int(u.def_id)]; body.add_child(_button("%s Lv.%d • %s • %d★\nHP %d • ATK %d"%[d.name,u.level,d.element,_unit_rarity(u),_unit_hp(u),_unit_atk(u)],func(index=i): squad[slot]=index; _save(); _squad_menu()))
 _add_button("CANCEL",_squad_menu)

func _units_menu() -> void:
 _clear(); _heading("UNIT INVENTORY","%d units owned • tap one to manage"%inventory.size())
 for i in range(inventory.size()):
  var u:Dictionary=inventory[i]; var d:Dictionary=unit_defs[int(u.def_id)]; body.add_child(_button("%s%s, %s\n%s • %d★ • Lv.%d • XP %d/%d\nHP %d • ATK %d"%["🔒 " if bool(u.locked) else "",d.name,d.title,d.element,_unit_rarity(u),u.level,u.xp,_xp_needed(u.level),_unit_hp(u),_unit_atk(u)],func(index=i): _unit_detail(index)))
 _add_button("BACK",_home)

func _unit_detail(index:int) -> void:
 var u:Dictionary=inventory[index]; var d:Dictionary=unit_defs[int(u.def_id)]; _clear(); _heading("%s, %s"%[d.name,d.title],"%s • %d★ • Level %d"%[d.element,_unit_rarity(u),u.level])
 var info:=Label.new(); info.text="HP %d\nATK %d\nHits %d\nBB: %s\nLeader Skill: %s\n\nEvolution stage %d/2"%[_unit_hp(u),_unit_atk(u),d.hits,d.bb_name,d.leader,u.evo]; info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; info.add_theme_font_size_override("font_size",20); info.add_theme_color_override("font_color",TEXT); body.add_child(info)
 _add_button("FUSE TRAINING • 500 GOLD",func(): _fuse_training(index))
 var mat:=_element_material(str(d.element)); var evo_cost:=3+int(u.evo)*2; var evo:=_button("EVOLVE • %d %s + %d GOLD"%[evo_cost,mat,1500+int(u.evo)*1000],func(): _evolve(index)); evo.disabled=int(u.evo)>=2 or int(u.level)<10+int(u.evo)*10; body.add_child(evo)
 _add_button("%s UNIT"%("UNLOCK" if bool(u.locked) else "LOCK"),func(): u.locked=not bool(u.locked); _save(); _unit_detail(index))
 _add_button("BACK",_units_menu)

func _fuse_training(index:int) -> void:
 if gold<500: _notice("Not enough Gold.",func(): _unit_detail(index)); return
 gold-=500; _add_unit_xp(index,55); _save(); _unit_detail(index)

func _evolve(index:int) -> void:
 var u:Dictionary=inventory[index]; if int(u.evo)>=2: return
 var d:Dictionary=unit_defs[int(u.def_id)]; var mat:=_element_material(str(d.element)); var cost_mat:=3+int(u.evo)*2; var cost_gold:=1500+int(u.evo)*1000
 if int(materials.get(mat,0))<cost_mat or gold<cost_gold: _notice("You need %d %s materials and %d Gold."%[cost_mat,mat,cost_gold],func(): _unit_detail(index)); return
 materials[mat]=int(materials[mat])-cost_mat; gold-=cost_gold; u.evo=int(u.evo)+1; u.level=1; u.xp=0; _save(); _unit_detail(index)

func _summon() -> void:
 _clear(); _heading("SUMMON GATE","5 Gems • duplicates become separate usable units")
 var banner:=Label.new(); banner.text="Rare pool\n3★ 70% • 4★ 30%\nEarn Gems from first quest clears."; banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; banner.add_theme_font_size_override("font_size",20); banner.add_theme_color_override("font_color",MUTED); body.add_child(banner)
 _add_button("SUMMON • 5 GEMS",func(): _do_summon())
 _add_button("BACK",_home)

func _do_summon() -> void:
 if gems<5: _notice("Not enough Gems.",_summon); return
 gems-=5; var pool:Array=[]; for i in range(unit_defs.size()):
  if int(unit_defs[i].rarity)==3: pool.append(i)
 var four:Array=[]; for i in range(unit_defs.size()):
  if int(unit_defs[i].rarity)==4: four.append(i)
 var chosen:=int(four[randi()%four.size()]) if randf()<0.30 else int(pool[randi()%pool.size()]); inventory.append(_new_unit(chosen)); _save(); var d:Dictionary=unit_defs[chosen]
 _clear(); _heading("SUMMON RESULT","A new unit answers the Gate!"); var l:=Label.new(); l.text="%s, %s\n%s • %d★\n\nAdded to Unit Inventory."%[d.name,d.title,d.element,d.rarity]; l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; l.add_theme_font_size_override("font_size",27); l.add_theme_color_override("font_color",GOLD); body.add_child(l); _add_button("SUMMON AGAIN",_summon); _add_button("UNITS",_units_menu)

func _materials() -> void:
 _clear(); _heading("MATERIALS","Quest drops used for evolution")
 for key in materials.keys():
  var l:=Label.new(); l.text="%s Material     x%d"%[key,materials[key]]; l.add_theme_font_size_override("font_size",22); l.add_theme_color_override("font_color",TEXT); body.add_child(l)
 _add_button("BACK",_home)

func _unit_hp(u:Dictionary) -> int:
 var d:Dictionary=unit_defs[int(u.def_id)]; return int(float(d.base_hp)*(1.0+(int(u.level)-1)*0.035+int(u.evo)*0.22))
func _unit_atk(u:Dictionary) -> int:
 var d:Dictionary=unit_defs[int(u.def_id)]; return int(float(d.base_atk)*(1.0+(int(u.level)-1)*0.032+int(u.evo)*0.20))
func _unit_rarity(u:Dictionary) -> int:
 return mini(6,int(unit_defs[int(u.def_id)].rarity)+int(u.evo))
func _xp_needed(level:int) -> int: return 80+level*20
func _add_unit_xp(index:int,amount:int) -> void:
 var u:Dictionary=inventory[index]; u.xp=int(u.xp)+amount
 while int(u.level)<40 and int(u.xp)>=_xp_needed(int(u.level)):
  u.xp=int(u.xp)-_xp_needed(int(u.level)); u.level=int(u.level)+1
func _apply_rank_xp() -> void:
 var need:=100+rank*25
 while rank_xp>=need:
  rank_xp-=need; rank+=1; need=100+rank*25
func _element_material(element:String) -> String:
 match element:
  "Fire": return "Ember"
  "Water": return "Tide"
  "Earth": return "Verdant"
  "Thunder": return "Volt"
  "Light": return "Lumen"
  _: return "Dusk"

func _leader_def() -> Dictionary:
 if squad.is_empty(): return unit_defs[0]
 return unit_defs[int(inventory[int(squad[0])].def_id)]
func _leader_attack_multiplier(element:String,is_bb:bool) -> float:
 var d:=_leader_def(); var m:=1.0; var text:=str(d.leader)
 if text.contains("15% ATK") and element=="Fire": m*=1.15
 if text.contains("20% ATK") and element=="Water": m*=1.20
 if text.contains("10% HP and ATK") and element=="Fire": m*=1.10
 if is_bb and text.contains("18%."): m*=1.18
 if is_bb and text.contains("25%."): m*=1.25
 return m
func _leader_spark_multiplier() -> float:
 var text:=str(_leader_def().leader); if text.contains("30%."): return 1.30; if text.contains("20%."): return 1.20; return 1.0
func _leader_bb_bonus() -> int: return 1 if str(_leader_def().leader).contains("1 point faster") else 0
func _leader_defense_multiplier(element:String) -> float:
 var text:=str(_leader_def().leader); return 0.88 if text.contains("Light/Dark") and (element=="Light" or element=="Dark") else 1.0

func _element_multiplier(attacker:String,defender:String) -> float:
 if (attacker=="Fire" and defender=="Earth") or (attacker=="Earth" and defender=="Thunder") or (attacker=="Thunder" and defender=="Water") or (attacker=="Water" and defender=="Fire"): return 1.35
 if (defender=="Fire" and attacker=="Earth") or (defender=="Earth" and attacker=="Thunder") or (defender=="Thunder" and attacker=="Water") or (defender=="Water" and attacker=="Fire"): return 0.75
 if (attacker=="Light" and defender=="Dark") or (attacker=="Dark" and defender=="Light"): return 1.35
 return 1.0

func _heading(a:String,b:String) -> void:
 var h:=Label.new(); h.text=a; h.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; h.add_theme_font_size_override("font_size",29); h.add_theme_color_override("font_color",GOLD); body.add_child(h)
 var s:=Label.new(); s.text=b; s.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; s.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; s.add_theme_font_size_override("font_size",17); s.add_theme_color_override("font_color",MUTED); body.add_child(s)
func _add_button(label:String,callback:Callable) -> void: body.add_child(_button(label,callback))
func _button(label:String,callback:Callable) -> Button:
 var b:=Button.new(); b.text=label; b.custom_minimum_size=Vector2(0,82); b.add_theme_font_size_override("font_size",20); b.add_theme_color_override("font_color",TEXT); var style:=StyleBoxFlat.new(); style.bg_color=PANEL_2; style.corner_radius_top_left=14; style.corner_radius_top_right=14; style.corner_radius_bottom_left=14; style.corner_radius_bottom_right=14; b.add_theme_stylebox_override("normal",style); b.pressed.connect(callback); return b
func _notice(text:String,back:Callable) -> void:
 _clear(); _heading("NOTICE",text); _add_button("BACK",back)
func _clear() -> void:
 for child in body.get_children(): child.queue_free()
func _refresh() -> void:
 status.text="Rank %d • XP %d/%d     Gold %d     Gems %d"%[rank,rank_xp,100+rank*25,gold,gems]

func _save() -> void:
 var f:=FileAccess.open("user://save.json",FileAccess.WRITE); if not f: return
 f.store_string(JSON.stringify({"save_version":SAVE_VERSION,"gems":gems,"gold":gold,"rank":rank,"rank_xp":rank_xp,"selected":selected,"unlocked_quest":unlocked_quest,"cleared_quests":cleared_quests,"materials":materials,"squad":squad,"inventory":inventory}))

func _load_save() -> void:
 if not FileAccess.file_exists("user://save.json"): return
 var f:=FileAccess.open("user://save.json",FileAccess.READ); if not f: return
 var data=JSON.parse_string(f.get_as_text()); if typeof(data)!=TYPE_DICTIONARY: return
 gems=int(data.get("gems",gems)); gold=int(data.get("gold",gold)); rank=int(data.get("rank",rank)); rank_xp=int(data.get("rank_xp",0)); selected=int(data.get("selected",0)); unlocked_quest=int(data.get("unlocked_quest",0))
 var cq=data.get("cleared_quests",[]); if typeof(cq)==TYPE_ARRAY: cleared_quests=cq
 var mats=data.get("materials",{}); if typeof(mats)==TYPE_DICTIONARY:
  for key in materials.keys(): materials[key]=int(mats.get(key,materials[key]))
 var inv=data.get("inventory",null)
 if typeof(inv)==TYPE_ARRAY and inv.size()>=6: inventory=inv
 for u in inventory:
  if not u.has("level"): u.level=1
  if not u.has("xp"): u.xp=0
  if not u.has("evo"): u.evo=0
  if not u.has("bb"): u.bb=0
  if not u.has("locked"): u.locked=false
 var sq=data.get("squad",null)
 if typeof(sq)==TYPE_ARRAY and sq.size()==6: squad=sq
 for i in range(squad.size()): squad[i]=clampi(int(squad[i]),0,inventory.size()-1)
