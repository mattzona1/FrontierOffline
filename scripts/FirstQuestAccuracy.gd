extends Node

# Locks the first playable quest to the documented Brave Frontier Mistral opening stage.
# Visual presentation is handled by the battle scene; this service keeps the content data
# truthful even while the rest of the prototype still uses simplified quest data.

var game: Node

func _ready() -> void:
    call_deferred("_apply")

func _apply() -> void:
    if game == null or not is_instance_valid(game):
        return
    var quests = game.get("quests")
    if typeof(quests) != TYPE_ARRAY or quests.is_empty():
        return
    quests[0] = {
        "name":"Start of Adventure",
        "area":"Adventurer's Prairie",
        "region":"Mistral",
        "energy":3,
        "battles":5,
        "gold":120,
        "gems":1,
        "xp":20,
        "drop":"Green Grass",
        "waves":[
            {"name":"Burny","element":"Fire","hp":360,"atk":32,"capture":true},
            {"name":"Squirty","element":"Water","hp":390,"atk":34,"capture":true},
            {"name":"Mossy","element":"Earth","hp":430,"atk":36,"capture":true},
            {"name":"Glowy","element":"Light","hp":480,"atk":40,"capture":true},
            {"name":"King Sparky","element":"Thunder","hp":2500,"atk":72,"capture":false,"boss":true}
        ],
        "encounter_pool":["Burny","Squirty","Mossy","Sparky","Glowy","Gloomy","Goblin","Merman","Mandragora","Harpy"],
        "documented":true
    }
    game.set("quests", quests)
