extends Control

const BUILD_LABEL := "VISUAL MILESTONE • v0.2.0"
const SAVE_VERSION := 4
const GOLD := Color("f6c85f")
const TEXT := Color("f4f7ff")
const MUTED := Color("aebbd2")
const PANEL := Color("17243a")
const PANEL_2 := Color("243a5b")
const PANEL_3 := Color("102033")
const GREEN := Color("72e6a4")
const RED := Color("ff7272")

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

var body: VBoxContainer
var status: Label
var current_quest: Dictionary = {}
var current_wave := 0
var enemy_hp := 0
var enemy_max_hp := 0
var battle_hp: Array = []
var battle_active := false
var last_attack_ms := 0
var last_attacker := -1
var spark_chain := 0
var training_mode := false
var training_single_slot := -1
var training_element := "Neutral"
var training_max_hp := 25000

var unit_defs: Array = [
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

var quests: Array = [
    {"name":"1-1 Cinders on the Road","area":"ASHEN COAST","reward_gold":300,"reward_gems":1,"rank_xp":35,"drop":"Ember","waves":[{"name":"Ash Slime","element":"Fire","hp":540,"atk":55},{"name":"Cinder Imp","element":"Fire","hp":700,"atk":70},{"name":"Scoria Brute","element":"Earth","hp":1050,"atk":90}]},
    {"name":"1-2 Tide Against Flame","area":"ASHEN COAST","reward_gold":450,"reward_gems":1,"rank_xp":45,"drop":"Tide","waves":[{"name":"Boiling Wisp","element":"Water","hp":720,"atk":75},{"name":"Coalback Hound","element":"Fire","hp":900,"atk":85},{"name":"Magma Warden","element":"Fire","hp":1350,"atk":105}]},
    {"name":"1-3 The Broken Beacon","area":"ASHEN COAST","reward_gold":650,"reward_gems":2,"rank_xp":60,"drop":"Lumen","waves":[{"name":"Gloom Bat","element":"Dark","hp":780,"atk":80},{"name":"Storm Idol","element":"Thunder","hp":1050,"atk":100},{"name":"Beacon Tyrant","element":"Light","hp":1750,"atk":125}]},
    {"name":"2-1 Verdant Crossing","area":"MOSSVALE","reward_gold":800,"reward_gems":1,"rank_xp":75,"drop":"Verdant","waves":[{"name":"Briar Pup","element":"Earth","hp":1100,"atk":110},{"name":"Moss Knight","element":"Earth","hp":1450,"atk":130},{"name":"Thorn Matron","element":"Earth","hp":2200,"atk":155}]},
    {"name":"2-2 Storm Over Mossvale","area":"MOSSVALE","reward_gold":1000,"reward_gems":2,"rank_xp":90,"drop":"Volt","waves":[{"name":"Spark Mite","element":"Thunder","hp":1250,"atk":125},{"name":"Cloud Raptor","element":"Thunder","hp":1700,"atk":150},{"name":"Tempest Stag","element":"Thunder","hp":2550,"atk":180}]},
    {"name":"2-3 Night at the Shrine","area":"MOSSVALE","reward_gold":1400,"reward_gems":3,"rank_xp":120,"drop":"Dusk","waves":[{"name":"Shade Monk","element":"Dark","hp":1500,"atk":145},{"name":"Moonfang","element":"Dark","hp":2050,"atk":175},{"name":"Shrine Devourer","element":"Dark","hp":3200,"atk":215}]}
]

func _ready() -> void:
    randomize()
    _build_shell()
    _seed_inventory()
    _load_save_safe()
    _repair_state()
    _home()

func _build_shell() -> void:
    var bg := ColorRect.new()
    bg.color = Color("07101d")
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var glow := ColorRect.new()
    glow.color = Color("0e2941")
    glow.position = Vector2(0, 0)
    glow.size = Vector2(720, 210)
    add_child(glow)

    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 14
    root.offset_right = -14
    root.offset_top = 14
    root.offset_bottom = -14
    root.add_theme_constant_override("separation", 8)
    add_child(root)

    var title := Label.new()
    title.text = "FRONTIER OFFLINE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", GOLD)
    root.add_child(title)

    var build := Label.new()
    build.text = BUILD_LABEL
    build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    build.add_theme_font_size_override("font_size", 15)
    build.add_theme_color_override("font_color", GREEN)
    root.add_child(build)

    status = Label.new()
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 17)
    status.add_theme_color_override("font_color", MUTED)
    root.add_child(status)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)

    body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 9)
    scroll.add_child(body)

func _home() -> void:
    battle_active = false
    training_mode = false
    _clear()
    _refresh()
    _hero_panel("GRAND GAIA", "Visual milestone is active", Color("173e62"))

    var squad_strip := HBoxContainer.new()
    squad_strip.add_theme_constant_override("separation", 5)
    body.add_child(squad_strip)
    for s in range(6):
        squad_strip.add_child(_mini_unit_card(s))

    _add_button("⚔  QUESTS", _quest_select)
    _add_button("🎯  TRAINING HALL", _training_menu)
    _add_button("✦  SUMMON GATE", _summon)
    _add_button("👥  SQUAD", _squad_menu)
    _add_button("📖  UNITS", _units_menu)
    _add_button("◇  MATERIALS", _materials)

    _heading("TESTER GEM CONSOLE", "These buttons are intentionally permanent in your private test build")
    var gems_row := HBoxContainer.new()
    gems_row.add_theme_constant_override("separation", 8)
    body.add_child(gems_row)
    gems_row.add_child(_small_button("+5", func(): _give_gems(5)))
    gems_row.add_child(_small_button("+50", func(): _give_gems(50)))
    gems_row.add_child(_small_button("+500", func(): _give_gems(500)))

func _give_gems(amount: int) -> void:
    gems += amount
    _save()
    _home()

func _mini_unit_card(slot: int) -> Control:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style := StyleBoxFlat.new()
    var idx := int(squad[slot])
    var u: Dictionary = inventory[idx]
    var d: Dictionary = unit_defs[int(u["def_id"])]
    style.bg_color = _element_color(str(d["element"])).darkened(0.45)
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    style.corner_radius_bottom_left = 10
    style.corner_radius_bottom_right = 10
    panel.add_theme_stylebox_override("panel", style)
    var box := VBoxContainer.new()
    panel.add_child(box)
    var icon := Label.new()
    icon.text = _element_symbol(str(d["element"]))
    icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon.add_theme_font_size_override("font_size", 24)
    box.add_child(icon)
    var name := Label.new()
    name.text = str(d["name"]).substr(0, 4)
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.add_theme_font_size_override("font_size", 12)
    box.add_child(name)
    return panel

func _hero_panel(title_text: String, subtitle: String, color: Color) -> void:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 18
    style.corner_radius_top_right = 18
    style.corner_radius_bottom_left = 18
    style.corner_radius_bottom_right = 18
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = GOLD.darkened(0.25)
    panel.add_theme_stylebox_override("panel", style)
    panel.custom_minimum_size = Vector2(0, 120)
    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    panel.add_child(box)
    var t := Label.new()
    t.text = title_text
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    t.add_theme_font_size_override("font_size", 30)
    t.add_theme_color_override("font_color", GOLD)
    box.add_child(t)
    var s := Label.new()
    s.text = subtitle
    s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    s.add_theme_font_size_override("font_size", 17)
    s.add_theme_color_override("font_color", TEXT)
    box.add_child(s)
    body.add_child(panel)

func _quest_select() -> void:
    _clear()
    _heading("QUESTS", "Clear routes to unlock the next battle")
    for i in range(quests.size()):
        var q: Dictionary = quests[i]
        if i > unlocked_quest:
            var locked := _button("🔒  %s" % q["name"], func(): pass)
            locked.disabled = true
            body.add_child(locked)
        else:
            var mark := "✓ " if cleared_quests.has(i) else ""
            body.add_child(_button("%s%s\n%s • %d Gold" % [mark, q["name"], q["area"], q["reward_gold"]], func(index=i): _start_quest(index)))
    _add_button("BACK", _home)

func _start_quest(index: int) -> void:
    training_mode = false
    current_quest = quests[index].duplicate(true)
    current_quest["index"] = index
    current_wave = 0
    battle_active = true
    _prepare_battle()
    _load_wave()

func _prepare_battle() -> void:
    last_attack_ms = 0
    last_attacker = -1
    spark_chain = 0
    battle_hp.clear()
    for slot in squad:
        var u: Dictionary = inventory[int(slot)]
        u["bb"] = 0
        battle_hp.append(_unit_hp(u))

func _load_wave() -> void:
    var waves: Array = current_quest["waves"]
    var e: Dictionary = waves[current_wave]
    enemy_max_hp = int(e["hp"])
    enemy_hp = enemy_max_hp
    spark_chain = 0
    _render_battle("Wave %d begins!" % (current_wave + 1))

func _render_battle(message: String = "") -> void:
    _clear()
    _refresh()
    var e := _battle_enemy()
    _hero_panel(str(e["name"]), "%s • HP %d / %d" % [e["element"], enemy_hp, enemy_max_hp], _element_color(str(e["element"])).darkened(0.55))

    var enemy_bar := ProgressBar.new()
    enemy_bar.max_value = enemy_max_hp
    enemy_bar.value = enemy_hp
    enemy_bar.custom_minimum_size = Vector2(0, 34)
    enemy_bar.show_percentage = false
    body.add_child(enemy_bar)

    var log := Label.new()
    log.text = message
    log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log.custom_minimum_size = Vector2(0, 58)
    log.add_theme_font_size_override("font_size", 17)
    body.add_child(log)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    body.add_child(grid)
    for s in range(6):
        var idx := int(squad[s])
        var u: Dictionary = inventory[idx]
        var d: Dictionary = unit_defs[int(u["def_id"])]
        var dead := int(battle_hp[s]) <= 0
        var wrap := VBoxContainer.new()
        var atk := _button("%s %s Lv.%d\nHP %d/%d • ATK %d" % [_element_symbol(str(d["element"])), d["name"], u["level"], maxi(0,int(battle_hp[s])), _unit_hp(u), _unit_atk(u)], func(slot=s): _attack_unit(slot))
        atk.disabled = dead or (training_mode and training_single_slot >= 0 and s != training_single_slot)
        atk.custom_minimum_size = Vector2(0, 96)
        _tint_button(atk, _element_color(str(d["element"])).darkened(0.5))
        wrap.add_child(atk)
        var bb := _button("BB %d/10 • %s" % [u["bb"], d["bb_name"]], func(slot=s): _brave_burst(slot))
        bb.disabled = dead or int(u["bb"]) < 10 or (training_mode and training_single_slot >= 0 and s != training_single_slot)
        bb.custom_minimum_size = Vector2(0, 56)
        wrap.add_child(bb)
        grid.add_child(wrap)

    if training_mode:
        var tools := HBoxContainer.new()
        tools.add_theme_constant_override("separation", 8)
        body.add_child(tools)
        tools.add_child(_small_button("REFILL HP", _training_refill_hp))
        tools.add_child(_small_button("FILL BB", _training_fill_bb))
        tools.add_child(_small_button("RESET TARGET", _training_reset_target))
        _add_button("TRAINING MENU", _training_menu)
    else:
        _add_button("RETREAT", _home)

func _battle_enemy() -> Dictionary:
    if training_mode:
        return {"name":"Training Golem","element":training_element,"atk":0}
    var waves: Array = current_quest["waves"]
    return waves[current_wave]

func _attack_unit(slot: int) -> void:
    if enemy_hp <= 0 or int(battle_hp[slot]) <= 0:
        return
    var idx := int(squad[slot])
    var u: Dictionary = inventory[idx]
    var d: Dictionary = unit_defs[int(u["def_id"])]
    var e := _battle_enemy()
    var now := Time.get_ticks_msec()
    var sparked := last_attack_ms > 0 and now - last_attack_ms <= 650 and last_attacker != slot
    spark_chain = spark_chain + 1 if sparked else 0
    last_attack_ms = now
    last_attacker = slot
    var mult := _element_multiplier(str(d["element"]), str(e["element"]))
    var damage := int(_unit_atk(u) * randf_range(0.60,0.82) * mult)
    if sparked:
        damage = int(damage * (1.18 + minf(0.04 * spark_chain, 0.25)))
    enemy_hp = maxi(0, enemy_hp - damage)
    u["bb"] = mini(10, int(u["bb"]) + 2 + (1 if sparked else 0))
    var msg := "%s dealt %d" % [d["name"], damage]
    if sparked:
        msg += " • ✦ SPARK x%d" % (spark_chain + 1)
    if training_mode:
        _render_battle(msg + (" • TARGET DOWN" if enemy_hp <= 0 else ""))
    elif enemy_hp <= 0:
        _finish_wave(msg)
    else:
        _enemy_turn(msg)

func _brave_burst(slot: int) -> void:
    var idx := int(squad[slot])
    var u: Dictionary = inventory[idx]
    if int(u["bb"]) < 10:
        return
    var d: Dictionary = unit_defs[int(u["def_id"])]
    var e := _battle_enemy()
    var damage := int(_unit_atk(u) * randf_range(1.65,2.0) * _element_multiplier(str(d["element"]), str(e["element"])))
    u["bb"] = 0
    enemy_hp = maxi(0, enemy_hp - damage)
    var msg := "✦ %s • %s • %d damage" % [d["name"], d["bb_name"], damage]
    if training_mode:
        _render_battle(msg)
    elif enemy_hp <= 0:
        _finish_wave(msg)
    else:
        _enemy_turn(msg)

func _enemy_turn(msg: String) -> void:
    var alive: Array = []
    for i in range(6):
        if int(battle_hp[i]) > 0:
            alive.append(i)
    if alive.is_empty():
        _battle_defeat()
        return
    var e := _battle_enemy()
    var slot := int(alive[randi() % alive.size()])
    var damage := maxi(1, int(e["atk"]) + randi_range(-10,15))
    battle_hp[slot] = maxi(0, int(battle_hp[slot]) - damage)
    var any_alive := false
    for hp in battle_hp:
        if int(hp) > 0:
            any_alive = true
    if not any_alive:
        _battle_defeat()
        return
    _render_battle(msg + "\nEnemy retaliation: %d damage." % damage)

func _finish_wave(msg: String) -> void:
    var waves: Array = current_quest["waves"]
    if current_wave + 1 < waves.size():
        current_wave += 1
        _load_wave()
        return
    battle_active = false
    var qi := int(current_quest["index"])
    var first := not cleared_quests.has(qi)
    gold += int(current_quest["reward_gold"])
    rank_xp += int(current_quest["rank_xp"])
    if first:
        gems += int(current_quest["reward_gems"])
        cleared_quests.append(qi)
        unlocked_quest = maxi(unlocked_quest, mini(quests.size()-1, qi+1))
    var drop := str(current_quest["drop"])
    materials[drop] = int(materials.get(drop,0)) + randi_range(1,3)
    _apply_rank_xp()
    _save()
    _clear()
    _hero_panel("QUEST CLEAR", msg, Color("164634"))
    _add_button("QUESTS", _quest_select)
    _add_button("HOME", _home)

func _battle_defeat() -> void:
    _clear()
    _hero_panel("DEFEAT", "Your squad was overwhelmed", Color("4a2028"))
    _add_button("TRY AGAIN", func(): _start_quest(int(current_quest["index"])))
    _add_button("HOME", _home)

func _training_menu() -> void:
    training_mode = false
    _clear()
    _heading("TRAINING HALL", "No rewards, no costs, unlimited testing")
    _hero_panel("TRAINING GOLEM", "Choose target HP, element, and who attacks", Color("24364d"))

    _heading("TARGET HP", "")
    var hp_row := HBoxContainer.new()
    hp_row.add_theme_constant_override("separation", 8)
    body.add_child(hp_row)
    hp_row.add_child(_small_button("5K", func(): training_max_hp=5000; _training_menu()))
    hp_row.add_child(_small_button("25K", func(): training_max_hp=25000; _training_menu()))
    hp_row.add_child(_small_button("100K", func(): training_max_hp=100000; _training_menu()))

    _heading("TARGET ELEMENT • %s" % training_element, "")
    var el_grid := GridContainer.new()
    el_grid.columns = 3
    body.add_child(el_grid)
    for el in ["Fire","Water","Earth","Thunder","Light","Dark"]:
        el_grid.add_child(_small_button("%s %s" % [_element_symbol(el), el], func(element=el): training_element=element; _training_menu()))

    _heading("TEST MODE", "Selected target HP: %d" % training_max_hp)
    _add_button("FULL SQUAD", func(): _start_training(-1))
    for s in range(6):
        var idx := int(squad[s])
        var u: Dictionary = inventory[idx]
        var d: Dictionary = unit_defs[int(u["def_id"])]
        _add_button("SLOT %d • %s" % [s+1,d["name"]], func(slot=s): _start_training(slot))
    _add_button("BACK", _home)

func _start_training(single_slot: int) -> void:
    training_mode = true
    training_single_slot = single_slot
    training_max_hp = maxi(100, training_max_hp)
    enemy_max_hp = training_max_hp
    enemy_hp = enemy_max_hp
    _prepare_battle()
    _render_battle("Training ready • no rewards or penalties")

func _training_refill_hp() -> void:
    for s in range(6):
        battle_hp[s] = _unit_hp(inventory[int(squad[s])])
    _render_battle("Squad HP restored")

func _training_fill_bb() -> void:
    for s in range(6):
        inventory[int(squad[s])]["bb"] = 10
    _render_battle("All Brave Bursts charged")

func _training_reset_target() -> void:
    enemy_max_hp = training_max_hp
    enemy_hp = enemy_max_hp
    _render_battle("Training target restored")

func _summon() -> void:
    _clear()
    _hero_panel("SUMMON GATE", "5 Gems per summon • 30% featured 4★ rate", Color("3b275d"))
    var crystal := Label.new()
    crystal.text = "       ✦\n    ✦  ◇  ✦\n       ✦"
    crystal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    crystal.add_theme_font_size_override("font_size", 42)
    crystal.add_theme_color_override("font_color", Color("c898ff"))
    body.add_child(crystal)
    _add_button("SUMMON • 5 GEMS", _do_summon)
    _add_button("+50 TEST GEMS", func(): _give_gems(50); _summon())
    _add_button("BACK", _home)

func _do_summon() -> void:
    if gems < 5:
        _notice("Not enough Gems.", _summon)
        return
    gems -= 5
    var four: Array = []
    for i in range(unit_defs.size()):
        if int(unit_defs[i]["rarity"]) == 4:
            four.append(i)
    var chosen := randi() % unit_defs.size()
    if randf() < 0.30:
        chosen = int(four[randi() % four.size()])
    inventory.append(_new_unit(chosen))
    _save()
    var d: Dictionary = unit_defs[chosen]
    _clear()
    _hero_panel("SUMMON RESULT", "%s, %s" % [d["name"],d["title"]], _element_color(str(d["element"])).darkened(0.45))
    var result := Label.new()
    result.text = "%s\n%s • %d★\n\nAdded to inventory" % [_element_symbol(str(d["element"])),d["element"],d["rarity"]]
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.add_theme_font_size_override("font_size", 32)
    result.add_theme_color_override("font_color", GOLD)
    body.add_child(result)
    _add_button("SUMMON AGAIN", _summon)
    _add_button("UNITS", _units_menu)

func _squad_menu() -> void:
    _clear()
    _heading("SQUAD", "Six active slots • slot 1 is Leader")
    for s in range(6):
        var idx := int(squad[s])
        var u: Dictionary = inventory[idx]
        var d: Dictionary = unit_defs[int(u["def_id"])]
        var prefix := "★ LEADER • " if s == 0 else ""
        var b := _button("%s%s %s Lv.%d • %d★" % [prefix,_element_symbol(str(d["element"])),d["name"],u["level"],_unit_rarity(u)], func(slot=s): _choose_squad_unit(slot))
        _tint_button(b,_element_color(str(d["element"])).darkened(0.55))
        body.add_child(b)
    _add_button("BACK", _home)

func _choose_squad_unit(slot: int) -> void:
    _clear()
    _heading("CHOOSE UNIT", "Squad slot %d" % (slot+1))
    for i in range(inventory.size()):
        var u: Dictionary = inventory[i]
        var d: Dictionary = unit_defs[int(u["def_id"])]
        body.add_child(_button("%s %s • Lv.%d • %d★\nHP %d • ATK %d" % [_element_symbol(str(d["element"])),d["name"],u["level"],_unit_rarity(u),_unit_hp(u),_unit_atk(u)], func(index=i,target=slot): _assign_squad(target,index)))
    _add_button("BACK", _squad_menu)

func _assign_squad(slot: int, index: int) -> void:
    squad[slot] = index
    _save()
    _squad_menu()

func _units_menu() -> void:
    _clear()
    _heading("UNIT INVENTORY", "%d owned units" % inventory.size())
    for i in range(inventory.size()):
        var u: Dictionary = inventory[i]
        var d: Dictionary = unit_defs[int(u["def_id"])]
        var b := _button("%s  %s, %s\nLv.%d • %d★ • HP %d • ATK %d" % [_element_symbol(str(d["element"])),d["name"],d["title"],u["level"],_unit_rarity(u),_unit_hp(u),_unit_atk(u)], func(index=i): _unit_details(index))
        _tint_button(b,_element_color(str(d["element"])).darkened(0.60))
        body.add_child(b)
    _add_button("BACK", _home)

func _unit_details(index: int) -> void:
    selected = index
    var u: Dictionary = inventory[index]
    var d: Dictionary = unit_defs[int(u["def_id"])]
    _clear()
    _hero_panel("%s %s" % [_element_symbol(str(d["element"])),d["name"]], d["title"], _element_color(str(d["element"])).darkened(0.5))
    var info := Label.new()
    info.text = "%s • %d★ • Level %d\nHP %d   ATK %d   Hits %d\nBB: %s\nLeader: %s\nXP %d/%d" % [d["element"],_unit_rarity(u),u["level"],_unit_hp(u),_unit_atk(u),d["hits"],d["bb_name"],d["leader"],u["xp"],_xp_needed(int(u["level"]))]
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 20)
    info.add_theme_color_override("font_color", TEXT)
    body.add_child(info)
    _add_button("TRAIN • 300 GOLD", func(): _train_unit(index))
    _add_button("EVOLVE", func(): _evolve_unit(index))
    _add_button("BACK", _units_menu)

func _train_unit(index: int) -> void:
    if gold < 300:
        _notice("Not enough Gold", func(): _unit_details(index))
        return
    gold -= 300
    _add_unit_xp(index,120)
    _save()
    _unit_details(index)

func _evolve_unit(index: int) -> void:
    var u: Dictionary = inventory[index]
    var d: Dictionary = unit_defs[int(u["def_id"])]
    if int(u["evo"]) >= 2:
        _notice("Evolution cap reached",func():_unit_details(index))
        return
    var mat := _element_material(str(d["element"]))
    var need := 2 + int(u["evo"])
    var cost := 1000 + int(u["evo"])*750
    if int(materials.get(mat,0)) < need or gold < cost:
        _notice("Need %d %s materials and %d Gold" % [need,mat,cost],func():_unit_details(index))
        return
    materials[mat] -= need
    gold -= cost
    u["evo"] += 1
    u["level"] = 1
    u["xp"] = 0
    _save()
    _unit_details(index)

func _materials() -> void:
    _clear()
    _heading("MATERIALS", "Evolution inventory")
    for key in materials.keys():
        var l := Label.new()
        l.text = "%s    x%d" % [key,materials[key]]
        l.add_theme_font_size_override("font_size",22)
        body.add_child(l)
    _add_button("BACK",_home)

func _seed_inventory() -> void:
    if inventory.size() > 0:
        return
    for i in range(6):
        inventory.append(_new_unit(i))

func _new_unit(def_id: int) -> Dictionary:
    return {"def_id":def_id,"level":1,"xp":0,"evo":0,"bb":0,"locked":false}

func _repair_state() -> void:
    if inventory.size() < 6:
        inventory.clear()
        _seed_inventory()
    for i in range(inventory.size()):
        var u = inventory[i]
        if typeof(u) != TYPE_DICTIONARY:
            inventory[i] = _new_unit(i % unit_defs.size())
        else:
            u["def_id"] = clampi(int(u.get("def_id",i%unit_defs.size())),0,unit_defs.size()-1)
            u["level"] = maxi(1,int(u.get("level",1)))
            u["xp"] = maxi(0,int(u.get("xp",0)))
            u["evo"] = clampi(int(u.get("evo",0)),0,2)
            u["bb"] = clampi(int(u.get("bb",0)),0,10)
    if squad.size() != 6:
        squad = [0,1,2,3,4,5]
    for i in range(6):
        squad[i] = clampi(int(squad[i]),0,inventory.size()-1)
    unlocked_quest = clampi(unlocked_quest,0,quests.size()-1)

func _unit_hp(u: Dictionary) -> int:
    var d: Dictionary = unit_defs[int(u["def_id"])]
    return int(float(d["base_hp"]) * (1.0 + (int(u["level"])-1)*0.035 + int(u["evo"])*0.22))

func _unit_atk(u: Dictionary) -> int:
    var d: Dictionary = unit_defs[int(u["def_id"])]
    return int(float(d["base_atk"]) * (1.0 + (int(u["level"])-1)*0.032 + int(u["evo"])*0.20))

func _unit_rarity(u: Dictionary) -> int:
    return mini(6,int(unit_defs[int(u["def_id"])]["rarity"])+int(u["evo"]))

func _xp_needed(level: int) -> int:
    return 80 + level*20

func _add_unit_xp(index: int, amount: int) -> void:
    var u: Dictionary = inventory[index]
    u["xp"] += amount
    while int(u["level"]) < 40 and int(u["xp"]) >= _xp_needed(int(u["level"])):
        u["xp"] -= _xp_needed(int(u["level"]))
        u["level"] += 1

func _apply_rank_xp() -> void:
    var need := 100 + rank*25
    while rank_xp >= need:
        rank_xp -= need
        rank += 1
        need = 100 + rank*25

func _element_multiplier(attacker: String, defender: String) -> float:
    if defender == "Neutral": return 1.0
    if (attacker=="Fire" and defender=="Earth") or (attacker=="Earth" and defender=="Thunder") or (attacker=="Thunder" and defender=="Water") or (attacker=="Water" and defender=="Fire"): return 1.35
    if (defender=="Fire" and attacker=="Earth") or (defender=="Earth" and attacker=="Thunder") or (defender=="Thunder" and attacker=="Water") or (defender=="Water" and attacker=="Fire"): return 0.75
    if (attacker=="Light" and defender=="Dark") or (attacker=="Dark" and defender=="Light"): return 1.35
    return 1.0

func _element_color(element: String) -> Color:
    match element:
        "Fire": return Color("d95145")
        "Water": return Color("348dd1")
        "Earth": return Color("4c9b58")
        "Thunder": return Color("d5ad38")
        "Light": return Color("d8c97d")
        "Dark": return Color("8a5aac")
        _: return Color("52677e")

func _element_symbol(element: String) -> String:
    match element:
        "Fire": return "🔥"
        "Water": return "💧"
        "Earth": return "🌿"
        "Thunder": return "⚡"
        "Light": return "☀"
        "Dark": return "☾"
        _: return "◇"

func _element_material(element: String) -> String:
    match element:
        "Fire": return "Ember"
        "Water": return "Tide"
        "Earth": return "Verdant"
        "Thunder": return "Volt"
        "Light": return "Lumen"
        _: return "Dusk"

func _heading(a: String,b: String) -> void:
    var h := Label.new()
    h.text = a
    h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.add_theme_font_size_override("font_size",28)
    h.add_theme_color_override("font_color",GOLD)
    body.add_child(h)
    if b != "":
        var s := Label.new()
        s.text = b
        s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        s.add_theme_font_size_override("font_size",16)
        s.add_theme_color_override("font_color",MUTED)
        body.add_child(s)

func _button(label: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(0,76)
    b.add_theme_font_size_override("font_size",19)
    b.add_theme_color_override("font_color",TEXT)
    _tint_button(b,PANEL_2)
    b.pressed.connect(callback)
    return b

func _small_button(label: String, callback: Callable) -> Button:
    var b := _button(label,callback)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.custom_minimum_size = Vector2(0,62)
    b.add_theme_font_size_override("font_size",17)
    return b

func _tint_button(b: Button,color: Color) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 13
    style.corner_radius_top_right = 13
    style.corner_radius_bottom_left = 13
    style.corner_radius_bottom_right = 13
    b.add_theme_stylebox_override("normal",style)

func _add_button(label: String, callback: Callable) -> void:
    body.add_child(_button(label,callback))

func _notice(text: String,back: Callable) -> void:
    _clear()
    _hero_panel("NOTICE",text,Color("3d3045"))
    _add_button("BACK",back)

func _clear() -> void:
    if body == null: return
    for child in body.get_children(): child.queue_free()

func _refresh() -> void:
    if status != null:
        status.text = "Rank %d   Gold %d   Gems %d" % [rank,gold,gems]

func _save() -> void:
    var f := FileAccess.open("user://save.json",FileAccess.WRITE)
    if not f: return
    f.store_string(JSON.stringify({"save_version":SAVE_VERSION,"gems":gems,"gold":gold,"rank":rank,"rank_xp":rank_xp,"selected":selected,"unlocked_quest":unlocked_quest,"cleared_quests":cleared_quests,"materials":materials,"squad":squad,"inventory":inventory}))

func _load_save_safe() -> void:
    if not FileAccess.file_exists("user://save.json"): return
    var f := FileAccess.open("user://save.json",FileAccess.READ)
    if not f: return
    var data = JSON.parse_string(f.get_as_text())
    if typeof(data) != TYPE_DICTIONARY: return
    gems = maxi(0,int(data.get("gems",gems)))
    gold = maxi(0,int(data.get("gold",gold)))
    rank = maxi(1,int(data.get("rank",rank)))
    rank_xp = maxi(0,int(data.get("rank_xp",0)))
    selected = maxi(0,int(data.get("selected",0)))
    unlocked_quest = maxi(0,int(data.get("unlocked_quest",0)))
    if typeof(data.get("cleared_quests",[])) == TYPE_ARRAY: cleared_quests = data.get("cleared_quests",[])
    var mats = data.get("materials",{})
    if typeof(mats) == TYPE_DICTIONARY:
        for key in materials.keys(): materials[key] = maxi(0,int(mats.get(key,0)))
    var inv = data.get("inventory",null)
    if typeof(inv) == TYPE_ARRAY and inv.size() >= 6: inventory = inv
    var sq = data.get("squad",null)
    if typeof(sq) == TYPE_ARRAY and sq.size() == 6: squad = sq
