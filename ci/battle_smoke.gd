extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game_script = load("res://scripts/BraveMain.gd")
    var battle_script = load("res://scripts/BraveBattleScene.gd")
    if game_script == null or battle_script == null:
        push_error("Battle smoke: required script failed to load")
        quit(2)
        return

    var game := Control.new()
    game.set_script(game_script)
    game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(game)
    await process_frame
    game.call("_start_quest", 0)
    await process_frame

    var battle := Control.new()
    battle.set_script(battle_script)
    battle.set("game", game)
    battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(battle)

    for i in range(12):
        await process_frame

    if not battle.visible:
        push_error("Battle smoke: full-screen battle scene did not become visible")
        quit(3)
        return
    if battle.get_child_count() == 0:
        push_error("Battle smoke: scene built no visual nodes")
        quit(4)
        return

    print("BATTLE_SMOKE_OK children=", battle.get_child_count())
    quit(0)
