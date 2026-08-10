extends Control

const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("a9bbd3")
const PANEL := Color("101a2c")
const OFFICIAL_ROOT := "https://www.bravefrontier.jp"
var game: Node
var panel: PanelContainer
var status: Label
var gallery_grid: GridContainer
var request: HTTPRequest
var pending: Array = []
var active_item: Dictionary = {}
var active_phase := ""
var starters := [
{"name":"Vargas","element":"Fire","no":1,"cache":"vargas_official.png"},{"name":"Selena","element":"Water","no":5,"cache":"selena_official.png"},{"name":"Lance","element":"Earth","no":9,"cache":"lance_official.png"},{"name":"Eze","element":"Thunder","no":13,"cache":"eze_official.png"},{"name":"Atro","element":"Light","no":17,"cache":"atro_official.png"},{"name":"Magress","element":"Dark","no":21,"cache":"magress_official.png"}]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    request = HTTPRequest.new(); request.timeout = 20.0; add_child(request)
    request.request_completed.connect(_on_request_completed)
    _build_button()

func _build_button() -> void:
    var b := Button.new(); b.text = "ORIGINAL ART"; b.position = Vector2(18,194); b.size = Vector2(260,58)
    b.add_theme_font_size_override("font_size",17); b.pressed.connect(_open_gallery); add_child(b)

func _open_gallery() -> void:
    if panel != null and is_instance_valid(panel): panel.queue_free(); panel=null; return
    # Expand the helper only while the gallery is intentionally open.
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    panel = PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left=14; panel.offset_right=-14; panel.offset_top=55; panel.offset_bottom=-20; panel.z_index=100
    var style:=StyleBoxFlat.new(); style.bg_color=PANEL; style.corner_radius_top_left=18; style.corner_radius_top_right=18; style.corner_radius_bottom_left=18; style.corner_radius_bottom_right=18
    panel.add_theme_stylebox_override("panel",style); add_child(panel)
    var root:=VBoxContainer.new(); root.add_theme_constant_override("separation",10); panel.add_child(root)
    var title:=Label.new(); title.text="ORIGINAL BRAVE FRONTIER ART"; title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",22); title.add_theme_color_override("font_color",GOLD); root.add_child(title)
    status=Label.new(); status.text="Starter artwork cache"; status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; status.add_theme_color_override("font_color",MUTED); root.add_child(status)
    var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(scroll)
    gallery_grid=GridContainer.new(); gallery_grid.columns=2; gallery_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; gallery_grid.add_theme_constant_override("h_separation",8); gallery_grid.add_theme_constant_override("v_separation",8); scroll.add_child(gallery_grid)
    var controls:=HBoxContainer.new(); var refresh:=Button.new(); refresh.text="REFRESH"; refresh.size_flags_horizontal=Control.SIZE_EXPAND_FILL; refresh.custom_minimum_size=Vector2(0,60); refresh.pressed.connect(_refresh_assets); controls.add_child(refresh)
    var close:=Button.new(); close.text="CLOSE"; close.size_flags_horizontal=Control.SIZE_EXPAND_FILL; close.custom_minimum_size=Vector2(0,60); close.pressed.connect(_close_gallery); controls.add_child(close); root.add_child(controls)
    _render_gallery(); _queue_missing()

func _close_gallery() -> void:
    if panel!=null and is_instance_valid(panel): panel.queue_free()
    panel=null
    set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    position=Vector2.ZERO; size=Vector2(300,270); mouse_filter=Control.MOUSE_FILTER_PASS

func _cache_path(filename:String)->String:
    var dir:="user://bf_assets"; DirAccess.make_dir_absolute(ProjectSettings.globalize_path(dir)); return "%s/%s"%[dir,filename]
func _render_gallery()->void:
    if gallery_grid==null:return
    for c in gallery_grid.get_children():c.queue_free()
    for item in starters:gallery_grid.add_child(_make_card(item))
func _make_card(item:Dictionary)->Control:
    var card:=VBoxContainer.new(); card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var tex:=TextureRect.new(); tex.custom_minimum_size=Vector2(0,210); tex.expand_mode=TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL; tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var path:=_cache_path(str(item["cache"])); if FileAccess.file_exists(path):
        var image:=Image.new(); if image.load(ProjectSettings.globalize_path(path))==OK:tex.texture=ImageTexture.create_from_image(image)
    if tex.texture==null:
        var p:=GradientTexture2D.new(); var g:=Gradient.new(); g.colors=PackedColorArray([_element_color(str(item["element"])),Color("121827")]); p.gradient=g;p.width=256;p.height=256;tex.texture=p
    card.add_child(tex); var name:=Label.new(); name.text="%s • %s"%[item["name"],item["element"]]; name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; name.add_theme_font_size_override("font_size",17); card.add_child(name); return card
func _refresh_assets()->void: pending=starters.duplicate(true); status.text="Refreshing starter art..."; _download_next()
func _queue_missing()->void:
    pending.clear(); for item in starters:
        if not FileAccess.file_exists(_cache_path(str(item["cache"]))):pending.append(item)
    if pending.is_empty(): status.text="All six starter artworks cached offline."; return
    status.text="Fetching %d missing artwork(s)..."%pending.size(); _download_next()
func _download_next()->void:
    if pending.is_empty(): status.text="Starter art cache ready."; _render_gallery(); return
    if request.get_http_client_status()!=HTTPClient.STATUS_DISCONNECTED:return
    active_item=pending.pop_front();active_phase="page";var err:=request.request("%s/library/bf1/bf1_full.php?no=%d"%[OFFICIAL_ROOT,int(active_item["no"])],["User-Agent: Mozilla/5.0 FrontierOffline/0.2"]);if err!=OK:_asset_failed("Could not open page")
func _on_request_completed(result:int,response_code:int,headers:PackedStringArray,body:PackedByteArray)->void:
    if result!=HTTPRequest.RESULT_SUCCESS or response_code<200 or response_code>=400:_asset_failed("Server returned %d"%response_code);return
    if active_phase=="page":
        var image_url:=_extract_official_image_url(body.get_string_from_utf8());if image_url=="":_asset_failed("Could not locate image");return
        active_phase="image";status.text="Downloading %s..."%active_item["name"];var err:=request.request(image_url,["User-Agent: Mozilla/5.0 FrontierOffline/0.2","Referer: %s/"%OFFICIAL_ROOT]);if err!=OK:_asset_failed("Could not request image");return
    if active_phase=="image":
        var image:=Image.new();var ok:=image.load_png_from_buffer(body);if ok!=OK:ok=image.load_jpg_from_buffer(body);if ok!=OK:ok=image.load_webp_from_buffer(body)
        if ok!=OK:_asset_failed("Unsupported image");return
        if image.save_png(ProjectSettings.globalize_path(_cache_path(str(active_item["cache"]))))!=OK:_asset_failed("Could not cache image");return
        status.text="Cached %s"%active_item["name"];_render_gallery();call_deferred("_download_next")
func _extract_official_image_url(html:String)->String:
    var re:=RegEx.new();re.compile("(?:src|href)=[\\\"']([^\\\"']+\\.(?:png|jpg|jpeg|webp)(?:\\?[^\\\"']*)?)[\\\"']");var fallback:=""
    for m in re.search_all(html):
        var candidate:=m.get_string(1).replace("&amp;","&");var low:=candidate.to_lower();if low.contains("logo") or low.contains("icon") or low.contains("btn") or low.contains("common"):continue
        var absolute:=_absolute_url(candidate);if fallback=="":fallback=absolute;if low.contains("full") or low.contains("unit") or low.contains("chara") or low.contains("large"):return absolute
    return fallback
func _absolute_url(path:String)->String:
    if path.begins_with("https://") or path.begins_with("http://"):return path
    if path.begins_with("//"):return "https:"+path
    if path.begins_with("/"):return OFFICIAL_ROOT+path
    return "%s/library/bf1/%s"%[OFFICIAL_ROOT,path]
func _asset_failed(reason:String)->void: status.text="%s: %s"%[active_item.get("name","Asset"),reason];_render_gallery();call_deferred("_download_next")
func _element_color(element:String)->Color:
    match element:
        "Fire":return Color("b7372f")
        "Water":return Color("2d69b4")
        "Earth":return Color("538c45")
        "Thunder":return Color("b29327")
        "Light":return Color("d5c96d")
        _:return Color("754b9d")
