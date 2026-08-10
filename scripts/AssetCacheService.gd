extends Node

const OFFICIAL_ROOT := "https://www.bravefrontier.jp"

# Silent background cache. No gallery/menu is exposed to the player.
# First six are the classic heroes; second six broaden the early summon roster.
const ASSETS := [
    {"name":"Vargas","no":1,"cache":"vargas_official.png"},
    {"name":"Selena","no":5,"cache":"selena_official.png"},
    {"name":"Lance","no":9,"cache":"lance_official.png"},
    {"name":"Eze","no":13,"cache":"eze_official.png"},
    {"name":"Atro","no":17,"cache":"atro_official.png"},
    {"name":"Magress","no":21,"cache":"magress_official.png"},
    {"name":"Zelgal","no":25,"cache":"zelgal_official.png"},
    {"name":"Zephu","no":28,"cache":"zephu_official.png"},
    {"name":"Lario","no":31,"cache":"lario_official.png"},
    {"name":"Weiss","no":34,"cache":"weiss_official.png"},
    {"name":"Luna","no":37,"cache":"luna_official.png"},
    {"name":"Mifune","no":40,"cache":"mifune_official.png"}
]

var request: HTTPRequest
var pending: Array = []
var active: Dictionary = {}
var phase := ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    request = HTTPRequest.new()
    request.timeout = 20.0
    add_child(request)
    request.request_completed.connect(_completed)
    call_deferred("_queue_missing")

func _cache_path(filename: String) -> String:
    var dir := "user://bf_assets"
    DirAccess.make_dir_absolute(ProjectSettings.globalize_path(dir))
    return "%s/%s" % [dir, filename]

func _queue_missing() -> void:
    pending.clear()
    for item in ASSETS:
        if not FileAccess.file_exists(_cache_path(str(item["cache"]))):
            pending.append(item.duplicate(true))
    _next()

func _next() -> void:
    if pending.is_empty():
        return
    if request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        return
    active = pending.pop_front()
    phase = "page"
    var url := "%s/library/bf1/bf1_full.php?no=%d" % [OFFICIAL_ROOT, int(active["no"])]
    var err := request.request(url, ["User-Agent: Mozilla/5.0 FrontierOffline/0.3"])
    if err != OK:
        call_deferred("_next")

func _completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 400:
        call_deferred("_next")
        return
    if phase == "page":
        var image_url := _extract_image(body.get_string_from_utf8())
        if image_url == "":
            call_deferred("_next")
            return
        phase = "image"
        var err := request.request(image_url, ["User-Agent: Mozilla/5.0 FrontierOffline/0.3", "Referer: %s/" % OFFICIAL_ROOT])
        if err != OK:
            call_deferred("_next")
        return
    if phase == "image":
        var image := Image.new()
        var ok := image.load_png_from_buffer(body)
        if ok != OK: ok = image.load_jpg_from_buffer(body)
        if ok != OK: ok = image.load_webp_from_buffer(body)
        if ok == OK:
            image.save_png(ProjectSettings.globalize_path(_cache_path(str(active["cache"]))))
        call_deferred("_next")

func _extract_image(html: String) -> String:
    var re := RegEx.new()
    re.compile("(?:src|href)=[\\\"']([^\\\"']+\\.(?:png|jpg|jpeg|webp)(?:\\?[^\\\"']*)?)[\\\"']")
    var fallback := ""
    for match in re.search_all(html):
        var candidate := match.get_string(1).replace("&amp;", "&")
        var low := candidate.to_lower()
        if low.contains("logo") or low.contains("icon") or low.contains("btn") or low.contains("common"):
            continue
        var absolute := _absolute(candidate)
        if fallback == "": fallback = absolute
        if low.contains("full") or low.contains("unit") or low.contains("chara") or low.contains("large"):
            return absolute
    return fallback

func _absolute(path: String) -> String:
    if path.begins_with("https://") or path.begins_with("http://"): return path
    if path.begins_with("//"): return "https:" + path
    if path.begins_with("/"): return OFFICIAL_ROOT + path
    return "%s/library/bf1/%s" % [OFFICIAL_ROOT, path]
