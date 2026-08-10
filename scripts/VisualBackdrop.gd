extends Control

const BG_TOP := Color("071326")
const BG_BOTTOM := Color("102844")
const GOLD := Color("f2c14e")
const BLUE := Color("4d8dff")
const PURPLE := Color("8d5cff")
const CYAN := Color("53d6d9")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(false)
    queue_redraw()

func _draw() -> void:
    var s := size
    if s.x <= 0.0 or s.y <= 0.0:
        return
    draw_rect(Rect2(Vector2.ZERO, s), BG_BOTTOM)
    var bands := 18
    for i in range(bands):
        var t := float(i) / float(bands - 1)
        var c := BG_TOP.lerp(BG_BOTTOM, t)
        draw_rect(Rect2(0, s.y * t, s.x, s.y / bands + 2), c)

    _orb(Vector2(s.x * 0.18, s.y * 0.18), minf(s.x, s.y) * 0.18, BLUE)
    _orb(Vector2(s.x * 0.86, s.y * 0.34), minf(s.x, s.y) * 0.16, PURPLE)
    _orb(Vector2(s.x * 0.45, s.y * 0.78), minf(s.x, s.y) * 0.22, CYAN)

    for i in range(22):
        var x := fmod(float(i * 137 + 43), maxf(1.0, s.x))
        var y := fmod(float(i * 211 + 89), maxf(1.0, s.y))
        var r := 1.5 + float(i % 3)
        draw_circle(Vector2(x, y), r, Color(GOLD, 0.25 + 0.08 * float(i % 4)))

    var center := Vector2(s.x * 0.5, s.y * 0.46)
    for j in range(4):
        draw_arc(center, minf(s.x, s.y) * (0.12 + j * 0.035), 0.0, TAU, 64, Color(GOLD, 0.05 + j * 0.018), 2.0)

func _orb(pos: Vector2, radius: float, color: Color) -> void:
    for i in range(9, 0, -1):
        var rr := radius * float(i) / 9.0
        draw_circle(pos, rr, Color(color, 0.012 + 0.006 * float(10 - i)))
