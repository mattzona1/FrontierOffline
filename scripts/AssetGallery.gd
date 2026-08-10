extends Control

const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("a9bbd3")
const PANEL := Color("101a2c")
const PANEL_2 := Color("243a5a")

var game: Node
var panel: PanelContainer
var status: Label
var gallery_grid: GridContainer
var request: HTTPRequest
var pending: Array = []
var active_item: Dictionary = {}

var starters := [
    {"name":"Vargas","element":"Fire","file":"Unit_ills_full_10011.png"},
    {"name":"Selena","element":"Water","file":"Unit_ills_full_20011.png"},
    {"name":"Lance","element":"Earth","file":"Unit_ills_full_30011.png"},
    {"name":"Eze","element":"Thunder","file":"Unit_ills_full_40011.png"},
    {"name":"Atro","element":"Light","file":"Unit_ills_full_50011.png"},
    {"name":"Magress","element":"Dark","file":"Unit_ills_full_60011.png"}
]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    request = HTTPRequest.new()
    add_child(request)
    request.request_completed.connect(_on_request_completed)
    _build_button()

func _build_button() -> void:
    var b := Button.new()
    b.text = "ORIGINAL ART"
    b.position = Vector2(18, 194)
    b.size = Vector2(180, 56)
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(_open_gallery)
    add_child(b)

func _open_gallery() -> void:
    if panel != null and is_instance_valid(panel):
        panel.queue_free()
        panel = null
        return

    panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 14
    panel.offset_right = -14
    panel.offset_top = 90
    panel.offset_bottom = -35
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.corner_radius_top_left = 18
    style.corner_radius_top_right = 18
    style.corner_radius_bottom_left = 18
    style.corner_radius_bottom_right = 18
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 12)
    panel.add_child(root)

    var title := Label.new()
    title.text = "ORIGINAL BRAVE FRONTIER ART • STARTER BATCH"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 25)
    title.add_theme_color_override("font_color", GOLD)
    root.add_child(title)

    status = Label.new()
    status.text = "Cached art loads offline. Missing art downloads once and is saved locally."
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.add_theme_font_size_override("font_size", 15)
    status.add_theme_color_override("font_color", MUTED)
    root.add_child(status)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)

    gallery_grid = GridContainer.new()
    gallery_grid.columns = 2
    gallery_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gallery_grid.add_theme_constant_override("h_separation", 10)
    gallery_grid.add_theme_constant_override("v_separation", 10)
    scroll.add_child(gallery_grid)

    var controls := HBoxContainer.new()
    controls.add_theme_constant_override("separation", 8)
    var refresh := Button.new()
    refresh.text = "DOWNLOAD / REFRESH"
    refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    refresh.custom_minimum_size = Vector2(0, 64)
    refresh.pressed.connect(_refresh_assets)
    controls.add_child(refresh)
    var close := Button.new()
    close.text = "CLOSE"
    close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    close.custom_minimum_size = Vector2(0, 64)
    close.pressed.connect(_open_gallery)
    controls.add_child(close)
    root.add_child(controls)

    _render_gallery()
    _queue_missing()

func _cache_path(filename: String) -> String:
    var dir := "user://bf_assets"
    DirAccess.make_dir_absolute(ProjectSettings.globalize_path(dir))
    return "%s/%s" % [dir, filename]

func _render_gallery() -> void:
    if gallery_grid == null:
        return
    for c in gallery_grid.get_children():
        c.queue_free()
    for item in starters:
        gallery_grid.add_child(_make_card(item))

func _make_card(item: Dictionary) -> Control:
    var card := VBoxContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var tex := TextureRect.new()
    tex.custom_minimum_size = Vector2(0, 245)
    tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var path := _cache_path(str(item["file"]))
    if FileAccess.file_exists(path):
        var image := Image.new()
        if image.load(ProjectSettings.globalize_path(path)) == OK:
            tex.texture = ImageTexture.create_from_image(image)
    if tex.texture == null:
        var placeholder := GradientTexture2D.new()
        var grad := Gradient.new()
        grad.colors = PackedColorArray([_element_color(str(item["element"])), Color("121827")])
        placeholder.gradient = grad
        placeholder.width = 256
        placeholder.height = 256
        tex.texture = placeholder
    card.add_child(tex)
    var name := Label.new()
    name.text = "%s • %s" % [item["name"], item["element"]]
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.add_theme_font_size_override("font_size", 19)
    name.add_theme_color_override("font_color", TEXT)
    card.add_child(name)
    var state := Label.new()
    state.text = "CACHED" if FileAccess.file_exists(path) else "DOWNLOAD NEEDED"
    state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    state.add_theme_font_size_override("font_size", 13)
    state.add_theme_color_override("font_color", MUTED)
    card.add_child(state)
    return card

func _refresh_assets() -> void:
    pending.clear()
    for item in starters:
        pending.append(item)
    status.text = "Refreshing original starter art..."
    _download_next()

func _queue_missing() -> void:
    pending.clear()
    for item in starters:
        if not FileAccess.file_exists(_cache_path(str(item["file"]))):
            pending.append(item)
    if pending.is_empty():
        status.text = "All six starter artworks are cached and available offline."
        return
    status.text = "Downloading %d missing starter artwork%s..." % [pending.size(), "s" if pending.size() != 1 else ""]
    _download_next()

func _download_next() -> void:
    if pending.is_empty():
        status.text = "Starter art cache ready."
        _render_gallery()
        return
    active_item = pending.pop_front()
    var filename := str(active_item["file"])
    var encoded := filename.uri_encode()
    var url := "https://bravefrontierglobal.fandom.com/wiki/Special:Redirect/file/%s" % encoded
    var err := request.request(url)
    if err != OK:
        status.text = "Could not request %s; continuing." % active_item["name"]
        call_deferred("_download_next")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code >= 200 and response_code < 400 and body.size() > 1000:
        var image := Image.new()
        var ok := image.load_png_from_buffer(body)
        if ok == OK:
            var path := _cache_path(str(active_item["file"]))
            var f := FileAccess.open(path, FileAccess.WRITE)
            if f:
                f.store_buffer(body)
            status.text = "Cached %s. %d remaining." % [active_item["name"], pending.size()]
        else:
            status.text = "%s returned non-PNG data; continuing." % active_item["name"]
    else:
        status.text = "%s download failed (%d); continuing." % [active_item.get("name", "Asset"), response_code]
    _render_gallery()
    call_deferred("_download_next")

func _element_color(element: String) -> Color:
    match element:
        "Fire": return Color("b7372f")
        "Water": return Color("2d69b4")
        "Earth": return Color("538c45")
        "Thunder": return Color("b29327")
        "Light": return Color("d5c96d")
        _: return Color("754b9d")
