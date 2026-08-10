extends Control

const BG := Color("09101c")
const PANEL := Color("162238")
const PANEL_2 := Color("223451")
const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("9fb0ca")

var gems := 20
var gold := 1000
var rank := 1
var selected := 0
var units := [
    {"name":"Kael, Ember Squire","element":"Fire","rarity":3,"hp":920,"atk":410,"bb":0},
    {"name":"Mira, Tide Mender","element":"Water","rarity":3,"hp":870,"atk":350,"bb":0},
    {"name":"Bram, Verdant Guard","element":"Earth","rarity":3,"hp":1080,"atk":330,"bb":0},
    {"name":"Rin, Gale Runner","element":"Thunder","rarity":3,"hp":820,"atk":445,"bb":0},
    {"name":"Sera, Lumen Adept","element":"Light","rarity":3,"hp":890,"atk":390,"bb":0},
    {"name":"Veyr, Dusk Reaver","element":"Dark","rarity":3,"hp":900,"atk":430,"bb":0}
]
var body: VBoxContainer
var status: Label

func _ready() -> void:
    _load_save()
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 14)
    root.add_theme_constant_override("margin_left", 18)
    add_child(root)

    var title := Label.new()
    title.text = "FRONTIER OFFLINE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 38)
    title.add_theme_color_override("font_color", GOLD)
    root.add_child(title)

    status = Label.new()
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 20)
    status.add_theme_color_override("font_color", MUTED)
    root.add_child(status)

    body = VBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 14)
    root.add_child(body)
    _home()

func _home() -> void:
    _clear()
    _refresh()
    _heading("GRAND GAIA", "Offline Android prototype • touch-first test build")
    _add_button("QUEST", _quest)
    _add_button("SQUAD", _squad)
    _add_button("SUMMON", _summon)
    _add_button("SAVE", func(): _save(); _home())

func _quest() -> void:
    _clear()
    _heading("ASHEN COAST", "1-1: Cinders on the Road")
    var enemy := Label.new()
    enemy.text = "ASH SLIME\nFire • HP 520\n\nTap ATTACK to send your selected unit forward.\nBuild BB and defeat the enemy to earn rewards."
    enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    enemy.add_theme_font_size_override("font_size", 24)
    enemy.add_theme_color_override("font_color", TEXT)
    body.add_child(enemy)
    var hp := 520
    var hp_label := Label.new()
    hp_label.text = "Enemy HP: %d" % hp
    hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_label.add_theme_font_size_override("font_size", 28)
    body.add_child(hp_label)
    var attack := _button("ATTACK", func(): pass)
    attack.pressed.connect(func():
        if hp <= 0: return
        var u = units[selected]
        var damage := maxi(60, int(u.atk * randf_range(0.28, 0.42)))
        hp = maxi(0, hp - damage)
        u.bb = mini(10, int(u.bb) + 3)
        hp_label.text = "Enemy HP: %d\n%s dealt %d damage • BB %d/10" % [hp, u.name, damage, u.bb]
        if hp == 0:
            gold += 250
            gems += 1
            rank += 1
            hp_label.text += "\n\nVICTORY! +250 Gold • +1 Gem"
            _save()
            _refresh()
    )
    body.add_child(attack)
    _add_button("BACK", _home)

func _squad() -> void:
    _clear()
    _heading("SQUAD", "Choose the unit used for the prototype battle")
    for i in range(units.size()):
        var u = units[i]
        var label := "%s%s\n%s • %d★ • HP %d • ATK %d" % ["★ " if i == selected else "", u.name, u.element, u.rarity, u.hp, u.atk]
        var b := _button(label, func(index=i): selected=index; _save(); _squad())
        body.add_child(b)
    _add_button("BACK", _home)

func _summon() -> void:
    _clear()
    _heading("SUMMON GATE", "Spend 5 earned Gems. No purchases, servers, or energy system.")
    var result := Label.new()
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.add_theme_font_size_override("font_size", 25)
    result.add_theme_color_override("font_color", TEXT)
    body.add_child(result)
    var summon := _button("SUMMON • 5 GEMS", func(): pass)
    summon.pressed.connect(func():
        if gems < 5:
            result.text = "Not enough Gems."
            return
        gems -= 5
        var u = units[randi() % units.size()]
        result.text = "You summoned\n%s\n%s • %d★" % [u.name, u.element, u.rarity]
        _save(); _refresh()
    )
    body.add_child(summon)
    _add_button("BACK", _home)

func _heading(a: String, b: String) -> void:
    var h := Label.new()
    h.text = a
    h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    h.add_theme_font_size_override("font_size", 32)
    h.add_theme_color_override("font_color", GOLD)
    body.add_child(h)
    var s := Label.new()
    s.text = b
    s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    s.add_theme_font_size_override("font_size", 19)
    s.add_theme_color_override("font_color", MUTED)
    body.add_child(s)

func _add_button(label: String, callback: Callable) -> void:
    body.add_child(_button(label, callback))

func _button(label: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(0, 92)
    b.add_theme_font_size_override("font_size", 23)
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
    for child in body.get_children(): child.queue_free()

func _refresh() -> void:
    status.text = "Rank %d     Gold %d     Gems %d" % [rank, gold, gems]

func _save() -> void:
    var f := FileAccess.open("user://save.json", FileAccess.WRITE)
    if f: f.store_string(JSON.stringify({"gems":gems,"gold":gold,"rank":rank,"selected":selected}))

func _load_save() -> void:
    if not FileAccess.file_exists("user://save.json"): return
    var f := FileAccess.open("user://save.json", FileAccess.READ)
    if not f: return
    var data = JSON.parse_string(f.get_as_text())
    if typeof(data) != TYPE_DICTIONARY: return
    gems = int(data.get("gems", gems))
    gold = int(data.get("gold", gold))
    rank = int(data.get("rank", rank))
    selected = clampi(int(data.get("selected", selected)), 0, units.size() - 1)
