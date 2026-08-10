extends Node

var game: Node
var tick := 0.0
var last_page := ""
var last_enemy_hp := -1
var last_wave := -1
var last_attacker := -1
var last_bb: Array = []
var stage_ref: Control
var portraits: Array = []
var enemy_art: TextureRect
var idle_time := 0.0
var busy_slots := {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
    idle_time += delta
    tick += delta
    if game == null or not is_instance_valid(game): return
    var page := _page()
    if page != "BATTLE" and page != "TRAINING":
        last_page = page
        stage_ref = null
        portraits.clear()
        enemy_art = null
        last_enemy_hp = -1
        last_wave = -1
        last_bb.clear()
        return
    if tick >= 0.08:
        tick = 0.0
        _sync_battle()
    _idle_motion()

func _page() -> String:
    var title = game.get("page_title")
    return str(title.text) if title != null and is_instance_valid(title) else ""

func _sync_battle() -> void:
    var stage = game.get("stage")
    if stage == null or not is_instance_valid(stage): return
    if stage_ref != stage or portraits.is_empty():
        stage_ref = stage
        await get_tree().process_frame
        _find_battle_art()
        _install_vignette()
    var hp := int(game.get("enemy_hp"))
    var wave := int(game.get("current_wave"))
    var attacker := int(game.get("last_attacker"))
    var bb_now := _bb_values()
    if last_wave != -1 and wave != last_wave:
        _wave_intro(wave + 1)
    if last_enemy_hp >= 0 and hp < last_enemy_hp:
        var damage := last_enemy_hp - hp
        var bb_slot := _find_bb_trigger(last_bb, bb_now)
        if bb_slot >= 0:
            _play_brave_burst(bb_slot, damage)
        elif attacker >= 0:
            _play_attack(attacker, damage)
        _enemy_impact(damage)
    last_enemy_hp = hp
    last_wave = wave
    last_attacker = attacker
    last_bb = bb_now

func _find_battle_art() -> void:
    portraits.clear()
    enemy_art = null
    if stage_ref == null: return
    var rects: Array = []
    _collect_rects(stage_ref, rects)
    for rect in rects:
        if rect.has_meta("battle_enemy_art"):
            enemy_art = rect
        elif not rect.has_meta("battle_feel") and not rect.has_meta("bf_ui_extra"):
            portraits.append(rect)
    if portraits.size() > 6:
        portraits = portraits.slice(maxi(0, portraits.size() - 6), portraits.size())
    if enemy_art == null:
        for rect in rects:
            if rect.has_meta("battle_feel") and rect.size.x >= 200 and rect.position.y < 230:
                enemy_art = rect
                rect.set_meta("battle_enemy_art", true)
                break
    for rect in portraits:
        rect.pivot_offset = rect.size * 0.5

func _collect_rects(node: Node, out: Array) -> void:
    if node is TextureRect: out.append(node)
    for child in node.get_children(): _collect_rects(child, out)

func _bb_values() -> Array:
    var values: Array = []
    var inventory = game.get("inventory")
    var squad = game.get("squad")
    if typeof(inventory) != TYPE_ARRAY or typeof(squad) != TYPE_ARRAY: return values
    for slot in range(mini(6, squad.size())):
        var idx := int(squad[slot])
        values.append(int(inventory[idx].get("bb", 0)) if idx >= 0 and idx < inventory.size() else 0)
    return values

func _find_bb_trigger(before: Array, after: Array) -> int:
    if before.size() != after.size(): return -1
    for i in range(before.size()):
        if int(before[i]) >= 10 and int(after[i]) == 0: return i
    return -1

func _idle_motion() -> void:
    if portraits.is_empty(): return
    for i in range(portraits.size()):
        var rect = portraits[i]
        if rect == null or not is_instance_valid(rect) or busy_slots.has(i): continue
        var phase := idle_time * 2.0 + float(i) * 0.7
        var breathe := 1.0 + sin(phase) * 0.018
        rect.scale = Vector2(breathe, breathe)
        rect.rotation = sin(phase * 0.65) * 0.008
    if enemy_art != null and is_instance_valid(enemy_art):
        enemy_art.pivot_offset = enemy_art.size * 0.5
        var ep := 1.0 + sin(idle_time * 1.7) * 0.014
        enemy_art.scale = Vector2(ep, ep)

func _play_attack(slot: int, damage: int) -> void:
    if slot < 0 or slot >= portraits.size(): return
    var rect: TextureRect = portraits[slot]
    if rect == null or not is_instance_valid(rect): return
    busy_slots[slot] = true
    var start_scale := Vector2.ONE
    rect.pivot_offset = rect.size * 0.5
    var tween := rect.create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(rect, "scale", Vector2(1.22, 1.22), 0.09)
    tween.parallel().tween_property(rect, "rotation", -0.07 if slot % 2 == 0 else 0.07, 0.09)
    tween.tween_property(rect, "scale", Vector2(0.96, 0.96), 0.07)
    tween.tween_property(rect, "scale", start_scale, 0.12)
    tween.parallel().tween_property(rect, "rotation", 0.0, 0.12)
    tween.finished.connect(func(): busy_slots.erase(slot))
    _slash_flash(slot)
    _damage_burst(damage, false)

func _slash_flash(slot: int) -> void:
    if stage_ref == null: return
    var slash := Label.new()
    slash.set_meta("battle_cinematic", true)
    slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    slash.text = "✦"
    slash.position = Vector2(290 + (slot % 3) * 18, 105 + int(slot / 3) * 10)
    slash.size = Vector2(120, 100)
    slash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    slash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    slash.add_theme_font_size_override("font_size", 72)
    slash.add_theme_color_override("font_color", Color("fff6c4"))
    stage_ref.add_child(slash)
    slash.pivot_offset = slash.size * 0.5
    slash.scale = Vector2(0.25, 0.25)
    slash.rotation = -0.5
    var tw := slash.create_tween()
    tw.set_parallel(true)
    tw.tween_property(slash, "scale", Vector2(1.5, 1.5), 0.13)
    tw.tween_property(slash, "rotation", 0.35, 0.13)
    tw.tween_property(slash, "modulate:a", 0.0, 0.24).set_delay(0.08)
    tw.finished.connect(slash.queue_free)

func _enemy_impact(damage: int) -> void:
    if stage_ref == null: return
    var flash := ColorRect.new()
    flash.set_meta("battle_cinematic", true)
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.position = Vector2(175, 25)
    flash.size = Vector2(350, 230)
    flash.color = Color(1.0, 0.92, 0.62, 0.0)
    stage_ref.add_child(flash)
    var tw := flash.create_tween()
    tw.tween_property(flash, "color:a", 0.42, 0.04)
    tw.tween_property(flash, "color:a", 0.0, 0.12)
    tw.finished.connect(flash.queue_free)
    _screen_shake(minf(12.0, 5.0 + float(damage) / 300.0))

func _damage_burst(damage: int, critical: bool) -> void:
    if stage_ref == null: return
    var label := Label.new()
    label.set_meta("battle_cinematic", true)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.text = str(damage)
    label.position = Vector2(235, 105)
    label.size = Vector2(230, 90)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 44 if critical else 36)
    label.add_theme_color_override("font_color", Color("fff287") if not critical else Color("ffb146"))
    stage_ref.add_child(label)
    label.pivot_offset = label.size * 0.5
    label.scale = Vector2(0.55, 0.55)
    var tw := label.create_tween()
    tw.tween_property(label, "scale", Vector2(1.18, 1.18), 0.08)
    tw.tween_property(label, "scale", Vector2.ONE, 0.08)
    tw.set_parallel(true)
    tw.tween_property(label, "position:y", 55.0, 0.55)
    tw.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.18)
    tw.finished.connect(label.queue_free)

func _play_brave_burst(slot: int, damage: int) -> void:
    if stage_ref == null: return
    if slot >= 0 and slot < portraits.size(): busy_slots[slot] = true
    var overlay := ColorRect.new()
    overlay.set_meta("battle_cinematic", true)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.01, 0.04, 0.12, 0.0)
    overlay.z_index = 80
    stage_ref.add_child(overlay)

    var ring := Label.new()
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ring.text = "✦   ◇   ✦   ◇   ✦"
    ring.position = Vector2(50, 220)
    ring.size = Vector2(600, 140)
    ring.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ring.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ring.add_theme_font_size_override("font_size", 48)
    ring.add_theme_color_override("font_color", Color("68d7ff"))
    overlay.add_child(ring)
    ring.pivot_offset = ring.size * 0.5
    ring.scale = Vector2(0.35, 0.35)

    var title := Label.new()
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title.text = "BRAVE BURST"
    title.position = Vector2(60, 345)
    title.size = Vector2(580, 90)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 46)
    title.add_theme_color_override("font_color", Color("dff8ff"))
    overlay.add_child(title)

    var name := Label.new()
    name.mouse_filter = Control.MOUSE_FILTER_IGNORE
    name.text = _bb_name(slot)
    name.position = Vector2(70, 430)
    name.size = Vector2(560, 60)
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.add_theme_font_size_override("font_size", 25)
    name.add_theme_color_override("font_color", Color("ffd96c"))
    overlay.add_child(name)

    if slot >= 0 and slot < portraits.size():
        var rect: TextureRect = portraits[slot]
        rect.pivot_offset = rect.size * 0.5
        var hero_tw := rect.create_tween()
        hero_tw.tween_property(rect, "scale", Vector2(1.34, 1.34), 0.14)
        hero_tw.tween_property(rect, "modulate", Color("bcecff"), 0.10)
        hero_tw.tween_property(rect, "scale", Vector2.ONE, 0.22).set_delay(0.12)
        hero_tw.parallel().tween_property(rect, "modulate", Color.WHITE, 0.22)
        hero_tw.finished.connect(func(): busy_slots.erase(slot))

    var tw := overlay.create_tween()
    tw.tween_property(overlay, "color:a", 0.86, 0.10)
    tw.parallel().tween_property(ring, "scale", Vector2(1.12, 1.12), 0.20)
    tw.parallel().tween_property(ring, "rotation", 0.18, 0.20)
    tw.tween_interval(0.18)
    tw.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.12)
    tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.12)
    tw.tween_interval(0.10)
    tw.tween_property(overlay, "color:a", 0.0, 0.18)
    tw.finished.connect(overlay.queue_free)
    _bb_projectiles()
    _damage_burst(damage, true)
    _screen_shake(16.0)

func _bb_projectiles() -> void:
    if stage_ref == null: return
    for i in range(8):
        var orb := Label.new()
        orb.set_meta("battle_cinematic", true)
        orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        orb.text = "✦"
        orb.position = Vector2(80 + (i % 4) * 155, 480 + int(i / 4) * 115)
        orb.size = Vector2(55, 55)
        orb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        orb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        orb.add_theme_font_size_override("font_size", 34)
        orb.add_theme_color_override("font_color", Color("62dcff") if i % 2 == 0 else Color("ffd966"))
        orb.z_index = 85
        stage_ref.add_child(orb)
        var tw := orb.create_tween()
        tw.set_parallel(true)
        tw.tween_property(orb, "position", Vector2(330 + randf_range(-55,55), 105 + randf_range(-25,35)), 0.32 + i * 0.018)
        tw.tween_property(orb, "scale", Vector2(1.7,1.7), 0.32)
        tw.tween_property(orb, "modulate:a", 0.0, 0.12).set_delay(0.26)
        tw.finished.connect(orb.queue_free)

func _bb_name(slot: int) -> String:
    var inventory = game.get("inventory")
    var squad = game.get("squad")
    var defs = game.get("unit_defs")
    if typeof(inventory) != TYPE_ARRAY or typeof(squad) != TYPE_ARRAY or typeof(defs) != TYPE_ARRAY: return "Brave Burst"
    if slot < 0 or slot >= squad.size(): return "Brave Burst"
    var idx := int(squad[slot])
    if idx < 0 or idx >= inventory.size(): return "Brave Burst"
    var def_id := int(inventory[idx].get("def_id", -1))
    if def_id < 0 or def_id >= defs.size(): return "Brave Burst"
    return str(defs[def_id].get("bb_name", "Brave Burst"))

func _wave_intro(number: int) -> void:
    if stage_ref == null: return
    var banner := Label.new()
    banner.set_meta("battle_cinematic", true)
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.text = "WAVE  %d" % number
    banner.position = Vector2(-420, 270)
    banner.size = Vector2(420, 80)
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    banner.add_theme_font_size_override("font_size", 38)
    banner.add_theme_color_override("font_color", Color("fff0b3"))
    banner.z_index = 70
    stage_ref.add_child(banner)
    var tw := banner.create_tween()
    tw.tween_property(banner, "position:x", 150.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_interval(0.30)
    tw.tween_property(banner, "position:x", 760.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.finished.connect(banner.queue_free)

func _screen_shake(amount: float) -> void:
    if stage_ref == null or not is_instance_valid(stage_ref): return
    var base := stage_ref.position
    var tw := stage_ref.create_tween()
    tw.tween_property(stage_ref, "position", base + Vector2(-amount, amount * 0.35), 0.035)
    tw.tween_property(stage_ref, "position", base + Vector2(amount * 0.8, -amount * 0.25), 0.035)
    tw.tween_property(stage_ref, "position", base + Vector2(-amount * 0.45, amount * 0.2), 0.035)
    tw.tween_property(stage_ref, "position", base, 0.055)

func _install_vignette() -> void:
    if stage_ref == null: return
    for child in stage_ref.get_children():
        if child.has_meta("battle_vignette"): return
    var top := ColorRect.new()
    top.set_meta("battle_vignette", true)
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.position = Vector2(0,0)
    top.size = Vector2(700,50)
    top.color = Color(0,0,0,0.34)
    top.z_index = 30
    stage_ref.add_child(top)
    var bottom := ColorRect.new()
    bottom.set_meta("battle_vignette", true)
    bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.position = Vector2(0,760)
    bottom.size = Vector2(700,65)
    bottom.color = Color(0,0,0,0.28)
    bottom.z_index = 30
    stage_ref.add_child(bottom)
