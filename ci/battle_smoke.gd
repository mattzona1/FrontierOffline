extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game_script = load("res://scripts/BraveMain.gd")
    var battle_script = load("res://scripts/OriginalQuestBattle.gd")
    var accuracy_script = load("res://scripts/FirstQuestAccuracy.gd")
    if game_script == null or battle_script == null or accuracy_script == null:
        push_error("Battle smoke: required script failed to load")
        quit(2)
        return

    var game := Control.new()
    game.set_script(game_script)
    game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(game)
    await process_frame

    var accuracy := Node.new()
    accuracy.set_script(accuracy_script)
    accuracy.set("game",game)
    root.add_child(accuracy)
    await process_frame
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
        push_error("Battle smoke: original-asset battle scene did not become visible")
        quit(3)
        return
    if battle.get_child_count() == 0:
        push_error("Battle smoke: scene built no visual nodes")
        quit(4)
        return

    var before_hp := int(game.get("enemy_hp"))
    battle.call("_normal_attack",0)
    for i in range(30):
        await process_frame
    var after_hp := int(game.get("enemy_hp"))
    if after_hp >= before_hp:
        push_error("Battle smoke: attack did not reduce enemy HP")
        quit(5)
        return

    var inventory = game.get("inventory")
    var squad = game.get("squad")
    var unit = inventory[int(squad[1])]
    unit["bb"] = 10
    var bb_before := int(game.get("enemy_hp"))
    battle.call("_burst",1)
    for i in range(45):
        await process_frame
    var bb_after := int(game.get("enemy_hp"))
    if bb_after >= bb_before:
        push_error("Battle smoke: Brave Burst did not reduce enemy HP")
        quit(6)
        return

    print("BATTLE_ATTACK_OK hp=",before_hp,"->",after_hp," bb=",bb_before,"->",bb_after)
    print("BATTLE_SMOKE_OK children=", battle.get_child_count())
    quit(0)
