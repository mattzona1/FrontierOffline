extends Node

var game: Node
var timer := 0.0
var last_signature := ""
var last_enemy_hp := -1
var last_spark := 0

const ENEMY_ART := {
    "Ash Slime":"enemy_moerus.png", "Moerus":"enemy_moerus.png",
    "Boiling Wisp":"enemy_mizurus.png", "Mizurus":"enemy_mizurus.png",
    "Scoria Brute":"enemy_morirus.png", "Briar Pup":"enemy_morirus.png", "Morirus":"enemy_morirus.png",
    "Storm Idol":"enemy_rairus.png", "Spark Mite":"enemy_rairus.png", "Rairus":"enemy_rairus.png",
    "Cinder Imp":"enemy_imp.png", "Gloom Bat":"enemy_imp.png", "Shade Monk":"enemy_imp.png", "Imp":"enemy_imp.png",
    "Coalback Hound":"enemy_caitsith.png", "Cloud Raptor":"enemy_caitsith.png", "Moonfang":"enemy_caitsith.png", "Cait Sith":"enemy_caitsith.png"
}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
    timer += delta
    if timer < 0.10: return
    timer = 0.0
    if game == null or not is_instance_valid(game): return
    var page := _page()
    if page != "BATTLE" and page != "TRAINING":
        last_signature = ""
        last_enemy_hp = -1
        return
    var hp := int(game.get("enemy_hp"))
    var enemy := _enemy()
    var sig := "%s|%s|%d|%d" % [page, enemy.get("name",""), hp, int(game.get("current_wave"))]
    if sig != last_signature:
        var old_hp := last_enemy_hp
        last_signature = sig
        call_deferred("_decorate", old_hp)
    last_enemy_hp = hp

func _page() -> String:
    var label = game.get("page_title")
    return str(label.text) if label != null and is_instance_valid(label) else ""

func _enemy() -> Dictionary:
    if game.has_method("_enemy"):
        var value = game.call("_enemy")
        if typeof(value) == TYPE_DICTIONARY: return value
    return {"name":"Enemy","element":"Neutral"}

func _decorate(previous_hp: int) -> void:
    await get_tree().process_frame
    var stage = game.get("stage")
    if stage == null or not is_instance_valid(stage): return
    _remove_old(stage)
    _add_scene(stage)
    _style_battle_controls(stage)
    var art := _add_enemy_art(stage)
    _add_enemy_gauge(stage)
    if previous_hp >= 0 and previous_hp > int(game.get("enemy_hp")):
        _hit_feedback(stage, previous_hp - int(game.get("enemy_hp")), art)
    _special_feedback(stage)

func _remove_old(stage: Node) -> void:
    for child in stage.get_children():
        if child.has_meta("battle_feel"):
            child.queue_free()

func _add_scene(stage: Control) -> void:
    var scene := Control.new()
    scene.set_meta("battle_feel", true)
    scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    stage.add_child(scene)
    stage.move_child(scene, 0)

    var sky := ColorRect.new()
    sky.position = Vector2(0,0); sky.size = Vector2(700,255); sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var ground := ColorRect.new()
    ground.position = Vector2(0,175); ground.size = Vector2(700,650); ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scene.add_child(sky); scene.add_child(ground)

    var area := _area_name()
    if area == "Mossvale":
        sky.color = Color("173b46"); ground.color = Color("183a28")
        _poly(scene, PackedVector2Array([Vector2(0,180),Vector2(120,75),Vector2(240,180)]), Color("234d38"))
        _poly(scene, PackedVector2Array([Vector2(150,180),Vector2(330,55),Vector2(500,180)]), Color("285942"))
        _poly(scene, PackedVector2Array([Vector2(410,180),Vector2(580,90),Vector2(700,180)]), Color("214934"))
        for x in [45,110,560,625]:
            var trunk := ColorRect.new(); trunk.position=Vector2(x,135); trunk.size=Vector2(18,95); trunk.color=Color("513c29"); trunk.mouse_filter=Control.MOUSE_FILTER_IGNORE; scene.add_child(trunk)
            var crown := Polygon2D.new(); crown.polygon=PackedVector2Array([Vector2(x-35,155),Vector2(x+9,75),Vector2(x+55,155)]); crown.color=Color("2e7045"); scene.add_child(crown)
    elif area == "Training":
        sky.color = Color("213349"); ground.color = Color("313743")
        for y in [185,230]:
            var line := ColorRect.new(); line.position=Vector2(0,y); line.size=Vector2(700,3); line.color=Color("73869d"); line.mouse_filter=Control.MOUSE_FILTER_IGNORE; scene.add_child(line)
        for x in range(0,701,90):
            var mark := ColorRect.new(); mark.position=Vector2(x,185); mark.size=Vector2(3,120); mark.color=Color("52667e"); mark.mouse_filter=Control.MOUSE_FILTER_IGNORE; scene.add_child(mark)
    else:
        sky.color = Color("4a2630"); ground.color = Color("42241f")
        _poly(scene, PackedVector2Array([Vector2(0,180),Vector2(135,65),Vector2(260,180)]), Color("67392e"))
        _poly(scene, PackedVector2Array([Vector2(190,180),Vector2(390,35),Vector2(570,180)]), Color("753c2e"))
        _poly(scene, PackedVector2Array([Vector2(470,180),Vector2(620,80),Vector2(700,180)]), Color("5c3029"))
        var lava := ColorRect.new(); lava.position=Vector2(0,205); lava.size=Vector2(700,10); lava.color=Color("d66437"); lava.mouse_filter=Control.MOUSE_FILTER_IGNORE; scene.add_child(lava)

    var shade := ColorRect.new()
    shade.position=Vector2(0,0); shade.size=Vector2(700,825); shade.color=Color(0,0,0,0.18); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; scene.add_child(shade)

func _poly(parent: Node, points: PackedVector2Array, color: Color) -> void:
    var p := Polygon2D.new(); p.polygon = points; p.color = color; parent.add_child(p)

func _area_name() -> String:
    if bool(game.get("training_mode")): return "Training"
    var index := int(game.get("current_quest"))
    var quests = game.get("quests")
    if typeof(quests) == TYPE_ARRAY and index >= 0 and index < quests.size(): return str(quests[index].get("area","Ashen Coast"))
    return "Ashen Coast"

func _add_enemy_art(stage: Control) -> TextureRect:
    var enemy := _enemy()
    var filename := str(ENEMY_ART.get(str(enemy.get("name","")), _element_enemy(str(enemy.get("element","Neutral")))))
    var texture := _load_cache(filename)
    var art := TextureRect.new()
    art.set_meta("battle_feel", true)
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.position = Vector2(225, 8)
    art.size = Vector2(250, 205)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.texture = texture
    stage.add_child(art)
    return art

func _element_enemy(element: String) -> String:
    match element:
        "Fire": return "enemy_moerus.png"
        "Water": return "enemy_mizurus.png"
        "Earth": return "enemy_morirus.png"
        "Thunder": return "enemy_rairus.png"
        "Dark": return "enemy_imp.png"
        _: return "enemy_caitsith.png"

func _load_cache(filename: String) -> Texture2D:
    var path := "user://bf_assets/%s" % filename
    if FileAccess.file_exists(path):
        var image := Image.new()
        if image.load(ProjectSettings.globalize_path(path)) == OK: return ImageTexture.create_from_image(image)
    var grad := GradientTexture2D.new(); var g:=Gradient.new(); g.colors=PackedColorArray([Color("6a7484"),Color("17202c")]); grad.gradient=g; grad.width=256; grad.height=256; return grad

func _add_enemy_gauge(stage: Control) -> void:
    var hp := int(game.get("enemy_hp")); var max_hp := maxi(1,int(game.get("enemy_max_hp")))
    var bar := ProgressBar.new(); bar.set_meta("battle_feel",true); bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    bar.position=Vector2(120,205); bar.size=Vector2(460,22); bar.max_value=max_hp; bar.value=hp; bar.show_percentage=false
    stage.add_child(bar)
    var name := Label.new(); name.set_meta("battle_feel",true); name.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var enemy:=_enemy(); name.text="%s   •   %s"%[enemy.get("name","Enemy"),enemy.get("element","Neutral")]; name.position=Vector2(100,228); name.size=Vector2(500,30); name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; name.add_theme_font_size_override("font_size",16); name.add_theme_color_override("font_color",Color("fff0c2")); stage.add_child(name)

func _style_battle_controls(stage: Node) -> void:
    var buttons:Array=[]; _collect_buttons(stage,buttons)
    for b in buttons:
        if str(b.text).begins_with("BB "):
            var style:=StyleBoxFlat.new(); style.bg_color=Color("204f72"); style.border_width_top=2; style.border_color=Color("5db7e8"); style.corner_radius_top_left=8;style.corner_radius_top_right=8;style.corner_radius_bottom_left=8;style.corner_radius_bottom_right=8; b.add_theme_stylebox_override("normal",style)
        elif str(b.text).contains("HP "):
            var style:=StyleBoxFlat.new();style.bg_color=Color("17263b");style.border_width_left=2;style.border_width_right=2;style.border_color=Color("536f91");style.corner_radius_top_left=8;style.corner_radius_top_right=8;style.corner_radius_bottom_left=8;style.corner_radius_bottom_right=8;b.add_theme_stylebox_override("normal",style)

func _collect_buttons(node:Node,out:Array)->void:
    if node is Button: out.append(node)
    for child in node.get_children(): _collect_buttons(child,out)

func _hit_feedback(stage: Control, damage: int, art: TextureRect) -> void:
    var label:=Label.new();label.set_meta("battle_feel",true);label.text=str(damage);label.position=Vector2(255,105);label.size=Vector2(190,60);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",34);label.add_theme_color_override("font_color",Color("fff19b"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(label)
    var tween:=stage.create_tween();tween.set_parallel(true);tween.tween_property(label,"position:y",65.0,0.45);tween.tween_property(label,"modulate:a",0.0,0.55)
    if art != null:
        var base:=art.position;var shake:=stage.create_tween();shake.tween_property(art,"position:x",base.x-12,0.045);shake.tween_property(art,"position:x",base.x+10,0.045);shake.tween_property(art,"position:x",base.x,0.055)
    var spark := int(game.get("spark_chain"))
    if spark > 0:
        var s:=Label.new();s.set_meta("battle_feel",true);s.text="SPARK!  x%d"%(spark+1);s.position=Vector2(235,160);s.size=Vector2(230,42);s.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;s.add_theme_font_size_override("font_size",25);s.add_theme_color_override("font_color",Color("ffe06a"));s.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(s)

func _special_feedback(stage: Control) -> void:
    var text:=_collect_text(stage)
    if text.contains("✦"):
        var bb:=Label.new();bb.set_meta("battle_feel",true);bb.text="BRAVE BURST!";bb.position=Vector2(105,265);bb.size=Vector2(490,65);bb.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;bb.add_theme_font_size_override("font_size",36);bb.add_theme_color_override("font_color",Color("71d7ff"));bb.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.add_child(bb)
        var tw:=stage.create_tween();tw.tween_property(bb,"scale",Vector2(1.12,1.12),0.12);tw.tween_property(bb,"scale",Vector2.ONE,0.16)

func _collect_text(node:Node)->String:
    var out:=""
    if node is Label or node is Button: out += " " + str(node.text)
    for child in node.get_children(): out += _collect_text(child)
    return out
