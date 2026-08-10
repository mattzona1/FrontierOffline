extends Control

const SAVE_VERSION := 5
const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("9fb0ca")
const BG := Color("08101c")
const PANEL2 := Color("213a5a")
const GREEN := Color("6fe0a4")

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

var unit_defs := [
    {"name":"Vargas","title":"Fencer Vargas","element":"Fire","rarity":3,"base_hp":920,"base_atk":410,"hits":5,"bb_name":"Blazing Arc","leader":"Fire units gain 15% ATK.","cache":"vargas_official.png"},
    {"name":"Selena","title":"Ice Selena","element":"Water","rarity":3,"base_hp":870,"base_atk":350,"hits":4,"bb_name":"Cresting Surge","leader":"Squad gains 10% max HP.","cache":"selena_official.png"},
    {"name":"Lance","title":"Lancer Lance","element":"Earth","rarity":3,"base_hp":1080,"base_atk":330,"hits":3,"bb_name":"Stonewake","leader":"Earth units gain 20% HP.","cache":"lance_official.png"},
    {"name":"Eze","title":"Warrior Eze","element":"Thunder","rarity":3,"base_hp":820,"base_atk":445,"hits":6,"bb_name":"Volt Rush","leader":"Spark damage increases by 20%.","cache":"eze_official.png"},
    {"name":"Atro","title":"Light Atro","element":"Light","rarity":3,"base_hp":890,"base_atk":390,"hits":5,"bb_name":"Radiant Choir","leader":"Light/Dark damage taken reduced by 12%.","cache":"atro_official.png"},
    {"name":"Magress","title":"Iron Magress","element":"Dark","rarity":3,"base_hp":900,"base_atk":430,"hits":5,"bb_name":"Nightfall Edge","leader":"BB damage increases by 18%.","cache":"magress_official.png"},
    {"name":"Toren","title":"Ashblade","element":"Fire","rarity":3,"base_hp":960,"base_atk":425,"hits":4,"bb_name":"Pyre Break","leader":"Fire units gain HP and ATK."},
    {"name":"Neris","title":"Deepcurrent","element":"Water","rarity":4,"base_hp":1010,"base_atk":455,"hits":7,"bb_name":"Abyssal Tide","leader":"Water units gain ATK."},
    {"name":"Oryn","title":"Rootbound","element":"Earth","rarity":4,"base_hp":1220,"base_atk":405,"hits":4,"bb_name":"Worldroot Crash","leader":"Squad gains max HP."},
    {"name":"Lyra","title":"Stormstep","element":"Thunder","rarity":4,"base_hp":930,"base_atk":500,"hits":8,"bb_name":"Skybreaker","leader":"Spark damage increases."},
    {"name":"Aurel","title":"Dawn Warden","element":"Light","rarity":4,"base_hp":1050,"base_atk":470,"hits":6,"bb_name":"Solar Verdict","leader":"BB gauge fills faster."},
    {"name":"Nyx","title":"Umbral Witch","element":"Dark","rarity":4,"base_hp":940,"base_atk":515,"hits":7,"bb_name":"Black Halo","leader":"BB damage increases."}
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
    var bg := ColorRect.new()
    bg.color = BG
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 10
    root.offset_right = -10
    root.offset_top = 10
    root.offset_bottom = -10
    root.add_theme_constant_override("separation", 6)
    add_child(root)
    var top := HBoxContainer.new()
    top.custom_minimum_size = Vector2(0, 60)
    root.add_child(top)
    var brand := Label.new()
    brand.text = "BRAVE FRONTIER • OFFLINE"
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brand.add_theme_font_size_override("font_size", 24)
    brand.add_theme_color_override("font_color", GOLD)
    top.add_child(brand)
    header_status = Label.new()
    header_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    header_status.add_theme_font_size_override("font_size", 16)
    top.add_child(header_status)
    page_title = Label.new()
    page_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    page_title.add_theme_font_size_override("font_size", 24)
    page_title.add_theme_color_override("font_color", TEXT)
    root.add_child(page_title)
    var frame := PanelContainer.new()
    frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var fs := StyleBoxFlat.new()
    fs.bg_color = Color("0d1828")
    fs.corner_radius_top_left = 18
    fs.corner_radius_top_right = 18
    fs.corner_radius_bottom_left = 18
    fs.corner_radius_bottom_right = 18
    frame.add_theme_stylebox_override("panel", fs)
    root.add_child(frame)
    stage = Control.new()
    stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stage.clip_contents = true
    frame.add_child(stage)
    toast = Label.new()
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.add_theme_font_size_override("font_size", 15)
    toast.add_theme_color_override("font_color", GREEN)
    toast.custom_minimum_size = Vector2(0, 26)
    root.add_child(toast)
    footer = HBoxContainer.new()
    footer.custom_minimum_size = Vector2(0, 82)
    footer.add_theme_constant_override("separation", 5)
    root.add_child(footer)
    _refresh_header()

func _clear_stage() -> void:
    for child in stage.get_children():
        child.queue_free()
    for child in footer.get_children():
        child.queue_free()
    toast.text = ""

func _refresh_header() -> void:
    if header_status != null:
        header_status.text = "R%d   %dG   💎%d" % [rank, gold, gems]

func _nav() -> void:
    footer.add_child(_nav_btn("HOME", _home))
    footer.add_child(_nav_btn("QUEST", _quests))
    footer.add_child(_nav_btn("UNITS", _units))
    footer.add_child(_nav_btn("SUMMON", _summon))
    footer.add_child(_nav_btn("MORE", _more))

func _nav_btn(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 15)
    button.pressed.connect(callback)
    return button

func _menu_btn(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(325, 180)
    button.add_theme_font_size_override("font_size", 20)
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL2
    style.corner_radius_top_left = 16
    style.corner_radius_top_right = 16
    style.corner_radius_bottom_left = 16
    style.corner_radius_bottom_right = 16
    button.add_theme_stylebox_override("normal", style)
    button.pressed.connect(callback)
    return button

func _home() -> void:
    training_mode = false
    _clear_stage()
    page_title.text = "GRAND GAIA"
    _refresh_header()
    var hero := PanelContainer.new()
    hero.position = Vector2(18, 18)
    hero.size = Vector2(664, 350)
    var hs := StyleBoxFlat.new()
    hs.bg_color = Color("143758")
    hs.corner_radius_top_left = 20
    hs.corner_radius_top_right = 20
    hs.corner_radius_bottom_left = 20
    hs.corner_radius_bottom_right = 20
    hero.add_theme_stylebox_override("panel", hs)
    stage.add_child(hero)
    var artrow := HBoxContainer.new()
    artrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    artrow.offset_left = 8
    artrow.offset_right = -8
    artrow.offset_top = 10
    artrow.offset_bottom = -45
    artrow.add_theme_constant_override("separation", 3)
    hero.add_child(artrow)
    for slot in range(6):
        var unit_index := int(squad[slot])
        artrow.add_child(_unit_portrait(int(inventory[unit_index]["def_id"]), Vector2(104, 260), false))
    var caption := Label.new()
    caption.text = "Your squad awaits. Choose your next move."
    caption.position = Vector2(20, 305)
    caption.size = Vector2(620, 38)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 17)
    hero.add_child(caption)
    var grid := GridContainer.new()
    grid.columns = 2
    grid.position = Vector2(18, 390)
    grid.size = Vector2(664, 390)
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    stage.add_child(grid)
    grid.add_child(_menu_btn("⚔ QUESTS\nContinue the journey", _quests))
    grid.add_child(_menu_btn("✦ SUMMON\nOpen the gate", _summon))
    grid.add_child(_menu_btn("👥 SQUAD\nArrange your heroes", _squad))
    grid.add_child(_menu_btn("🎯 TRAINING\nTest damage & BB", _training))
    _nav()

func _quests() -> void:
    _clear_stage()
    page_title.text = "QUESTS"
    _refresh_header()
    var grid := GridContainer.new()
    grid.columns = 2
    grid.position = Vector2(18, 20)
    grid.size = Vector2(664, 760)
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    stage.add_child(grid)
    for index in range(6):
        var q: Dictionary = quests[index]
        var locked := index > unlocked_quest
        var mark := "✓ " if cleared_quests.has(index) else ""
        var button := Button.new()
        button.text = ("🔒 " if locked else mark) + "%d-%d  %s\n%s\n%d Gold" % [int(index / 3) + 1, (index % 3) + 1, q["name"], q["area"], q["gold"]]
        button.custom_minimum_size = Vector2(325, 235)
        button.add_theme_font_size_override("font_size", 17)
        button.disabled = locked
        if not locked:
            button.pressed.connect(func(idx=index): _start_quest(idx))
        grid.add_child(button)
    _nav()

func _start_quest(index: int) -> void:
    current_quest = index
    current_wave = 0
    training_mode = false
    _prepare_battle()
    _load_wave()

func _prepare_battle() -> void:
    battle_hp.clear()
    last_attack_ms = 0
    last_attacker = -1
    spark_chain = 0
    for unit_index in squad:
        var unit: Dictionary = inventory[int(unit_index)]
        unit["bb"] = 0
        battle_hp.append(_unit_hp(unit))

func _load_wave() -> void:
    var enemy: Dictionary = quests[current_quest]["waves"][current_wave]
    enemy_max_hp = int(enemy["hp"])
    enemy_hp = enemy_max_hp
    _battle("Wave %d" % (current_wave + 1))

func _enemy() -> Dictionary:
    if training_mode:
        return {"name":"Training Golem","element":training_element,"atk":0}
    return quests[current_quest]["waves"][current_wave]

func _battle(message: String = "") -> void:
    _clear_stage()
    page_title.text = "TRAINING" if training_mode else "BATTLE"
    _refresh_header()
    var enemy_data := _enemy()
    var enemy_panel := PanelContainer.new()
    enemy_panel.position = Vector2(25, 12)
    enemy_panel.size = Vector2(650, 190)
    var es := StyleBoxFlat.new()
    es.bg_color = _element_color(str(enemy_data["element"])).darkened(0.55)
    es.corner_radius_top_left = 18
    es.corner_radius_top_right = 18
    es.corner_radius_bottom_left = 18
    es.corner_radius_bottom_right = 18
    enemy_panel.add_theme_stylebox_override("panel", es)
    stage.add_child(enemy_panel)
    var enemy_text := Label.new()
    enemy_text.text = "%s\n%s   HP %d / %d" % [enemy_data["name"], enemy_data["element"], enemy_hp, enemy_max_hp]
    enemy_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    enemy_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    enemy_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    enemy_text.add_theme_font_size_override("font_size", 24)
    enemy_panel.add_child(enemy_text)
    var log := Label.new()
    log.text = message
    log.position = Vector2(20, 208)
    log.size = Vector2(660, 45)
    log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    log.add_theme_font_size_override("font_size", 15)
    stage.add_child(log)
    var grid := GridContainer.new()
    grid.columns = 3
    grid.position = Vector2(18, 260)
    grid.size = Vector2(664, 525)
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    stage.add_child(grid)
    for slot in range(6):
        grid.add_child(_battle_card(slot))
    if training_mode:
        footer.add_child(_nav_btn("REFILL", _training_refill))
        footer.add_child(_nav_btn("FILL BB", _training_fill))
        footer.add_child(_nav_btn("RESET", _training_reset))
        footer.add_child(_nav_btn("TRAINING", _training))
        footer.add_child(_nav_btn("HOME", _home))
    else:
        footer.add_child(_nav_btn("RETREAT", _home))
        footer.add_child(_nav_btn("QUESTS", _quests))
        footer.add_child(_nav_btn("HOME", _home))

func _battle_card(slot: int) -> Control:
    var unit: Dictionary = inventory[int(squad[slot])]
    var definition: Dictionary = unit_defs[int(unit["def_id"])]
    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(216, 250)
    box.add_child(_unit_portrait(int(unit["def_id"]), Vector2(216, 125), false))
    var attack := Button.new()
    attack.text = "%s\nHP %d/%d" % [definition["name"], maxi(0, int(battle_hp[slot])), _unit_hp(unit)]
    attack.custom_minimum_size = Vector2(0, 67)
    attack.disabled = int(battle_hp[slot]) <= 0 or (training_mode and training_single_slot >= 0 and slot != training_single_slot)
    attack.pressed.connect(func(s=slot): _attack(s))
    box.add_child(attack)
    var bb := Button.new()
    bb.text = "BB %d/10" % int(unit["bb"])
    bb.custom_minimum_size = Vector2(0, 48)
    bb.disabled = int(unit["bb"]) < 10 or attack.disabled
    bb.pressed.connect(func(s=slot): _bb(s))
    box.add_child(bb)
    return box

func _attack(slot: int) -> void:
    var unit: Dictionary = inventory[int(squad[slot])]
    var definition: Dictionary = unit_defs[int(unit["def_id"])]
    var enemy_data := _enemy()
    var now := Time.get_ticks_msec()
    var sparked := last_attack_ms > 0 and now - last_attack_ms <= 650 and last_attacker != slot
    spark_chain = spark_chain + 1 if sparked else 0
    last_attack_ms = now
    last_attacker = slot
    var damage := int(_unit_atk(unit) * randf_range(0.60, 0.82) * _element_multiplier(str(definition["element"]), str(enemy_data["element"])))
    if sparked:
        damage = int(damage * (1.18 + minf(0.04 * spark_chain, 0.25)))
    enemy_hp = maxi(0, enemy_hp - damage)
    unit["bb"] = mini(10, int(unit["bb"]) + 2 + (1 if sparked else 0))
    var message := "%s • %d damage" % [definition["name"], damage]
    if sparked:
        message += " • SPARK x%d" % (spark_chain + 1)
    if training_mode:
        _battle(message)
    elif enemy_hp <= 0:
        _finish_wave()
    else:
        _enemy_turn(message)

func _bb(slot: int) -> void:
    var unit: Dictionary = inventory[int(squad[slot])]
    if int(unit["bb"]) < 10:
        return
    var definition: Dictionary = unit_defs[int(unit["def_id"])]
    var enemy_data := _enemy()
    var damage := int(_unit_atk(unit) * randf_range(1.65, 2.0) * _element_multiplier(str(definition["element"]), str(enemy_data["element"])))
    unit["bb"] = 0
    enemy_hp = maxi(0, enemy_hp - damage)
    var message := "✦ %s • %d" % [definition["bb_name"], damage]
    if training_mode:
        _battle(message)
    elif enemy_hp <= 0:
        _finish_wave()
    else:
        _enemy_turn(message)

func _enemy_turn(message: String) -> void:
    var alive: Array = []
    for slot in range(6):
        if int(battle_hp[slot]) > 0:
            alive.append(slot)
    if alive.is_empty():
        _defeat()
        return
    var target := int(alive[randi() % alive.size()])
    var damage := maxi(1, int(_enemy()["atk"]) + randi_range(-10, 15))
    battle_hp[target] = maxi(0, int(battle_hp[target]) - damage)
    var any_alive := false
    for hp in battle_hp:
        if int(hp) > 0:
            any_alive = true
    if not any_alive:
        _defeat()
        return
    _battle(message + " • enemy hits %d" % damage)

func _finish_wave() -> void:
    var waves: Array = quests[current_quest]["waves"]
    if current_wave + 1 < waves.size():
        current_wave += 1
        _load_wave()
        return
    var q: Dictionary = quests[current_quest]
    var first := not cleared_quests.has(current_quest)
    gold += int(q["gold"])
    rank_xp += int(q["xp"])
    materials[q["drop"]] = int(materials.get(q["drop"], 0)) + randi_range(1, 3)
    if first:
        gems += int(q["gems"])
        cleared_quests.append(current_quest)
        unlocked_quest = maxi(unlocked_quest, mini(quests.size() - 1, current_quest + 1))
    _rank_up()
    _save()
    _clear_stage()
    page_title.text = "QUEST CLEAR"
    _refresh_header()
    var result := Label.new()
    result.text = "VICTORY\n+%d Gold%s" % [q["gold"], "  +%d Gems" % q["gems"] if first else ""]
    result.position = Vector2(60, 250)
    result.size = Vector2(600, 250)
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    result.add_theme_font_size_override("font_size", 32)
    result.add_theme_color_override("font_color", GOLD)
    stage.add_child(result)
    footer.add_child(_nav_btn("QUESTS", _quests))
    footer.add_child(_nav_btn("HOME", _home))

func _defeat() -> void:
    _clear_stage()
    page_title.text = "DEFEAT"
    var label := Label.new()
    label.text = "Your squad was overwhelmed."
    label.position = Vector2(60, 300)
    label.size = Vector2(600, 120)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 26)
    stage.add_child(label)
    footer.add_child(_nav_btn("RETRY", func(): _start_quest(current_quest)))
    footer.add_child(_nav_btn("HOME", _home))

func _units() -> void:
    _clear_stage()
    page_title.text = "UNITS"
    _refresh_header()
    var start := units_page * 6
    var grid := GridContainer.new()
    grid.columns = 3
    grid.position = Vector2(18, 20)
    grid.size = Vector2(664, 700)
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    stage.add_child(grid)
    for index in range(start, mini(start + 6, inventory.size())):
        var unit: Dictionary = inventory[index]
        var box := VBoxContainer.new()
        box.custom_minimum_size = Vector2(216, 330)
        box.add_child(_unit_portrait(int(unit["def_id"]), Vector2(216, 225), true))
        var button := Button.new()
        button.text = "Lv.%d • %d★\nHP %d • ATK %d" % [unit["level"], _rarity(unit), _unit_hp(unit), _unit_atk(unit)]
        button.custom_minimum_size = Vector2(0, 88)
        button.pressed.connect(func(idx=index): _unit_details(idx))
        box.add_child(button)
        grid.add_child(box)
    footer.add_child(_nav_btn("◀", func(): units_page = maxi(0, units_page - 1); _units()))
    footer.add_child(_nav_btn("HOME", _home))
    footer.add_child(_nav_btn("▶", func(): units_page = mini(maxi(0, int((inventory.size() - 1) / 6)), units_page + 1); _units()))

func _unit_details(index: int) -> void:
    selected = index
    _clear_stage()
    var unit: Dictionary = inventory[index]
    var definition: Dictionary = unit_defs[int(unit["def_id"])]
    page_title.text = definition["name"]
    _refresh_header()
    var art := _unit_portrait(int(unit["def_id"]), Vector2(360, 500), true)
    art.position = Vector2(180, 30)
    stage.add_child(art)
    var info := Label.new()
    info.text = "%s • %d★ • Lv.%d\nHP %d   ATK %d   Hits %d\nBB: %s\nLeader: %s" % [definition["element"], _rarity(unit), unit["level"], _unit_hp(unit), _unit_atk(unit), definition["hits"], definition["bb_name"], definition["leader"]]
    info.position = Vector2(40, 555)
    info.size = Vector2(640, 150)
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 18)
    stage.add_child(info)
    var train := Button.new()
    train.text = "TRAIN • 300 GOLD"
    train.position = Vector2(80, 720)
    train.size = Vector2(260, 70)
    train.pressed.connect(func(): _train(index))
    stage.add_child(train)
    var evolve := Button.new()
    evolve.text = "EVOLVE"
    evolve.position = Vector2(380, 720)
    evolve.size = Vector2(260, 70)
    evolve.pressed.connect(func(): _evolve(index))
    stage.add_child(evolve)
    footer.add_child(_nav_btn("BACK", _units))
    footer.add_child(_nav_btn("HOME", _home))

func _train(index: int) -> void:
    if gold < 300:
        toast.text = "Not enough Gold"
        return
    gold -= 300
    var unit: Dictionary = inventory[index]
    unit["xp"] = int(unit["xp"]) + 120
    while int(unit["level"]) < 40 and int(unit["xp"]) >= 80 + int(unit["level"]) * 20:
        unit["xp"] -= 80 + int(unit["level"]) * 20
        unit["level"] += 1
    _save()
    _unit_details(index)

func _evolve(index: int) -> void:
    var unit: Dictionary = inventory[index]
    var definition: Dictionary = unit_defs[int(unit["def_id"])]
    if int(unit["evo"]) >= 2:
        toast.text = "Evolution cap reached"
        return
    var mat := _mat(str(definition["element"]))
    var need := 2 + int(unit["evo"])
    var cost := 1000 + int(unit["evo"]) * 750
    if int(materials.get(mat, 0)) < need or gold < cost:
        toast.text = "Need %d %s + %d Gold" % [need, mat, cost]
        return
    materials[mat] -= need
    gold -= cost
    unit["evo"] += 1
    unit["level"] = 1
    unit["xp"] = 0
    _save()
    _unit_details(index)

func _summon() -> void:
    _clear_stage()
    page_title.text = "SUMMON GATE"
    _refresh_header()
    var panel := PanelContainer.new()
    panel.position = Vector2(35, 30)
    panel.size = Vector2(650, 560)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("281746")
    style.corner_radius_top_left = 24
    style.corner_radius_top_right = 24
    style.corner_radius_bottom_left = 24
    style.corner_radius_bottom_right = 24
    panel.add_theme_stylebox_override("panel", style)
    stage.add_child(panel)
    var crystal := Label.new()
    crystal.text = "✦\n◇\n✦"
    crystal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    crystal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    crystal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    crystal.add_theme_font_size_override("font_size", 92)
    crystal.add_theme_color_override("font_color", Color("c49cff"))
    panel.add_child(crystal)
    var pull := Button.new()
    pull.text = "SUMMON • 5 GEMS"
    pull.position = Vector2(120, 630)
    pull.size = Vector2(480, 90)
    pull.add_theme_font_size_override("font_size", 24)
    pull.pressed.connect(_do_summon)
    stage.add_child(pull)
    var test := HBoxContainer.new()
    test.position = Vector2(105, 735)
    test.size = Vector2(510, 65)
    stage.add_child(test)
    for amount in [5, 50, 500]:
        var gem_button := Button.new()
        gem_button.text = "+%d" % amount
        gem_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        gem_button.pressed.connect(func(value=amount): gems += value; _save(); _summon())
        test.add_child(gem_button)
    _nav()

func _do_summon() -> void:
    if gems < 5:
        toast.text = "Not enough Gems"
        return
    gems -= 5
    var chosen := randi() % unit_defs.size()
    var owned := false
    for unit in inventory:
        if int(unit["def_id"]) == chosen:
            owned = true
            break
    if owned:
        gems += 5
        _save()
        _summon_result(chosen, true)
        return
    inventory.append(_new_unit(chosen))
    _save()
    _summon_result(chosen, false)

func _summon_result(def_id: int, duplicate: bool) -> void:
    _clear_stage()
    var definition: Dictionary = unit_defs[def_id]
    page_title.text = "SUMMON RESULT"
    _refresh_header()
    var art := _unit_portrait(def_id, Vector2(420, 570), true)
    art.position = Vector2(150, 40)
    stage.add_child(art)
    var label := Label.new()
    label.text = "DUPLICATE • 5 GEMS REFUNDED" if duplicate else "%s joined your party!" % definition["name"]
    label.position = Vector2(50, 640)
    label.size = Vector2(620, 80)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 22)
    label.add_theme_color_override("font_color", GREEN if duplicate else GOLD)
    stage.add_child(label)
    footer.add_child(_nav_btn("AGAIN", _summon))
    footer.add_child(_nav_btn("UNITS", _units))
    footer.add_child(_nav_btn("HOME", _home))

func _squad() -> void:
    _clear_stage()
    page_title.text = "SQUAD"
    _refresh_header()
    var grid := GridContainer.new()
    grid.columns = 3
    grid.position = Vector2(18, 20)
    grid.size = Vector2(664, 760)
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    stage.add_child(grid)
    for slot in range(6):
        var unit_index := int(squad[slot])
        var unit: Dictionary = inventory[unit_index]
        var box := VBoxContainer.new()
        box.custom_minimum_size = Vector2(216, 350)
        box.add_child(_unit_portrait(int(unit["def_id"]), Vector2(216, 245), true))
        var button := Button.new()
        button.text = "★ LEADER" if slot == 0 else "SLOT %d" % (slot + 1)
        button.custom_minimum_size = Vector2(0, 80)
        button.pressed.connect(func(s=slot): _choose_squad(s))
        box.add_child(button)
        grid.add_child(box)
    _nav()

func _choose_squad(slot: int) -> void:
    _clear_stage()
    page_title.text = "CHOOSE SLOT %d" % (slot + 1)
    var grid := GridContainer.new()
    grid.columns = 3
    grid.position = Vector2(18, 20)
    grid.size = Vector2(664, 760)
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    stage.add_child(grid)
    for index in range(mini(6, inventory.size())):
        var unit: Dictionary = inventory[index]
        var button := Button.new()
        button.custom_minimum_size = Vector2(216, 240)
        button.text = "%s\nLv.%d" % [unit_defs[int(unit["def_id"])]["name"], unit["level"]]
        button.icon = _texture(int(unit["def_id"]))
        button.expand_icon = true
        button.pressed.connect(func(idx=index, s=slot): squad[s] = idx; _save(); _squad())
        grid.add_child(button)
    footer.add_child(_nav_btn("BACK", _squad))
    footer.add_child(_nav_btn("HOME", _home))

func _training() -> void:
    training_mode = false
    _clear_stage()
    page_title.text = "TRAINING HALL"
    _refresh_header()
    var title := Label.new()
    title.text = "TRAINING GOLEM\nNo rewards • No costs"
    title.position = Vector2(80, 35)
    title.size = Vector2(560, 100)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    stage.add_child(title)
    var hp_row := HBoxContainer.new()
    hp_row.position = Vector2(75, 165)
    hp_row.size = Vector2(570, 70)
    stage.add_child(hp_row)
    for value in [5000, 25000, 100000]:
        var button := Button.new()
        button.text = "%dK" % int(value / 1000)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(func(v=value): training_max_hp = v; toast.text = "Target HP: %d" % v)
        hp_row.add_child(button)
    var elements := GridContainer.new()
    elements.columns = 3
    elements.position = Vector2(75, 260)
    elements.size = Vector2(570, 180)
    stage.add_child(elements)
    for element in ["Fire","Water","Earth","Thunder","Light","Dark"]:
        var button := Button.new()
        button.text = element
        button.custom_minimum_size = Vector2(185, 80)
        button.pressed.connect(func(v=element): training_element = v; toast.text = "Element: %s" % v)
        elements.add_child(button)
    var modes := VBoxContainer.new()
    modes.position = Vector2(120, 485)
    modes.size = Vector2(480, 270)
    stage.add_child(modes)
    var full := Button.new()
    full.text = "TEST FULL SQUAD"
    full.custom_minimum_size = Vector2(0, 80)
    full.pressed.connect(func(): _start_training(-1))
    modes.add_child(full)
    var leader := Button.new()
    leader.text = "TEST LEADER ONLY"
    leader.custom_minimum_size = Vector2(0, 80)
    leader.pressed.connect(func(): _start_training(0))
    modes.add_child(leader)
    _nav()

func _start_training(slot: int) -> void:
    training_mode = true
    training_single_slot = slot
    enemy_max_hp = training_max_hp
    enemy_hp = enemy_max_hp
    _prepare_battle()
    _battle("Training ready")

func _training_refill() -> void:
    for slot in range(6):
        battle_hp[slot] = _unit_hp(inventory[int(squad[slot])])
    _battle("HP restored")

func _training_fill() -> void:
    for slot in range(6):
        inventory[int(squad[slot])]["bb"] = 10
    _battle("BB charged")

func _training_reset() -> void:
    enemy_hp = training_max_hp
    enemy_max_hp = training_max_hp
    _battle("Target restored")

func _more() -> void:
    _clear_stage()
    page_title.text = "MORE"
    _refresh_header()
    var grid := GridContainer.new()
    grid.columns = 2
    grid.position = Vector2(18, 190)
    grid.size = Vector2(664, 390)
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    stage.add_child(grid)
    grid.add_child(_menu_btn("MATERIALS\nEvolution stock", _materials))
    grid.add_child(_menu_btn("TRAINING\nDamage sandbox", _training))
    grid.add_child(_menu_btn("+50 GEMS\nTester shortcut", func(): gems += 50; _save(); _more()))
    grid.add_child(_menu_btn("HOME\nReturn", _home))
    _nav()

func _materials() -> void:
    _clear_stage()
    page_title.text = "MATERIALS"
    var grid := GridContainer.new()
    grid.columns = 2
    grid.position = Vector2(100, 100)
    grid.size = Vector2(520, 560)
    stage.add_child(grid)
    for key in materials.keys():
        var label := Label.new()
        label.text = "%s\n× %d" % [key, materials[key]]
        label.custom_minimum_size = Vector2(250, 170)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 24)
        grid.add_child(label)
    _nav()

func _unit_portrait(def_id: int, size_value: Vector2, show_name: bool) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.custom_minimum_size = size_value
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var texture_rect := TextureRect.new()
    var name_space := 32.0 if show_name else 0.0
    texture_rect.custom_minimum_size = Vector2(size_value.x, maxf(80.0, size_value.y - name_space))
    texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_rect.texture = _texture(def_id)
    box.add_child(texture_rect)
    if show_name:
        var label := Label.new()
        label.text = unit_defs[def_id]["name"] if def_id >= 0 and def_id < unit_defs.size() else "Unit"
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 15)
        box.add_child(label)
    return box

func _texture(def_id: int) -> Texture2D:
    if def_id >= 0 and def_id < 6:
        var path := "user://bf_assets/%s" % unit_defs[def_id]["cache"]
        if FileAccess.file_exists(path):
            var image := Image.new()
            if image.load(ProjectSettings.globalize_path(path)) == OK:
                return ImageTexture.create_from_image(image)
    var gradient_texture := GradientTexture2D.new()
    var gradient := Gradient.new()
    var color := Color("52677e")
    if def_id >= 0 and def_id < unit_defs.size():
        color = _element_color(str(unit_defs[def_id]["element"]))
    gradient.colors = PackedColorArray([color, Color("0a1220")])
    gradient_texture.gradient = gradient
    gradient_texture.width = 256
    gradient_texture.height = 256
    return gradient_texture

func _new_unit(def_id: int) -> Dictionary:
    return {"def_id":def_id,"level":1,"xp":0,"evo":0,"bb":0,"locked":false}

func _seed_inventory() -> void:
    if inventory.is_empty():
        for index in range(6):
            inventory.append(_new_unit(index))

func _repair_state() -> void:
    if inventory.size() < 6:
        inventory.clear()
        _seed_inventory()
    if squad.size() != 6:
        squad = [0,1,2,3,4,5]
    for index in range(6):
        squad[index] = clampi(int(squad[index]), 0, inventory.size() - 1)

func _unit_hp(unit: Dictionary) -> int:
    return int(float(unit_defs[int(unit["def_id"])]["base_hp"]) * (1.0 + (int(unit["level"]) - 1) * 0.035 + int(unit["evo"]) * 0.22))

func _unit_atk(unit: Dictionary) -> int:
    return int(float(unit_defs[int(unit["def_id"])]["base_atk"]) * (1.0 + (int(unit["level"]) - 1) * 0.032 + int(unit["evo"]) * 0.20))

func _rarity(unit: Dictionary) -> int:
    return mini(6, int(unit_defs[int(unit["def_id"])]["rarity"]) + int(unit["evo"]))

func _rank_up() -> void:
    var need := 100 + rank * 25
    while rank_xp >= need:
        rank_xp -= need
        rank += 1
        need = 100 + rank * 25

func _mat(element: String) -> String:
    match element:
        "Fire": return "Ember"
        "Water": return "Tide"
        "Earth": return "Verdant"
        "Thunder": return "Volt"
        "Light": return "Lumen"
        _: return "Dusk"

func _element_color(element: String) -> Color:
    match element:
        "Fire": return Color("d95145")
        "Water": return Color("348dd1")
        "Earth": return Color("4c9b58")
        "Thunder": return Color("d5ad38")
        "Light": return Color("d8c97d")
        "Dark": return Color("8a5aac")
        _: return Color("52677e")

func _element_multiplier(attacker: String, defender: String) -> float:
    if defender == "Neutral":
        return 1.0
    if (attacker == "Fire" and defender == "Earth") or (attacker == "Earth" and defender == "Thunder") or (attacker == "Thunder" and defender == "Water") or (attacker == "Water" and defender == "Fire") or (attacker == "Light" and defender == "Dark") or (attacker == "Dark" and defender == "Light"):
        return 1.35
    if (defender == "Fire" and attacker == "Earth") or (defender == "Earth" and attacker == "Thunder") or (defender == "Thunder" and attacker == "Water") or (defender == "Water" and attacker == "Fire"):
        return 0.75
    return 1.0

func _save() -> void:
    var file := FileAccess.open("user://save.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify({"save_version":SAVE_VERSION,"gems":gems,"gold":gold,"rank":rank,"rank_xp":rank_xp,"unlocked_quest":unlocked_quest,"cleared_quests":cleared_quests,"materials":materials,"squad":squad,"inventory":inventory,"selected":selected}))

func _load_save() -> void:
    if not FileAccess.file_exists("user://save.json"):
        return
    var file := FileAccess.open("user://save.json", FileAccess.READ)
    if not file:
        return
    var data = JSON.parse_string(file.get_as_text())
    if typeof(data) != TYPE_DICTIONARY:
        return
    gems = maxi(0, int(data.get("gems", gems)))
    gold = maxi(0, int(data.get("gold", gold)))
    rank = maxi(1, int(data.get("rank", rank)))
    rank_xp = maxi(0, int(data.get("rank_xp", 0)))
    unlocked_quest = clampi(int(data.get("unlocked_quest", 0)), 0, quests.size() - 1)
    selected = maxi(0, int(data.get("selected", 0)))
    if typeof(data.get("cleared_quests", [])) == TYPE_ARRAY:
        cleared_quests = data.get("cleared_quests", [])
    if typeof(data.get("inventory", null)) == TYPE_ARRAY and data["inventory"].size() >= 6:
        inventory = data["inventory"]
    if typeof(data.get("squad", null)) == TYPE_ARRAY and data["squad"].size() == 6:
        squad = data["squad"]
    if typeof(data.get("materials", null)) == TYPE_DICTIONARY:
        for key in materials.keys():
            materials[key] = maxi(0, int(data["materials"].get(key, 0)))
