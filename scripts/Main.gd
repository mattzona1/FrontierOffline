extends Control

const PANEL := Color("162238")
const PANEL_2 := Color("223451")
const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("9fb0ca")
const RED := Color("ff6b6b")
const GREEN := Color("6ee7a8")
const BLUE := Color("6eb6ff")

var gems := 20
var gold := 1000
var rank := 1
var selected := 0
var body: VBoxContainer
var status: Label
var battle_log: Label
var enemy_label: Label
var enemy_hp_bar: ProgressBar
var wave_label: Label
var squad_grid: GridContainer
var battle_buttons: Array[Button] = []
var current_quest: Dictionary = {}
var current_wave := 0
var enemy_hp := 0
var enemy_max_hp := 0
var battle_active := false
var last_attack_ms := 0
var last_attacker := -1
var spark_chain := 0

var units := [
    {"name":"Kael","title":"Ember Squire","element":"Fire","rarity":3,"hp":920,"atk":410,"bb":0,"max_bb":10,"hits":5,"bb_name":"Blazing Arc"},
    {"name":"Mira","title":"Tide Mender","element":"Water","rarity":3,"hp":870,"atk":350,"bb":0,"max_bb":10,"hits":4,"bb_name":"Cresting Surge"},
    {"name":"Bram","title":"Verdant Guard","element":"Earth","rarity":3,"hp":1080,"atk":330,"bb":0,"max_bb":10,"hits":3,"bb_name":"Stonewake"},
    {"name":"Rin","title":"Gale Runner","element":"Thunder","rarity":3,"hp":820,"atk":445,"bb":0,"max_bb":10,"hits":6,"bb_name":"Volt Rush"},
    {"name":"Sera","title":"Lumen Adept","element":"Light","rarity":3,"hp":890,"atk":390,"bb":0,"max_bb":10,"hits":5,"bb_name":"Radiant Choir"},
    {"name":"Veyr","title":"Dusk Reaver","element":"Dark","rarity":3,"hp":900,"atk":430,"bb":0,"max_bb":10,"hits":5,"bb_name":"Nightfall Edge"}
]

var quests := [
    {"name":"1-1 Cinders on the Road","area":"ASHEN COAST","reward_gold":300,"reward_gems":1,"waves":[
        {"name":"Ash Slime","element":"Fire","hp":540,"atk":55},
        {"name":"Cinder Imp","element":"Fire","hp":700,"atk":70},
        {"name":"Scoria Brute","element":"Earth","hp":1050,"atk":90}
    ]},
    {"name":"1-2 Tide Against Flame","area":"ASHEN COAST","reward_gold":450,"reward_gems":1,"waves":[
        {"name":"Boiling Wisp","element":"Water","hp":720,"atk":75},
        {"name":"Coalback Hound","element":"Fire","hp":900,"atk":85},
        {"name":"Magma Warden","element":"Fire","hp":1350,"atk":105}
    ]},
    {"name":"1-3 The Broken Beacon","area":"ASHEN COAST","reward_gold":650,"reward_gems":2,"waves":[
        {"name":"Gloom Bat","element":"Dark","hp":780,"atk":80},
        {"name":"Storm Idol","element":"Thunder","hp":1050,"atk":100},
        {"name":"Beacon Tyrant","element":"Light","hp":1750,"atk":125}
    ]}
]

func _ready() -> void:
    randomize()
    _load_save()
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 12)
    root.offset_left = 16
    root.offset_right = -16
    root.offset_top = 18
    root.offset_bottom = -18
    add_child(root)

    var title := Label.new()
    title.text = "FRONTIER OFFLINE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 34)
    title.add_theme_color_override("font_color", GOLD)
    root.add_child(title)

    status = Label.new()
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 18)
    status.add_theme_color_override("font_color", MUTED)
    root.add_child(status)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)

    body = VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 12)
    scroll.add_child(body)
    _home()

func _home() -> void:
    battle_active = false
    _clear()
    _refresh()
    _heading("GRAND GAIA", "Single-player mobile test build")
    _add_button("QUESTS", _quest_select)
    _add_button("SQUAD", _squad)
    _add_button("SUMMON", _summon)
    _add_button("UNIT GUIDE", _unit_guide)
    _add_button("SAVE GAME", func(): _save(); _home())

func _quest_select() -> void:
    _clear()
    _heading("QUESTS", "Ashen Coast • three-wave combat test")
    for i in range(quests.size()):
        var q: Dictionary = quests[i]
        var text := "%s\n%s • %d Gold • %d Gem%s" % [q.name, q.area, q.reward_gold, q.reward_gems, "s" if q.reward_gems != 1 else ""]
        body.add_child(_button(text, func(index=i): _start_quest(index)))
    _add_button("BACK", _home)

func _start_quest(index: int) -> void:
    current_quest = quests[index]
    current_wave = 0
    battle_active = true
    last_attack_ms = 0
    last_attacker = -1
    spark_chain = 0
    for u in units:
        u.bb = 0
    _load_wave()

func _load_wave() -> void:
    var e: Dictionary = current_quest.waves[current_wave]
    enemy_max_hp = int(e.hp)
    enemy_hp = enemy_max_hp
    _render_battle("Wave %d begins!" % (current_wave + 1))

func _render_battle(message: String = "") -> void:
    _clear()
    _refresh()

    wave_label = Label.new()
    wave_label.text = "%s  •  WAVE %d/%d" % [current_quest.name, current_wave + 1, current_quest.waves.size()]
    wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    wave_label.add_theme_font_size_override("font_size", 18)
    wave_label.add_theme_color_override("font_color", MUTED)
    body.add_child(wave_label)

    var e: Dictionary = current_quest.waves[current_wave]
    var enemy_panel := VBoxContainer.new()
    enemy_panel.add_theme_constant_override("separation", 6)
    enemy_label = Label.new()
    enemy_label.text = "%s\n%s" % [e.name, e.element]
    enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    enemy_label.add_theme_font_size_override("font_size", 30)
    enemy_label.add_theme_color_override("font_color", RED)
    enemy_panel.add_child(enemy_label)

    enemy_hp_bar = ProgressBar.new()
    enemy_hp_bar.max_value = enemy_max_hp
    enemy_hp_bar.value = enemy_hp
    enemy_hp_bar.custom_minimum_size = Vector2(0, 34)
    enemy_hp_bar.show_percentage = false
    enemy_panel.add_child(enemy_hp_bar)

    var hp_text := Label.new()
    hp_text.text = "HP %d / %d" % [enemy_hp, enemy_max_hp]
    hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_text.add_theme_font_size_override("font_size", 18)
    enemy_panel.add_child(hp_text)
    body.add_child(enemy_panel)

    battle_log = Label.new()
    battle_log.text = message if message != "" else "Tap a unit to attack. Tap a full BB button to unleash its Brave Burst."
    battle_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    battle_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    battle_log.custom_minimum_size = Vector2(0, 78)
    battle_log.add_theme_font_size_override("font_size", 18)
    battle_log.add_theme_color_override("font_color", TEXT)
    body.add_child(battle_log)

    squad_grid = GridContainer.new()
    squad_grid.columns = 2
    squad_grid.add_theme_constant_override("h_separation", 10)
    squad_grid.add_theme_constant_override("v_separation", 10)
    body.add_child(squad_grid)
    battle_buttons.clear()

    for i in range(units.size()):
        var u: Dictionary = units[i]
        var wrap := VBoxContainer.new()
        wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        var atk := _button(_unit_attack_text(u), func(index=i): _attack_unit(index))
        atk.custom_minimum_size = Vector2(0, 104)
        wrap.add_child(atk)
        battle_buttons.append(atk)

        var bb := _button(_unit_bb_text(u), func(index=i): _brave_burst(index))
        bb.custom_minimum_size = Vector2(0, 64)
        bb.disabled = int(u.bb) < int(u.max_bb)
        wrap.add_child(bb)
        squad_grid.add_child(wrap)

    _add_button("RETREAT", _home)

func _attack_unit(index: int) -> void:
    if not battle_active or enemy_hp <= 0:
        return
    var u: Dictionary = units[index]
    var e: Dictionary = current_quest.waves[current_wave]
    var now := Time.get_ticks_msec()
    var sparked := last_attack_ms > 0 and now - last_attack_ms <= 650 and last_attacker != index
    if sparked:
        spark_chain += 1
    else:
        spark_chain = 0
    last_attack_ms = now
    last_attacker = index

    var modifier := randf_range(0.58, 0.78)
    var damage := int(float(u.atk) * modifier * _element_multiplier(str(u.element), str(e.element)))
    if sparked:
        damage = int(damage * (1.18 + minf(float(spark_chain) * 0.04, 0.20)))
    enemy_hp = maxi(0, enemy_hp - damage)
    u.bb = mini(int(u.max_bb), int(u.bb) + 2 + (1 if sparked else 0))

    var msg := "%s attacks for %d damage" % [u.name, damage]
    if sparked:
        msg += " • SPARK x%d!" % (spark_chain + 1)
    if enemy_hp <= 0:
        _finish_wave(msg)
    else:
        _enemy_turn(msg)

func _brave_burst(index: int) -> void:
    if not battle_active or enemy_hp <= 0:
        return
    var u: Dictionary = units[index]
    if int(u.bb) < int(u.max_bb):
        return
    var e: Dictionary = current_quest.waves[current_wave]
    var damage := int(float(u.atk) * randf_range(1.55, 1.85) * _element_multiplier(str(u.element), str(e.element)))
    enemy_hp = maxi(0, enemy_hp - damage)
    u.bb = 0
    spark_chain = 0
    var msg := "%s unleashes %s! %d damage!" % [u.name, u.bb_name, damage]
    if enemy_hp <= 0:
        _finish_wave(msg)
    else:
        _enemy_turn(msg)

func _enemy_turn(player_msg: String) -> void:
    var e: Dictionary = current_quest.waves[current_wave]
    var target := randi() % units.size()
    var target_unit: Dictionary = units[target]
    var pressure := int(e.atk) + randi_range(-10, 12)
    var bb_gain := 1 if pressure > 0 else 0
    target_unit.bb = mini(int(target_unit.max_bb), int(target_unit.bb) + bb_gain)
    _render_battle("%s\n%s retaliates at %s for %d pressure." % [player_msg, e.name, target_unit.name, pressure])

func _finish_wave(player_msg: String) -> void:
    if current_wave + 1 < current_quest.waves.size():
        current_wave += 1
        var next_enemy: Dictionary = current_quest.waves[current_wave]
        enemy_max_hp = int(next_enemy.hp)
        enemy_hp = enemy_max_hp
        spark_chain = 0
        _render_battle("%s\nEnemy defeated! Wave %d approaches." % [player_msg, current_wave + 1])
        return
    battle_active = false
    gold += int(current_quest.reward_gold)
    gems += int(current_quest.reward_gems)
    rank += 1
    _save()
    _clear()
    _refresh()
    _heading("QUEST CLEAR", current_quest.name)
    var result := Label.new()
    result.text = "%s\n\n+%d Gold\n+%d Gem%s\nRank increased to %d" % [player_msg, current_quest.reward_gold, current_quest.reward_gems, "s" if int(current_quest.reward_gems) != 1 else "", rank]
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.add_theme_font_size_override("font_size", 24)
    result.add_theme_color_override("font_color", GREEN)
    body.add_child(result)
    _add_button("RETURN TO QUESTS", _quest_select)
    _add_button("HOME", _home)

func _unit_attack_text(u: Dictionary) -> String:
    return "%s • %s\n%s • %d★\nATK %d • %d hits" % [u.name, u.title, u.element, u.rarity, u.atk, u.hits]

func _unit_bb_text(u: Dictionary) -> String:
    return "BB %d/%d  •  %s" % [u.bb, u.max_bb, u.bb_name]

func _element_multiplier(attacker: String, defender: String) -> float:
    if (attacker == "Fire" and defender == "Earth") or (attacker == "Earth" and defender == "Thunder") or (attacker == "Thunder" and defender == "Water") or (attacker == "Water" and defender == "Fire"):
        return 1.35
    if (defender == "Fire" and attacker == "Earth") or (defender == "Earth" and attacker == "Thunder") or (defender == "Thunder" and attacker == "Water") or (defender == "Water" and attacker == "Fire"):
        return 0.75
    if (attacker == "Light" and defender == "Dark") or (attacker == "Dark" and defender == "Light"):
        return 1.35
    return 1.0

func _squad() -> void:
    _clear()
    _heading("SQUAD", "Six-unit squad • leader slot preview")
    for i in range(units.size()):
        var u: Dictionary = units[i]
        var marker := "LEADER • " if i == selected else ""
        var label := "%s%s, %s\n%s • %d★ • HP %d • ATK %d • %d hits" % [marker, u.name, u.title, u.element, u.rarity, u.hp, u.atk, u.hits]
        body.add_child(_button(label, func(index=i): selected=index; _save(); _squad()))
    _add_button("BACK", _home)

func _unit_guide() -> void:
    _clear()
    _heading("UNIT GUIDE", "%d discovered units" % units.size())
    for u in units:
        var card := Label.new()
        card.text = "%s, %s\n%s • %d★\nHP %d • ATK %d • %d hits\nBB: %s" % [u.name, u.title, u.element, u.rarity, u.hp, u.atk, u.hits, u.bb_name]
        card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        card.add_theme_font_size_override("font_size", 20)
        card.add_theme_color_override("font_color", TEXT)
        body.add_child(card)
    _add_button("BACK", _home)

func _summon() -> void:
    _clear()
    _heading("SUMMON GATE", "Spend 5 earned Gems • offline prototype pool")
    var result := Label.new()
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.add_theme_font_size_override("font_size", 24)
    result.add_theme_color_override("font_color", TEXT)
    body.add_child(result)
    var summon := _button("SUMMON • 5 GEMS", func(): pass)
    summon.pressed.connect(func():
        if gems < 5:
            result.text = "Not enough Gems. Clear quests to earn more."
            return
        gems -= 5
        var u: Dictionary = units[randi() % units.size()]
        var bonus := randi_range(150, 300)
        gold += bonus
        result.text = "SUMMON RESULT\n%s, %s\n%s • %d★\nDuplicate Merit converted to +%d Gold" % [u.name, u.title, u.element, u.rarity, bonus]
        _save()
        _refresh()
    )
    body.add_child(summon)
    _add_button("BACK", _home)

func _heading(a: String, b: String) -> void:
    var h := Label.new()
    h.text = a
    h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.add_theme_font_size_override("font_size", 30)
    h.add_theme_color_override("font_color", GOLD)
    body.add_child(h)
    var s := Label.new()
    s.text = b
    s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    s.add_theme_font_size_override("font_size", 18)
    s.add_theme_color_override("font_color", MUTED)
    body.add_child(s)

func _add_button(label: String, callback: Callable) -> void:
    body.add_child(_button(label, callback))

func _button(label: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(0, 86)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

func _clear() -> void:
    for child in body.get_children():
        body.remove_child(child)
        child.queue_free()

func _refresh() -> void:
    status.text = "Rank %d     Gold %d     Gems %d" % [rank, gold, gems]

func _save() -> void:
    var f := FileAccess.open("user://save.json", FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify({"gems":gems,"gold":gold,"rank":rank,"selected":selected}))

func _load_save() -> void:
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
    rank = int(data.get("rank", rank))
    selected = clampi(int(data.get("selected", selected)), 0, units.size() - 1)
