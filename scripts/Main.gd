extends Control

const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("9fb0ca")
const RED := Color("ff6b6b")
const GREEN := Color("6ee7a8")
const PANEL_2 := Color("223451")
const SAVE_VERSION := 3

var gems: int = 20
var gold: int = 1000
var rank: int = 1
var rank_xp: int = 0
var selected: int = 0
var unlocked_quest: int = 0
var cleared_quests: Array = []
var materials: Dictionary = {"Ember":0,"Tide":0,"Verdant":0,"Volt":0,"Lumen":0,"Dusk":0}
var squad: Array = [0,1,2,3,4,5]
var inventory: Array = []

var body: VBoxContainer
var status: Label
var current_quest: Dictionary = {}
var current_wave: int = 0
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var battle_active: bool = false
var battle_hp: Array = []
var last_attack_ms: int = 0
var last_attacker: int = -1
var spark_chain: int = 0

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
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 16
    root.offset_right = -16
    root.offset_top = 18
    root.offset_bottom = -18
    root.add_theme_constant_override("separation", 10)
    add_child(root)

    var title := Label.new()
    title.text = "FRONTIER OFFLINE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", GOLD)
    root.add_child(title)

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
    body.add_theme_constant_override("separation", 10)
    scroll.add_child(body)

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
            continue
        if not u.has("def_id"):
            u["def_id"] = i % unit_defs.size()
        u["def_id"] = clampi(int(u["def_id"]), 0, unit_defs.size() - 1)
        if not u.has("level"): u["level"] = 1
        if not u.has("xp"): u["xp"] = 0
        if not u.has("evo"): u["evo"] = 0
        if not u.has("bb"): u["bb"] = 0
        if not u.has("locked"): u["locked"] = false
    if squad.size() != 6:
        squad = [0,1,2,3,4,5]
    for i in range(squad.size()):
        squad[i] = clampi(int(squad[i]), 0, inventory.size() - 1)
    unlocked_quest = clampi(unlocked_quest, 0, quests.size() - 1)

func _home() -> void:
    battle_active = false
    _clear()
    _refresh()
    _heading("GRAND GAIA", "Milestone build • progression systems online")
    _add_button("QUESTS", _quest_select)
    _add_button("SQUAD", _squad_menu)
    _add_button("UNITS", _units_menu)
    _add_button("SUMMON GATE", _summon)
    _add_button("MATERIALS", _materials)
    _add_button("SAVE GAME", func(): _save(); _home())

func _quest_select() -> void:
    _clear()
    _heading("QUESTS", "Clear quests to unlock the next route")
    for i in range(quests.size()):
        var q: Dictionary = quests[i]
        if i > unlocked_quest:
            var locked := _button("LOCKED • %s" % q["name"], func(): pass)
            locked.disabled = true
            body.add_child(locked)
            continue
        var clear_mark := "CLEAR • " if cleared_quests.has(i) else ""
        var label := "%s%s\n%s • %d Gold • %d Gem%s" % [clear_mark, q["name"], q["area"], q["reward_gold"], q["reward_gems"], "s" if int(q["reward_gems"]) != 1 else ""]
        body.add_child(_button(label, func(index=i): _start_quest(index)))
    _add_button("BACK", _home)

func _start_quest(index: int) -> void:
    current_quest = quests[index].duplicate(true)
    current_quest["index"] = index
    current_wave = 0
    battle_active = true
    last_attack_ms = 0
    last_attacker = -1
    spark_chain = 0
    battle_hp.clear()
    for slot in squad:
        var inst: Dictionary = inventory[int(slot)]
        inst["bb"] = 0
        battle_hp.append(_unit_hp(inst))
    _load_wave()

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
    var waves: Array = current_quest["waves"]
    var e: Dictionary = waves[current_wave]
    _heading("%s • WAVE %d/%d" % [current_quest["name"], current_wave + 1, waves.size()], "%s • %s" % [e["name"], e["element"]])

    var bar := ProgressBar.new()
    bar.max_value = enemy_max_hp
    bar.value = enemy_hp
    bar.custom_minimum_size = Vector2(0, 34)
    bar.show_percentage = false
    body.add_child(bar)

    var hp_label := Label.new()
    hp_label.text = "Enemy HP %d / %d" % [enemy_hp, enemy_max_hp]
    hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_label.add_theme_font_size_override("font_size", 18)
    body.add_child(hp_label)

    var log := Label.new()
    log.text = message if message != "" else "Tap a unit to attack. Full BB gauges unlock Brave Burst."
    log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    log.custom_minimum_size = Vector2(0, 70)
    log.add_theme_font_size_override("font_size", 17)
    body.add_child(log)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    body.add_child(grid)

    for s in range(squad.size()):
        var inv_index := int(squad[s])
        var u: Dictionary = inventory[inv_index]
        var d: Dictionary = unit_defs[int(u["def_id"])]
        var wrap := VBoxContainer.new()
        wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var dead := int(battle_hp[s]) <= 0
        var atk_text := "%s%s Lv.%d\n%s • HP %d/%d\nATK %d" % ["LEADER • " if s == 0 else "", d["name"], u["level"], d["element"], maxi(0, int(battle_hp[s])), _unit_hp(u), _unit_atk(u)]
        var atk := _button(atk_text, func(slot=s): _attack_unit(slot))
        atk.disabled = dead
        atk.custom_minimum_size = Vector2(0, 112)
        wrap.add_child(atk)
        var bb := _button("BB %d/10 • %s" % [u["bb"], d["bb_name"]], func(slot=s): _brave_burst(slot))
        bb.disabled = dead or int(u["bb"]) < 10
        bb.custom_minimum_size = Vector2(0, 60)
        wrap.add_child(bb)
        grid.add_child(wrap)
    _add_button("RETREAT", _home)

func _attack_unit(slot: int) -> void:
    if not battle_active or enemy_hp <= 0 or int(battle_hp[slot]) <= 0:
        return
    var inv_index := int(squad[slot])
    var u: Dictionary = inventory[inv_index]
    var d: Dictionary = unit_defs[int(u["def_id"])]
    var waves: Array = current_quest["waves"]
    var e: Dictionary = waves[current_wave]
    var now := Time.get_ticks_msec()
    var sparked := last_attack_ms > 0 and now - last_attack_ms <= 650 and last_attacker != slot
    if sparked:
        spark_chain += 1
    else:
        spark_chain = 0
    last_attack_ms = now
    last_attacker = slot
    var damage := int(_unit_atk(u) * randf_range(0.58, 0.78) * _element_multiplier(str(d["element"]), str(e["element"])) * _leader_attack_multiplier(str(d["element"]), false))
    if sparked:
        damage = int(damage * (1.18 + minf(float(spark_chain) * 0.05, 0.30)) * _leader_spark_multiplier())
    enemy_hp = maxi(0, enemy_hp - damage)
    u["bb"] = mini(10, int(u["bb"]) + 2 + _leader_bb_bonus() + (1 if sparked else 0))
    var msg := "%s hits for %d" % [d["name"], damage]
    if sparked:
        msg += " • SPARK x%d!" % (spark_chain + 1)
    if enemy_hp <= 0:
        _finish_wave(msg)
    else:
        _enemy_turn(msg)

func _brave_burst(slot: int) -> void:
    if not battle_active or enemy_hp <= 0 or int(battle_hp[slot]) <= 0:
        return
    var inv_index := int(squad[slot])
    var u: Dictionary = inventory[inv_index]
    if int(u["bb"]) < 10:
        return
    var d: Dictionary = unit_defs[int(u["def_id"])]
    var waves: Array = current_quest["waves"]
    var e: Dictionary = waves[current_wave]
    var damage := int(_unit_atk(u) * randf_range(1.55, 1.90) * _element_multiplier(str(d["element"]), str(e["element"])) * _leader_attack_multiplier(str(d["element"]), true))
    u["bb"] = 0
    enemy_hp = maxi(0, enemy_hp - damage)
    spark_chain = 0
    var msg := "%s unleashes %s! %d damage!" % [d["name"], d["bb_name"], damage]
    if enemy_hp <= 0:
        _finish_wave(msg)
    else:
        _enemy_turn(msg)

func _enemy_turn(player_msg: String) -> void:
    var alive: Array = []
    for i in range(battle_hp.size()):
        if int(battle_hp[i]) > 0:
            alive.append(i)
    if alive.is_empty():
        _battle_defeat()
        return
    var waves: Array = current_quest["waves"]
    var e: Dictionary = waves[current_wave]
    var slot := int(alive[randi() % alive.size()])
    var inv_index := int(squad[slot])
    var u: Dictionary = inventory[inv_index]
    var d: Dictionary = unit_defs[int(u["def_id"])]
    var damage := maxi(1, int(e["atk"]) + randi_range(-10, 15))
    damage = int(float(damage) * _leader_defense_multiplier(str(d["element"])))
    battle_hp[slot] = maxi(0, int(battle_hp[slot]) - damage)
    if int(battle_hp[slot]) <= 0:
        player_msg += "\n%s is knocked out!" % d["name"]
    else:
        u["bb"] = mini(10, int(u["bb"]) + 1)
    var any_alive := false
    for value in battle_hp:
        if int(value) > 0:
            any_alive = true
            break
    if not any_alive:
        _battle_defeat()
        return
    _render_battle("%s\n%s retaliates against %s for %d." % [player_msg, e["name"], d["name"], damage])

func _finish_wave(player_msg: String) -> void:
    var waves: Array = current_quest["waves"]
    if current_wave + 1 < waves.size():
        current_wave += 1
        _load_wave()
        return
    battle_active = false
    var qi := int(current_quest["index"])
    var first_clear := not cleared_quests.has(qi)
    gold += int(current_quest["reward_gold"])
    if first_clear:
        gems += int(current_quest["reward_gems"])
    rank_xp += int(current_quest["rank_xp"])
    var drop := str(current_quest["drop"])
    materials[drop] = int(materials.get(drop, 0)) + randi_range(1, 3)
    if first_clear:
        cleared_quests.append(qi)
        unlocked_quest = maxi(unlocked_quest, mini(quests.size() - 1, qi + 1))
    _apply_rank_xp()
    for slot in squad:
        _add_unit_xp(int(slot), 20 + qi * 8)
    _save()
    _clear()
    _refresh()
    _heading("QUEST CLEAR", current_quest["name"])
    var result := Label.new()
    result.text = "%s\n\n+%d Gold\n%s\n+%d %s Material" % [player_msg, current_quest["reward_gold"], ("+%d Gems" % current_quest["reward_gems"]) if first_clear else "Repeat clear • no Gem reward", materials[drop], drop]
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.add_theme_font_size_override("font_size", 22)
    result.add_theme_color_override("font_color", GREEN)
    body.add_child(result)
    _add_button("QUESTS", _quest_select)
    _add_button("HOME", _home)

func _battle_defeat() -> void:
    battle_active = false
    _clear()
    _heading("DEFEAT", "Your squad was overwhelmed.")
    _add_button("TRY AGAIN", func(): _start_quest(int(current_quest["index"])))
    _add_button("HOME", _home)

func _squad_menu() -> void:
    _clear()
    _heading("SQUAD", "Tap a slot, then choose an owned unit")
    for i in range(squad.size()):
        var inv_index := int(squad[i])
        var u: Dictionary = inventory[inv_index]
        var d: Dictionary = unit_defs[int(u["def_id"])]
        var prefix := "LEADER • " if i == 0 else ""
        body.add_child(_button("%sSlot %d • %s Lv.%d • %d★" % [prefix, i + 1, d["name"], u["level"], _unit_rarity(u)], func(slot=i): _choose_squad_unit(slot)))
    var ld := _leader_def()
    var ls := Label.new()
    ls.text = "Leader Skill\n%s" % ld["leader"]
    ls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ls.add_theme_font_size_override("font_size", 19)
    ls.add_theme_color_override("font_color", GOLD)
    body.add_child(ls)
    _add_button("BACK", _home)

func _choose_squad_unit(slot: int) -> void:
    _clear()
    _heading("CHOOSE UNIT", "Assign a unit to squad slot %d" % (slot + 1))
    for i in range(inventory.size()):
        var u: Dictionary = inventory[i]
        var d: Dictionary = unit_defs[int(u["def_id"])]
        body.add_child(_button("%s, %s • Lv.%d • %d★\nHP %d • ATK %d" % [d["name"], d["title"], u["level"], _unit_rarity(u), _unit_hp(u), _unit_atk(u)], func(index=i, target_slot=slot): _assign_squad(target_slot, index)))
    _add_button("BACK", _squad_menu)

func _assign_squad(slot: int, inv_index: int) -> void:
    squad[slot] = inv_index
    _save()
    _squad_menu()

func _units_menu() -> void:
    _clear()
    _heading("UNITS", "%d owned units • tap one for details" % inventory.size())
    for i in range(inventory.size()):
        var u: Dictionary = inventory[i]
        var d: Dictionary = unit_defs[int(u["def_id"])]
        var tag := " • SQUAD" if squad.has(i) else ""
        body.add_child(_button("%s, %s%s\n%s • Lv.%d • %d★ • XP %d/%d" % [d["name"], d["title"], tag, d["element"], u["level"], _unit_rarity(u), u["xp"], _xp_needed(int(u["level"]))], func(index=i): _unit_details(index)))
    _add_button("BACK", _home)

func _unit_details(index: int) -> void:
    selected = index
    var u: Dictionary = inventory[index]
    var d: Dictionary = unit_defs[int(u["def_id"])]
    _clear()
    _heading("%s, %s" % [d["name"], d["title"]], "%s • %d★ • Level %d" % [d["element"], _unit_rarity(u), u["level"]])
    var info := Label.new()
    info.text = "HP %d\nATK %d\nHits %d\nBB: %s\n\nLeader Skill: %s\n\nXP %d / %d" % [_unit_hp(u), _unit_atk(u), d["hits"], d["bb_name"], d["leader"], u["xp"], _xp_needed(int(u["level"]))]
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 20)
    info.add_theme_color_override("font_color", TEXT)
    body.add_child(info)
    _add_button("TRAIN • 300 GOLD", func(): _train_unit(index))
    _add_button("EVOLVE", func(): _evolve_unit(index))
    _add_button("BACK", _units_menu)

func _train_unit(index: int) -> void:
    if gold < 300:
        _notice("Not enough Gold.", func(): _unit_details(index))
        return
    gold -= 300
    _add_unit_xp(index, 120)
    _save()
    _unit_details(index)

func _evolve_unit(index: int) -> void:
    var u: Dictionary = inventory[index]
    var d: Dictionary = unit_defs[int(u["def_id"])]
    if int(u["evo"]) >= 2:
        _notice("This unit has reached the prototype evolution cap.", func(): _unit_details(index))
        return
    var mat := _element_material(str(d["element"]))
    var need := 2 + int(u["evo"])
    var cost := 1000 + int(u["evo"]) * 750
    if int(materials.get(mat, 0)) < need or gold < cost:
        _notice("Evolution requires %d %s Materials and %d Gold." % [need, mat, cost], func(): _unit_details(index))
        return
    materials[mat] = int(materials.get(mat, 0)) - need
    gold -= cost
    u["evo"] = int(u["evo"]) + 1
    u["level"] = 1
    u["xp"] = 0
    _save()
    _unit_details(index)

func _summon() -> void:
    _clear()
    _heading("SUMMON GATE", "5 Gems • duplicates become separate trainable units")
    _add_button("SUMMON • 5 GEMS", _do_summon)
    _add_button("BACK", _home)

func _do_summon() -> void:
    if gems < 5:
        _notice("Not enough Gems.", _summon)
        return
    gems -= 5
    var pool: Array = []
    var four: Array = []
    for i in range(unit_defs.size()):
        pool.append(i)
        if int(unit_defs[i]["rarity"]) == 4:
            four.append(i)
    var chosen: int
    if randf() < 0.30 and not four.is_empty():
        chosen = int(four[randi() % four.size()])
    else:
        chosen = int(pool[randi() % pool.size()])
    inventory.append(_new_unit(chosen))
    _save()
    var d: Dictionary = unit_defs[chosen]
    _clear()
    _heading("SUMMON RESULT", "A new unit answers the Gate!")
    var l := Label.new()
    l.text = "%s, %s\n%s • %d★\n\nAdded to Unit Inventory." % [d["name"], d["title"], d["element"], d["rarity"]]
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", 27)
    l.add_theme_color_override("font_color", GOLD)
    body.add_child(l)
    _add_button("SUMMON AGAIN", _summon)
    _add_button("UNITS", _units_menu)

func _materials() -> void:
    _clear()
    _heading("MATERIALS", "Quest drops used for evolution")
    for key in materials.keys():
        var l := Label.new()
        l.text = "%s Material     x%d" % [key, materials[key]]
        l.add_theme_font_size_override("font_size", 22)
        l.add_theme_color_override("font_color", TEXT)
        body.add_child(l)
    _add_button("BACK", _home)

func _unit_hp(u: Dictionary) -> int:
    var d: Dictionary = unit_defs[int(u["def_id"])]
    return int(float(d["base_hp"]) * (1.0 + (int(u["level"]) - 1) * 0.035 + int(u["evo"]) * 0.22))

func _unit_atk(u: Dictionary) -> int:
    var d: Dictionary = unit_defs[int(u["def_id"])]
    return int(float(d["base_atk"]) * (1.0 + (int(u["level"]) - 1) * 0.032 + int(u["evo"]) * 0.20))

func _unit_rarity(u: Dictionary) -> int:
    return mini(6, int(unit_defs[int(u["def_id"])]["rarity"]) + int(u["evo"]))

func _xp_needed(level: int) -> int:
    return 80 + level * 20

func _add_unit_xp(index: int, amount: int) -> void:
    var u: Dictionary = inventory[index]
    u["xp"] = int(u["xp"]) + amount
    while int(u["level"]) < 40 and int(u["xp"]) >= _xp_needed(int(u["level"])):
        u["xp"] = int(u["xp"]) - _xp_needed(int(u["level"]))
        u["level"] = int(u["level"]) + 1

func _apply_rank_xp() -> void:
    var need := 100 + rank * 25
    while rank_xp >= need:
        rank_xp -= need
        rank += 1
        need = 100 + rank * 25

func _element_material(element: String) -> String:
    match element:
        "Fire": return "Ember"
        "Water": return "Tide"
        "Earth": return "Verdant"
        "Thunder": return "Volt"
        "Light": return "Lumen"
        _: return "Dusk"

func _leader_def() -> Dictionary:
    if squad.is_empty() or inventory.is_empty():
        return unit_defs[0]
    var index := clampi(int(squad[0]), 0, inventory.size() - 1)
    var u: Dictionary = inventory[index]
    return unit_defs[int(u["def_id"])]

func _leader_attack_multiplier(element: String, is_bb: bool) -> float:
    var d := _leader_def()
    var m := 1.0
    var text := str(d["leader"])
    if text.contains("15% ATK") and element == "Fire": m *= 1.15
    if text.contains("20% ATK") and element == "Water": m *= 1.20
    if text.contains("10% HP and ATK") and element == "Fire": m *= 1.10
    if is_bb and text.contains("18%."): m *= 1.18
    if is_bb and text.contains("25%."): m *= 1.25
    return m

func _leader_spark_multiplier() -> float:
    var text := str(_leader_def()["leader"])
    if text.contains("30%."):
        return 1.30
    if text.contains("20%."):
        return 1.20
    return 1.0

func _leader_bb_bonus() -> int:
    return 1 if str(_leader_def()["leader"]).contains("1 point faster") else 0

func _leader_defense_multiplier(element: String) -> float:
    var text := str(_leader_def()["leader"])
    if text.contains("Light/Dark") and (element == "Light" or element == "Dark"):
        return 0.88
    return 1.0

func _element_multiplier(attacker: String, defender: String) -> float:
    if (attacker == "Fire" and defender == "Earth") or (attacker == "Earth" and defender == "Thunder") or (attacker == "Thunder" and defender == "Water") or (attacker == "Water" and defender == "Fire"):
        return 1.35
    if (defender == "Fire" and attacker == "Earth") or (defender == "Earth" and attacker == "Thunder") or (defender == "Thunder" and attacker == "Water") or (defender == "Water" and attacker == "Fire"):
        return 0.75
    if (attacker == "Light" and defender == "Dark") or (attacker == "Dark" and defender == "Light"):
        return 1.35
    return 1.0

func _heading(a: String, b: String) -> void:
    var h := Label.new()
    h.text = a
    h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.add_theme_font_size_override("font_size", 29)
    h.add_theme_color_override("font_color", GOLD)
    body.add_child(h)
    var s := Label.new()
    s.text = b
    s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    s.add_theme_font_size_override("font_size", 17)
    s.add_theme_color_override("font_color", MUTED)
    body.add_child(s)

func _add_button(label: String, callback: Callable) -> void:
    body.add_child(_button(label, callback))

func _button(label: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(0, 82)
    b.add_theme_font_size_override("font_size", 20)
    b.add_theme_color_override("font_color", TEXT)
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL_2
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_left = 14
    style.corner_radius_bottom_right = 14
    b.add_theme_stylebox_override("normal", style)
    b.pressed.connect(callback)
    return b

func _notice(text: String, back: Callable) -> void:
    _clear()
    _heading("NOTICE", text)
    _add_button("BACK", back)

func _clear() -> void:
    if body == null:
        return
    for child in body.get_children():
        child.queue_free()

func _refresh() -> void:
    if status != null:
        status.text = "Rank %d • XP %d/%d     Gold %d     Gems %d" % [rank, rank_xp, 100 + rank * 25, gold, gems]

func _save() -> void:
    var f := FileAccess.open("user://save.json", FileAccess.WRITE)
    if not f:
        return
    var data := {
        "save_version": SAVE_VERSION,
        "gems": gems,
        "gold": gold,
        "rank": rank,
        "rank_xp": rank_xp,
        "selected": selected,
        "unlocked_quest": unlocked_quest,
        "cleared_quests": cleared_quests,
        "materials": materials,
        "squad": squad,
        "inventory": inventory
    }
    f.store_string(JSON.stringify(data))

func _load_save_safe() -> void:
    if not FileAccess.file_exists("user://save.json"):
        return
    var f := FileAccess.open("user://save.json", FileAccess.READ)
    if not f:
        return
    var data = JSON.parse_string(f.get_as_text())
    if typeof(data) != TYPE_DICTIONARY:
        return
    gems = int(data.get("gems", gems))
    gold = int(data.get("gold", gold))
    rank = maxi(1, int(data.get("rank", rank)))
    rank_xp = maxi(0, int(data.get("rank_xp", 0)))
    selected = maxi(0, int(data.get("selected", 0)))
    unlocked_quest = maxi(0, int(data.get("unlocked_quest", 0)))

    var cq = data.get("cleared_quests", [])
    if typeof(cq) == TYPE_ARRAY:
        cleared_quests = cq

    var mats = data.get("materials", {})
    if typeof(mats) == TYPE_DICTIONARY:
        for key in materials.keys():
            materials[key] = maxi(0, int(mats.get(key, materials[key])))

    var inv = data.get("inventory", null)
    if typeof(inv) == TYPE_ARRAY and inv.size() >= 6:
        inventory = inv

    var sq = data.get("squad", null)
    if typeof(sq) == TYPE_ARRAY and sq.size() == 6:
        squad = sq
