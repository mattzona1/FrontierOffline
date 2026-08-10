extends Node

var game: Node
var overlay: Control
var last_page := ""
var selected_unit := -1

const GOLD := Color("e8bd56")
const GOLD_DARK := Color("6f4c15")
const STONE := Color("1b2c3c")
const PANEL := Color("17130d")
const TEXT := Color("f7f2e6")

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_tick_now")

func _process(_delta: float) -> void:
    if game == null or not is_instance_valid(game): return
    var page := _page()
    if page != last_page:
        last_page = page
        call_deferred("_refresh")

func _tick_now() -> void:
    await get_tree().process_frame
    if game != null and is_instance_valid(game):
        last_page = _page()
        _refresh()

func _page() -> String:
    var p = game.get("page_title")
    return str(p.text) if p != null and is_instance_valid(p) else ""

func _refresh() -> void:
    await get_tree().process_frame
    _remove_overlay()
    if _page() == "GRAND GAIA":
        _build_home()
    elif _page() in ["Vargas","Selena","Lance","Eze","Atro","Magress","Zelgal","Zephu","Lario","Weiss","Luna","Mifune"]:
        _build_unit_detail(int(game.get("selected")))

func _remove_overlay() -> void:
    if overlay != null and is_instance_valid(overlay): overlay.queue_free()
    overlay = null

func _new_overlay() -> Control:
    var o := Control.new()
    o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    o.z_index = 300
    o.mouse_filter = Control.MOUSE_FILTER_STOP
    game.add_child(o)
    overlay = o
    return o

func _panel(parent: Node, pos: Vector2, size: Vector2, color: Color = PANEL, radius := 12) -> PanelContainer:
    var p := PanelContainer.new(); p.position=pos; p.size=size
    var s := StyleBoxFlat.new(); s.bg_color=color; s.border_width_left=3;s.border_width_right=3;s.border_width_top=3;s.border_width_bottom=3;s.border_color=GOLD_DARK
    s.corner_radius_top_left=radius;s.corner_radius_top_right=radius;s.corner_radius_bottom_left=radius;s.corner_radius_bottom_right=radius
    p.add_theme_stylebox_override("panel",s); parent.add_child(p); return p

func _label(parent: Node, text: String, pos: Vector2, size: Vector2, fs := 18, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l:=Label.new();l.text=text;l.position=pos;l.size=size;l.add_theme_font_size_override("font_size",fs);l.add_theme_color_override("font_color",color);l.horizontal_alignment=align;l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l

func _button(parent: Node, text: String, pos: Vector2, size: Vector2, cb: Callable, fs := 17) -> Button:
    var b:=Button.new();b.text=text;b.position=pos;b.size=size;b.add_theme_font_size_override("font_size",fs)
    var n:=StyleBoxFlat.new();n.bg_color=Color("3b2a15");n.border_width_left=3;n.border_width_right=3;n.border_width_top=3;n.border_width_bottom=3;n.border_color=GOLD;n.corner_radius_top_left=10;n.corner_radius_top_right=10;n.corner_radius_bottom_left=10;n.corner_radius_bottom_right=10;b.add_theme_stylebox_override("normal",n)
    var h:=n.duplicate();h.bg_color=Color("62421b");b.add_theme_stylebox_override("hover",h);b.add_theme_stylebox_override("pressed",h);b.pressed.connect(cb);parent.add_child(b);return b

func _build_home() -> void:
    var o:=_new_overlay()
    var bg:=ColorRect.new();bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.color=Color("14110c");bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;o.add_child(bg)
    # Dense original-style status header
    _panel(o,Vector2(0,0),Vector2(720,205),STONE,0)
    _label(o,"SUMMONER",Vector2(24,12),Vector2(240,34),14,Color("b9c8d8"))
    _label(o,"Frontier",Vector2(24,40),Vector2(260,38),25,TEXT)
    _label(o,"Lv  %d"%int(game.get("rank")),Vector2(24,82),Vector2(130,34),18)
    _label(o,"EXP",Vector2(24,120),Vector2(60,28),14,Color("ffbf58"))
    var exp:=ProgressBar.new();exp.position=Vector2(82,123);exp.size=Vector2(210,22);exp.max_value=100;exp.value=int(game.get("rank_xp"))%100;exp.show_percentage=false;o.add_child(exp)
    _label(o,"Energy",Vector2(24,151),Vector2(75,28),14,Color("8af087"));var en:=ProgressBar.new();en.position=Vector2(98,154);en.size=Vector2(194,22);en.max_value=30;en.value=30;en.show_percentage=false;o.add_child(en)
    _label(o,"BRAVE FRONTIER",Vector2(278,22),Vector2(260,62),30,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
    _label(o,"OFFLINE",Vector2(330,79),Vector2(160,28),14,Color("d6b96f"),HORIZONTAL_ALIGNMENT_CENTER)
    _label(o,"💎  %d"%int(game.get("gems")),Vector2(545,34),Vector2(155,34),19)
    _label(o,"●  %d"%int(game.get("gold")),Vector2(545,76),Vector2(155,34),19,Color("ffd77b"))
    _label(o,"ARENA   ● ● ●",Vector2(530,125),Vector2(170,30),15,Color("dcb975"))

    # Feature carousel area, deliberately horizontal like the reference screen.
    var car_bg:=ColorRect.new();car_bg.position=Vector2(0,205);car_bg.size=Vector2(720,655);car_bg.color=Color("241d11");o.add_child(car_bg)
    var scroll:=ScrollContainer.new();scroll.position=Vector2(0,225);scroll.size=Vector2(720,520);scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;o.add_child(scroll)
    var row:=HBoxContainer.new();row.custom_minimum_size=Vector2(1440,500);row.add_theme_constant_override("separation",14);scroll.add_child(row)
    row.add_child(_feature_card("ARENA","PVP BATTLES",Color("264b72"),func(): _toast("Arena will be restored after the core quest loop.")))
    row.add_child(_feature_card("QUEST","ENTER GRAND GAIA",Color("6b3218"),func(): game.call("_quests")))
    row.add_child(_feature_card("VORTEX","SPECIAL DUNGEONS",Color("4b205f"),func(): _toast("Vortex is coming after Quest 1 is locked in.")))
    row.add_child(_feature_card("TOWN","UPGRADES & CRAFTING",Color("3d5a2d"),func(): game.call("_more")))
    row.add_child(_feature_card("SUMMON","OPEN THE GATE",Color("1f5075"),func(): game.call("_summon")))
    row.add_child(_feature_card("SHOP","ITEMS & GEMS",Color("6a4a1e"),func(): _toast("Shop will be one of the few scrolling screens.")))
    _label(o,"Swipe left / right to select a feature",Vector2(110,760),Vector2(500,38),15,Color("cbb98e"),HORIZONTAL_ALIGNMENT_CENTER)

    var promo:=_panel(o,Vector2(18,806),Vector2(684,168),Color("241523"),8)
    _label(promo,"FEATURED SUMMON",Vector2(18,8),Vector2(640,30),15,Color("c894ff"),HORIZONTAL_ALIGNMENT_CENTER)
    var names=[6,7,8,9,10,11]
    for i in range(6):
        var tex:=TextureRect.new();tex.position=Vector2(14+i*108,38);tex.size=Vector2(100,112);tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;tex.texture=_unit_texture(names[i]);tex.mouse_filter=Control.MOUSE_FILTER_IGNORE;promo.add_child(tex)

    _build_bottom_nav(o)

func _feature_card(title:String,sub:String,color:Color,cb:Callable)->Control:
    var p:=PanelContainer.new();p.custom_minimum_size=Vector2(300,470)
    var s:=StyleBoxFlat.new();s.bg_color=color;s.border_width_left=4;s.border_width_right=4;s.border_width_top=4;s.border_width_bottom=4;s.border_color=GOLD;s.corner_radius_top_left=18;s.corner_radius_top_right=18;s.corner_radius_bottom_left=18;s.corner_radius_bottom_right=18;p.add_theme_stylebox_override("panel",s)
    var b:=Button.new();b.flat=true;b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);b.pressed.connect(cb);p.add_child(b)
    var icon:=Label.new();icon.text="✦" if title!="QUEST" else "🚪";icon.position=Vector2(30,70);icon.size=Vector2(240,180);icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;icon.add_theme_font_size_override("font_size",100);icon.add_theme_color_override("font_color",Color(1,0.82,0.25,0.85));icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;p.add_child(icon)
    _label(p,title,Vector2(10,260),Vector2(280,92),48,Color("fff1be"),HORIZONTAL_ALIGNMENT_CENTER)
    _label(p,sub,Vector2(14,352),Vector2(272,44),15,Color("e9dec4"),HORIZONTAL_ALIGNMENT_CENTER)
    return p

func _build_bottom_nav(o:Control)->void:
    var bar:=_panel(o,Vector2(0,1000),Vector2(720,280),Color("101722"),0)
    _label(bar,"Select a Menu.",Vector2(18,4),Vector2(684,34),15,Color("d4dbe4"))
    var items=[
        ["HOME",func():game.call("_home")],["UNIT",func():game.call("_units")],["TOWN",func():game.call("_more")],
        ["SHOP",func():_toast("Shop coming soon")],["SUMMON",func():game.call("_summon")],["SOCIAL",func():_toast("Social is disabled for the offline build")]
    ]
    for i in range(items.size()):
        _button(bar,str(items[i][0]),Vector2(7+i*118,50),Vector2(112,118),items[i][1],15)

func _build_unit_detail(index:int)->void:
    if index<0:return
    var inv=game.get("inventory");var defs=game.get("unit_defs")
    if typeof(inv)!=TYPE_ARRAY or index>=inv.size():return
    var unit:Dictionary=inv[index];var id:=int(unit.get("def_id",0));var def:Dictionary=defs[id]
    var o:=_new_overlay();var bg:=ColorRect.new();bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.color=Color("1a160d");o.add_child(bg)
    _panel(o,Vector2(0,0),Vector2(720,118),STONE,0)
    _button(o,"Back",Vector2(14,18),Vector2(110,74),func():game.call("_units"),19)
    _label(o,"Unit No.%03d"%(id+1),Vector2(145,12),Vector2(280,34),18)
    _label(o,"%s  %s"%[_stars(int(def.get("rarity",3))),str(def.get("title",def.get("name","Unit")))],Vector2(145,45),Vector2(520,52),23,Color("fff0b5"))
    var type_panel:=_panel(o,Vector2(18,145),Vector2(250,155),Color("211a10"),8)
    _label(type_panel,"TYPE   %s"%_type_name(unit),Vector2(18,12),Vector2(220,42),20,Color("ffc450"))
    _label(type_panel,"Lv. %d / 60"%int(unit.get("level",1)),Vector2(18,58),Vector2(220,34),22)
    _label(type_panel,"Next Lv. %d"%maxi(0,1000-int(unit.get("xp",0))),Vector2(18,98),Vector2(220,34),18)
    var art:=TextureRect.new();art.position=Vector2(245,112);art.size=Vector2(455,610);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.texture=_unit_texture(id);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;o.add_child(art)
    var stats:=_panel(o,Vector2(18,325),Vector2(245,350),Color("16120c"),8)
    _stat(stats,"HP",int(game.call("_unit_hp",unit)),18)
    _stat(stats,"ATK",int(game.call("_unit_atk",unit)),82)
    _stat(stats,"DEF",int(float(game.call("_unit_hp",unit))*0.23),146)
    _stat(stats,"REC",int(float(game.call("_unit_hp",unit))*0.14),210)
    _label(stats,"COST  %d"%(6+int(def.get("rarity",3))*2),Vector2(18,280),Vector2(205,44),19,Color("ffd679"),HORIZONTAL_ALIGNMENT_RIGHT)
    var leader:=_panel(o,Vector2(18,705),Vector2(684,142),Color("0d1118"),6)
    _label(leader,"Leader Skill",Vector2(12,6),Vector2(180,36),18,Color("ffba4b"));_label(leader,str(def.get("leader","")),Vector2(18,46),Vector2(648,82),16,TEXT)
    var bb:=_panel(o,Vector2(18,862),Vector2(684,170),Color("0b1421"),6)
    _label(bb,"Brave Burst",Vector2(12,6),Vector2(180,36),18,Color("62c4ff"));_label(bb,str(def.get("bb_name","Brave Burst"))+"   Lv.%d"%(int(unit.get("bb",0))+1),Vector2(190,6),Vector2(470,36),18,Color("ffd679"))
    _label(bb,"%d combo %s elemental attack."%[int(def.get("hits",3)),str(def.get("element","Neutral"))],Vector2(18,50),Vector2(648,80),16,TEXT)
    _button(o,"TRAIN",Vector2(18,1055),Vector2(325,75),func():game.call("_train",index),18);_button(o,"EVOLVE",Vector2(377,1055),Vector2(325,75),func():game.call("_evolve",index),18)

func _stat(parent:Node,name:String,value:int,y:int)->void:
    _label(parent,name,Vector2(16,y),Vector2(80,46),19,Color("d9d0bb"));_label(parent,str(value),Vector2(95,y),Vector2(125,46),28,TEXT,HORIZONTAL_ALIGNMENT_RIGHT)

func _stars(n:int)->String:
    var out:="";for i in range(clampi(n,1,6)):out+="★";return out
func _type_name(_unit:Dictionary)->String:return "Breaker"
func _toast(text:String)->void:
    var t=game.get("toast");if t!=null and is_instance_valid(t):t.text=text
func _unit_texture(id:int)->Texture2D:
    var defs=game.get("unit_defs");if typeof(defs)!=TYPE_ARRAY or id<0 or id>=defs.size():return null
    var filename:=str(defs[id].get("cache",""));if filename=="":return null
    var path:="user://bf_assets/%s"%filename
    if not FileAccess.file_exists(path):path="res://assets/bf/%s"%filename
    if not FileAccess.file_exists(path):return null
    var img:=Image.new();if img.load(ProjectSettings.globalize_path(path))!=OK:return null
    return ImageTexture.create_from_image(img)
