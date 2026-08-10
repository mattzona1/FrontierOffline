extends Control

const GOLD := Color("f2c14e")
const TEXT := Color("eef4ff")
const MUTED := Color("9fb0ca")
const SAVE_VERSION := 4
const RESET_MARKER := "user://reset_v021.done"

var status_label: Label

func _ready() -> void:
    _reset_save_once()
    _add_visual_backdrop()
    _draw_boot_screen()
    call_deferred("_boot_game")

func _reset_save_once() -> void:
    if FileAccess.file_exists(RESET_MARKER):
        return
    if FileAccess.file_exists("user://save.json"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
    var marker := FileAccess.open(RESET_MARKER, FileAccess.WRITE)
    if marker:
        marker.store_string("Fresh test save created for duplicate-refund milestone.")

func _add_visual_backdrop() -> void:
    var backdrop_script = load("res://scripts/VisualBackdrop.gd")
    if backdrop_script == null:
        return
    var backdrop := Control.new()
    backdrop.set_script(backdrop_script)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)
    move_child(backdrop, 0)

func _draw_boot_screen() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 24
    root.offset_right = -24
    root.offset_top = 80
    root.offset_bottom = -80
    root.alignment = BoxContainer.ALIGNMENT_CENTER
    root.add_theme_constant_override("separation", 18)
    add_child(root)

    var title := Label.new()
    title.text = "FRONTIER OFFLINE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 38)
    title.add_theme_color_override("font_color", GOLD)
    root.add_child(title)

    status_label = Label.new()
    status_label.text = "Preparing fresh test save..."
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 20)
    status_label.add_theme_color_override("font_color", TEXT)
    root.add_child(status_label)

    var hint := Label.new()
    hint.text = "Duplicate summons refund their 5 Gems • original art button is forced into Home"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 15)
    hint.add_theme_color_override("font_color", MUTED)
    root.add_child(hint)

func _boot_game() -> void:
    await get_tree().process_frame
    status_label.text = "Checking save compatibility..."
    _migrate_legacy_save()
    await get_tree().process_frame
    status_label.text = "Starting Grand Gaia..."

    var script = load("res://scripts/Main.gd")
    if script == null:
        status_label.text = "Recovery mode: the main game script could not be loaded."
        return

    var game := Control.new()
    game.set_script(script)
    game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(game)
    await get_tree().process_frame

    var gallery := _add_asset_gallery(game)
    _add_runtime_guard(game, gallery)

    if is_instance_valid(status_label):
        var boot_root := status_label.get_parent()
        if is_instance_valid(boot_root):
            boot_root.queue_free()

func _add_asset_gallery(game: Node) -> Node:
    var gallery_script = load("res://scripts/AssetGallery.gd")
    if gallery_script == null:
        return null
    var gallery := Control.new()
    gallery.set_script(gallery_script)
    gallery.set("game", game)
    gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    gallery.z_index = 50
    add_child(gallery)
    return gallery

func _add_runtime_guard(game: Node, gallery: Node) -> void:
    var guard_script = load("res://scripts/RuntimeGuard.gd")
    if guard_script == null:
        return
    var guard := Node.new()
    guard.set_script(guard_script)
    guard.set("game", game)
    guard.set("gallery", gallery)
    add_child(guard)

func _migrate_legacy_save() -> void:
    if not FileAccess.file_exists("user://save.json"):
        return

    var f := FileAccess.open("user://save.json", FileAccess.READ)
    if not f:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        _write_clean_save(20, 1000, 1, 0)
        return

    var data: Dictionary = parsed
    var version := int(data.get("save_version", 0))
    if version >= SAVE_VERSION and _looks_like_v3(data):
        return

    var keep_gems := maxi(0, int(data.get("gems", 20)))
    var keep_gold := maxi(0, int(data.get("gold", 1000)))
    var keep_rank := maxi(1, int(data.get("rank", 1)))
    var keep_selected := clampi(int(data.get("selected", 0)), 0, 5)
    _write_clean_save(keep_gems, keep_gold, keep_rank, keep_selected)

func _looks_like_v3(data: Dictionary) -> bool:
    if typeof(data.get("inventory", null)) != TYPE_ARRAY:
        return false
    if typeof(data.get("squad", null)) != TYPE_ARRAY:
        return false
    if data["inventory"].size() < 6 or data["squad"].size() != 6:
        return false
    return true

func _write_clean_save(keep_gems: int, keep_gold: int, keep_rank: int, keep_selected: int) -> void:
    var starter_inventory := []
    for i in range(6):
        starter_inventory.append({"def_id":i,"level":1,"xp":0,"evo":0,"bb":0,"locked":false})

    var clean := {
        "save_version": SAVE_VERSION,
        "gems": keep_gems,
        "gold": keep_gold,
        "rank": keep_rank,
        "rank_xp": 0,
        "selected": keep_selected,
        "unlocked_quest": 0,
        "cleared_quests": [],
        "materials": {"Ember":0,"Tide":0,"Verdant":0,"Volt":0,"Lumen":0,"Dusk":0},
        "squad": [0,1,2,3,4,5],
        "inventory": starter_inventory
    }

    var out := FileAccess.open("user://save.json", FileAccess.WRITE)
    if out:
        out.store_string(JSON.stringify(clean))
