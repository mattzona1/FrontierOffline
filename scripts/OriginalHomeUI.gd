extends Node

var game: Node
var overlay: Control
var last_page := ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_refresh")

func _process(_delta: float) -> void:
    if game == null or not is_instance_valid(game): return
    var page := _page()
    if page != last_page:
        last_page = page
        call_deferred("_refresh")

func _page() -> String:
    var p=game.get("page_title")
    return str(p.text) if p!=null and is_instance_valid(p) else ""

func _refresh() -> void:
    await get_tree().process_frame
    if overlay!=null and is_instance_valid(overlay): overlay.queue_free()
    overlay=null
    if _page()=="GRAND GAIA": _home()

func _home() -> void:
    overlay=Control.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.z_index=500;overlay.mouse_filter=Control.MOUSE_FILTER_PASS;game.add_child(overlay)
    _texture("menu_base.jpg",Vector2(0,0),Vector2(720,1280),overlay)
    _texture("menu_header.png",Vector2(0,0),Vector2(720,205),overlay)
    _text("Frontier",Vector2(20,18),Vector2(210,34),22)
    _text("Lv %d"%int(game.get("rank")),Vector2(20,55),Vector2(120,32),17)
    _text("EXP",Vector2(20,93),Vector2(70,28),13,Color("ffb551"))
    var xp:=ProgressBar.new();xp.position=Vector2(78,96);xp.size=Vector2(205,20);xp.max_value=100;xp.value=int(game.get("rank_xp"))%100;xp.show_percentage=false;xp.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(xp)
    _text("Energy",Vector2(20,125),Vector2(70,28),13,Color("8eff80"))
    var en:=ProgressBar.new();en.position=Vector2(84,128);en.size=Vector2(199,20);en.max_value=30;en.value=30;en.show_percentage=false;en.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(en)
    _text("💎 %d"%int(game.get("gems")),Vector2(540,40),Vector2(155,32),18)
    _text("● %d"%int(game.get("gold")),Vector2(540,78),Vector2(155,32),18,Color("ffd77b"))

    var scroll:=ScrollContainer.new();scroll.position=Vector2(0,218);scroll.size=Vector2(720,535);scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.mouse_filter=Control.MOUSE_FILTER_PASS;overlay.add_child(scroll)
    var row:=HBoxContainer.new();row.custom_minimum_size=Vector2(1040,520);row.add_theme_constant_override("separation",12);scroll.add_child(row)
    row.add_child(_launch("launch_arena.png","ARENA",func():_toast("Arena will follow the core quest reconstruction.")))
    row.add_child(_launch("launch_quest.png","QUEST",func():game.call("_quests")))
    row.add_child(_launch("launch_gate.png","VORTEX",func():_toast("Vortex will return after Quest 1 is locked in.")))

    var banner:=TextureButton.new();banner.position=Vector2(25,770);banner.size=Vector2(670,170);banner.texture_normal=_tex("menu_banner.png");banner.ignore_texture_size=true;banner.stretch_mode=TextureButton.STRETCH_SCALE;banner.pressed.connect(func():game.call("_summon"));overlay.add_child(banner)

    _texture("menu_footer_base.png",Vector2(0,1000),Vector2(720,280),overlay)
    var icons=[
        ["menu_home.png",func():game.call("_home")],
        ["menu_unit.png",func():game.call("_units")],
        ["menu_town.png",func():game.call("_more")],
        ["menu_shop.png",func():_toast("Shop is coming next.")],
        ["menu_summon.png",func():game.call("_summon")],
        ["menu_social.png",func():_toast("Social is disabled in the offline build.")]
    ]
    for i in range(icons.size()):
        var b:=TextureButton.new();b.position=Vector2(4+i*119,1050);b.size=Vector2(116,145);b.texture_normal=_tex(str(icons[i][0]));b.ignore_texture_size=true;b.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED;b.pressed.connect(icons[i][1]);overlay.add_child(b)

func _launch(file:String,label:String,callback:Callable)->Control:
    var holder:=Control.new();holder.custom_minimum_size=Vector2(330,500)
    var b:=TextureButton.new();b.position=Vector2(5,20);b.size=Vector2(320,410);b.texture_normal=_tex(file);b.ignore_texture_size=true;b.stretch_mode=TextureButton.STRETCH_KEEP_ASPECT_CENTERED;b.pressed.connect(callback);holder.add_child(b)
    var l:=Label.new();l.text=label;l.position=Vector2(10,425);l.size=Vector2(310,55);l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.add_theme_font_size_override("font_size",30);l.add_theme_color_override("font_color",Color("fff0b0"));l.mouse_filter=Control.MOUSE_FILTER_IGNORE;holder.add_child(l)
    return holder

func _texture(file:String,pos:Vector2,size:Vector2,parent:Node)->void:
    var t:=TextureRect.new();t.position=pos;t.size=size;t.texture=_tex(file);t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_SCALE;t.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(t)

func _tex(file:String)->Texture2D:
    var path="res://assets/bf/original/%s"%file
    return load(path) if ResourceLoader.exists(path) else null

func _text(text:String,pos:Vector2,size:Vector2,fs:int,color:=Color.WHITE)->void:
    var l:=Label.new();l.text=text;l.position=pos;l.size=size;l.add_theme_font_size_override("font_size",fs);l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(l)

func _toast(text:String)->void:
    var t=game.get("toast")
    if t!=null and is_instance_valid(t):t.text=text
