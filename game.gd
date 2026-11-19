extends Node2D
## ISTRA SHOOTER v0.4 — procedural playable vertical slice
## Created by Oleg Istratov. Original code and procedural art.

const WORLD := Vector2(2600, 1800)
const PLAYER_SPEED := 285.0
const BULLET_SPEED := 1000.0
const MAX_AMMO := 32
var player := WORLD / 2.0
var hp := 100.0
var ammo := MAX_AMMO
var reserve := 224
var grenades := 3
var kills := 0
var credits := 0
var weapon_level := 1
var boss_wave := 0
var best_kills := 0
var boss_alert := 0.0
var wave := 0
var elapsed := 0.0
var shoot_timer := 0.0
var spawn_timer := 0.0
var wave_timer := 0.0
var reload_timer := 0.0
var invuln := 0.0
var shake := 0.0
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var decor: Array[Dictionary] = []
var state := "menu"
var touch_move_id := -1
var touch_aim_id := -1
var move_origin := Vector2.ZERO
var move_pos := Vector2.ZERO
var aim_origin := Vector2.ZERO
var aim_pos := Vector2.ZERO
var aim_dir := Vector2.RIGHT
var mouse_firing := false
var touch_firing := false
var rng := RandomNumberGenerator.new()
var font: Font

func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	for i in range(120):
		decor.append({"p": Vector2(rng.randf_range(80, WORLD.x - 80), rng.randf_range(80, WORLD.y - 80)), "kind": rng.randi_range(0, 3)})
	set_process(true)

func reset_game() -> void:
	player = WORLD / 2.0
	hp = 100.0
	ammo = MAX_AMMO
	reserve = 224
	grenades = 3
	kills = 0
	credits = 0
	weapon_level = 1
	boss_wave = 0
	wave = 0
	elapsed = 0.0
	shoot_timer = 0.0
	spawn_timer = 0.0
	wave_timer = 0.0
	reload_timer = 0.0
	enemies.clear()
	bullets.clear()
	particles.clear()
	pickups.clear()
	state = "playing"
	start_wave()

func start_wave() -> void:
	wave += 1
	wave_timer = 2.5
	spawn_timer = 0.1
	if wave % 3 == 0:
		spawn_boss()

func spawn_boss() -> void:
	boss_wave = wave
	boss_alert = 4.0
	var pos := (player + Vector2(450, -300)).clamp(Vector2(80, 80), WORLD - Vector2(80, 80))
	enemies.append({"p": pos, "hp": 650.0 + wave * 110.0, "max_hp": 650.0 + wave * 110.0, "speed": 67.0 + wave * 2.0, "damage": 25.0, "fast": false, "boss": true})

func upgrade_weapon() -> void:
	var cost := 100 * weapon_level
	if state == "playing" and credits >= cost and weapon_level < 6:
		credits -= cost
		weapon_level += 1

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	if state != "playing":
		queue_redraw()
		return
	elapsed += dt
	boss_alert = maxf(0.0, boss_alert - dt)
	shoot_timer = maxf(0.0, shoot_timer - dt)
	invuln = maxf(0.0, invuln - dt)
	shake = maxf(0.0, shake - dt * 20.0)
	if reload_timer > 0.0:
		reload_timer -= dt
		if reload_timer <= 0.0:
			var taken: int = mini(MAX_AMMO - ammo, reserve)
			ammo += taken
			reserve -= taken
	var movement := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): movement.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): movement.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): movement.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): movement.x += 1.0
	if touch_move_id != -1 and move_pos.distance_to(move_origin) > 8.0:
		movement += (move_pos - move_origin).limit_length(75.0) / 75.0
	player += movement.limit_length(1.0) * PLAYER_SPEED * dt
	player = player.clamp(Vector2(35, 35), WORLD - Vector2(35, 35))
	var screen_size := get_viewport_rect().size
	if touch_aim_id != -1:
		if aim_pos.distance_to(aim_origin) > 12.0:
			aim_dir = (aim_pos - aim_origin).normalized()
	else:
		var mouse_world := get_global_mouse_position() + player - screen_size / 2.0
		if mouse_world.distance_to(player) > 10.0:
			aim_dir = (mouse_world - player).normalized()
	if (mouse_firing or touch_firing) and shoot_timer <= 0.0 and reload_timer <= 0.0:
		shoot()
	if ammo == 0 and reserve > 0 and reload_timer <= 0.0:
		reload()
	if spawn_timer > 0.0:
		spawn_timer -= dt
	else:
		var cap: int = mini(15 + wave * 7, 85)
		if enemies.size() < cap:
			spawn_enemy()
		spawn_timer = maxf(0.24, 1.05 - wave * 0.075)
	if wave_timer > 0.0:
		wave_timer -= dt
	if elapsed > float(wave) * 35.0:
		start_wave()
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		var toward: Vector2 = player - e.p
		var dist: float = toward.length()
		if dist > 1.0:
			e.p += toward / dist * e.speed * dt
		if dist < 35.0 and invuln <= 0.0:
			hp -= e.damage
			invuln = 0.5
			shake = 6.0
			if hp <= 0.0:
				hp = 0.0
				state = "dead"
				best_kills = maxi(best_kills, kills)
		enemies[i] = e
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b.p += b.v * dt
		b.life -= dt
		var hit := false
		for j in range(enemies.size() - 1, -1, -1):
			var e: Dictionary = enemies[j]
			if b.p.distance_squared_to(e.p) < (1700.0 if e.get("boss", false) else 550.0):
				e.hp -= b.damage
				burst(b.p, Color(0.85, 0.15, 0.12), 5)
				if e.hp <= 0.0:
					kills += 1
					credits += 120 if e.get("boss", false) else (15 if e.fast else 10)
					burst(e.p, Color(0.5, 0.8, 0.25), 12)
					if rng.randf() < 0.12:
						pickups.append({"p": e.p, "type": rng.randi_range(0, 1)})
					enemies.remove_at(j)
				else:
					enemies[j] = e
				hit = true
				break
		if hit or b.life <= 0.0:
			bullets.remove_at(i)
		else:
			bullets[i] = b
	for i in range(particles.size() - 1, -1, -1):
		particles[i].p += particles[i].v * dt
		particles[i].life -= dt
		if particles[i].life <= 0.0:
			particles.remove_at(i)
	for i in range(pickups.size() - 1, -1, -1):
		if player.distance_to(pickups[i].p) < 34.0:
			if pickups[i].type == 0: hp = minf(100.0, hp + 20.0)
			else: reserve += 48
			pickups.remove_at(i)
	queue_redraw()

func shoot() -> void:
	if ammo <= 0: return
	ammo -= 1
	shoot_timer = maxf(0.055, 0.11 - (weapon_level - 1) * 0.009)
	var dir := aim_dir.rotated(rng.randf_range(-0.055, 0.055))
	bullets.append({"p": player + dir * 30.0, "v": dir * BULLET_SPEED, "life": 0.9, "damage": 30.0 + (weapon_level - 1) * 12.0})
	burst(player + dir * 32.0, Color(1.0, 0.7, 0.2), 3)
	shake = 2.0

func reload() -> void:
	if reload_timer <= 0.0 and ammo < MAX_AMMO and reserve > 0:
		reload_timer = 1.25

func grenade() -> void:
	if grenades <= 0 or state != "playing": return
	grenades -= 1
	shake = 10.0
	var target := player + aim_dir * 240.0
	burst(target, Color(1.0, 0.48, 0.1), 45)
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].p.distance_to(target) < 185.0:
			kills += 1
			enemies.remove_at(i)

func spawn_enemy() -> void:
	var angle := rng.randf_range(0.0, TAU)
	var p := (player + Vector2.from_angle(angle) * rng.randf_range(550.0, 760.0)).clamp(Vector2(30, 30), WORLD - Vector2(30, 30))
	var fast := rng.randf() < 0.28
	enemies.append({"p": p, "hp": 55.0 if fast else 100.0, "speed": (165.0 if fast else 95.0) + wave * 5.0, "damage": 9.0 if fast else 14.0, "fast": fast})

func burst(at: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var v := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(50.0, 270.0)
		particles.append({"p": at, "v": v, "life": rng.randf_range(0.18, 0.65), "color": color})

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if state == "playing": state = "paused"
			elif state == "paused": state = "playing"
		elif event.keycode == KEY_ENTER and state in ["menu", "dead"]: reset_game()
		elif event.keycode == KEY_R: reload()
		elif event.keycode == KEY_SPACE: grenade()
		elif event.keycode == KEY_U: upgrade_weapon()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if state in ["menu", "dead"] and event.pressed:
			reset_game()
		elif state == "paused" and event.pressed:
			state = "playing"
		else:
			mouse_firing = event.pressed
	if event is InputEventScreenTouch:
		var w := get_viewport_rect().size.x
		if event.pressed:
			if state in ["menu", "dead"]:
				reset_game()
				return
			if state == "paused":
				state = "playing"
				return
			if event.position.y < 120 and event.position.x > w - 160:
				reload()
				return
			if event.position.y > get_viewport_rect().size.y - 145 and event.position.x > w - 145:
				grenade()
				return
			if event.position.y > get_viewport_rect().size.y - 145 and event.position.x > w * 0.5 and event.position.x < w * 0.68:
				upgrade_weapon()
				return
			if event.position.x < w * 0.48 and touch_move_id == -1:
				touch_move_id = event.index
				move_origin = event.position
				move_pos = event.position
			elif touch_aim_id == -1:
				touch_aim_id = event.index
				aim_origin = event.position
				aim_pos = event.position
				touch_firing = true
		else:
			if event.index == touch_move_id: touch_move_id = -1
			if event.index == touch_aim_id:
				touch_aim_id = -1
				touch_firing = false
	if event is InputEventScreenDrag:
		if event.index == touch_move_id: move_pos = event.position
		if event.index == touch_aim_id: aim_pos = event.position

func text_at(at: Vector2, value: String, size: int = 22, color: Color = Color.WHITE) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Color("070b12"))
	if state == "menu":
		draw_rect(Rect2(Vector2.ZERO, screen), Color("0b101a"))
		text_at(Vector2(screen.x * 0.5 - 220, screen.y * 0.34), "ISTRA SHOOTER", 58, Color("f3f6fa"))
		text_at(Vector2(screen.x * 0.5 - 125, screen.y * 0.43), "CREATED BY OLEG ISTRATOV", 18, Color("ff554d"))
		text_at(Vector2(screen.x * 0.5 - 225, screen.y * 0.61), "ENTER / TAP — START SURVIVAL", 27)
		text_at(Vector2(screen.x * 0.5 - 285, screen.y * 0.69), "WASD move | Mouse fire | R reload | SPACE grenade | U upgrade", 18, Color("9eacbc"))
		return
	var offset := screen / 2.0 - player + Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	draw_set_transform(offset)
	# Ground: diagonal floor plates and shadowed industrial seams
	draw_rect(Rect2(Vector2.ZERO, WORLD), Color("171e28"))
	for x in range(0, int(WORLD.x) + 1, 96):
		draw_line(Vector2(x, 0), Vector2(x, WORLD.y), Color("28313d"), 2.0)
	for y in range(0, int(WORLD.y) + 1, 96):
		draw_line(Vector2(0, y), Vector2(WORLD.x, y), Color("28313d"), 2.0)
	for d in decor:
		var p: Vector2 = d.p
		match d.kind:
			0:
				draw_rect(Rect2(p + Vector2(9, 12), Vector2(72, 52)), Color(0, 0, 0, 0.4))
				draw_rect(Rect2(p, Vector2(72, 52)), Color("394655"))
				draw_rect(Rect2(p + Vector2(5, 5), Vector2(62, 12)), Color("627181"))
			1:
				draw_circle(p + Vector2(7, 7), 25, Color(0, 0, 0, 0.4))
				draw_circle(p, 23, Color("243d3d"))
				draw_circle(p, 14, Color("35bb80"))
			2:
				draw_rect(Rect2(p, Vector2(60, 10)), Color("655337"))
				draw_rect(Rect2(p + Vector2(5, 2), Vector2(8, 6)), Color("e2b552"))
			3:
				draw_circle(p, 9, Color("493032"))
	for item in pickups:
		var c := Color("62e7a4") if item.type == 0 else Color("ffcf61")
		draw_circle(item.p, 15, c.darkened(0.6))
		draw_circle(item.p, 9, c)
	for e in enemies:
		var p: Vector2 = e.p
		var is_boss: bool = e.get("boss", false)
		var c := Color("c447a0") if is_boss else (Color("b9454e") if e.fast else Color("688c47"))
		draw_ellipse_shadow(p, 46.0 if is_boss else 23.0)
		draw_circle(p + Vector2(0, -5), 43 if is_boss else (19 if e.fast else 24), c.darkened(0.35))
		draw_circle(p + Vector2(0, -10), 34 if is_boss else (14 if e.fast else 19), c)
		var face: Vector2 = (player - p).normalized()
		draw_circle(p + face * (22.0 if is_boss else 11.0) + Vector2(0, -10), 7 if is_boss else 5, Color("ff5149"))
		if is_boss:
			draw_rect(Rect2(p + Vector2(-46, -65), Vector2(92, 7)), Color("3b243a"))
			draw_rect(Rect2(p + Vector2(-46, -65), Vector2(92.0 * e.hp / e.max_hp, 7)), Color("ff4c9e"))
	for b in bullets:
		draw_line(b.p - b.v.normalized() * 22.0, b.p, Color("ffc665"), 5.0)
	for part in particles:
		draw_circle(part.p, 3.5, part.color)
	draw_ellipse_shadow(player, 26.0)
	var armor := Color("e3e9f1") if invuln > 0.0 else Color("738ba0")
	draw_circle(player + Vector2(0, -7), 24, Color("1a2633"))
	draw_circle(player + Vector2(0, -10), 19, armor)
	draw_circle(player + Vector2(0, -15), 10, Color("263d51"))
	draw_line(player + aim_dir * 8.0 - Vector2(0, 8), player + aim_dir * 37.0 - Vector2(0, 8), Color("161b23"), 11.0)
	draw_line(player + aim_dir * 20.0 - Vector2(0, 8), player + aim_dir * 39.0 - Vector2(0, 8), Color("8b9ba8"), 4.0)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, 78)), Color(0.025, 0.04, 0.07, 0.9))
	text_at(Vector2(22, 31), "ISTRA SHOOTER", 25, Color("f1f4f7"))
	text_at(Vector2(23, 55), "OLEG ISTRATOV  /  SURVIVAL PROTOTYPE 0.4", 12, Color("8c9bab"))
	draw_rect(Rect2(Vector2(280, 21), Vector2(210, 18)), Color("44252b"))
	draw_rect(Rect2(Vector2(280, 21), Vector2(210.0 * hp / 100.0, 18)), Color("ed4d4b"))
	text_at(Vector2(500, 37), str(int(hp)) + " HP", 18)
	text_at(Vector2(screen.x - 370, 32), "WAVE " + str(wave) + "   KILLS " + str(kills), 22)
	text_at(Vector2(screen.x - 370, 57), "AMMO " + str(ammo) + " / " + str(reserve) + "    GRENADES " + str(grenades), 17, Color("f0bb6a"))
	text_at(Vector2(24, screen.y - 22), "CREDITS " + str(credits) + "  |  WEAPON LVL " + str(weapon_level) + "  |  U UPGRADE (" + str(100 * weapon_level) + ")", 17, Color("ffd27a"))
	if boss_alert > 0.0: text_at(Vector2(screen.x * 0.5 - 170, 175), "WARNING: BOSS INCOMING", 27, Color("ff6da9"))
	if reload_timer > 0.0: text_at(Vector2(screen.x / 2.0 - 75, screen.y - 65), "RELOADING...", 24, Color("ffcf61"))
	if wave_timer > 0.0: text_at(Vector2(screen.x / 2.0 - 95, 115), "WAVE " + str(wave), 38, Color("ff665a"))
	if OS.has_feature("mobile"):
		draw_rect(Rect2(Vector2(screen.x - 148, 80), Vector2(136, 50)), Color("273d4b"))
		text_at(Vector2(screen.x - 135, 113), "RELOAD", 19)
		draw_rect(Rect2(Vector2(screen.x - 140, screen.y - 140), Vector2(128, 100)), Color("603332"))
		text_at(Vector2(screen.x - 130, screen.y - 83), "GRENADE", 17)
		draw_rect(Rect2(Vector2(screen.x * 0.50, screen.y - 140), Vector2(screen.x * 0.18, 90)), Color("53442a"))
		text_at(Vector2(screen.x * 0.51, screen.y - 90), "UPGRADE", 17)
	if touch_move_id != -1:
		draw_circle(move_origin, 75, Color(0.4, 0.5, 0.65, 0.16))
		draw_circle(move_pos, 31, Color(0.6, 0.7, 0.85, 0.35))
	if touch_aim_id != -1:
		draw_circle(aim_origin, 75, Color(0.7, 0.3, 0.3, 0.16))
		draw_circle(aim_pos, 31, Color(0.95, 0.4, 0.3, 0.35))
	if state in ["paused", "dead"]:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.75))
		text_at(screen / 2.0 + Vector2(-150, -25), "PAUSED" if state == "paused" else "MISSION FAILED", 44, Color("ff655b"))
		text_at(screen / 2.0 + Vector2(-185, 35), "TAP / CLICK TO CONTINUE" if state == "paused" else "TAP / ENTER TO RESTART", 24)

func draw_ellipse_shadow(at: Vector2, radius: float) -> void:
	draw_circle(at + Vector2(8, 11), radius, Color(0, 0, 0, 0.35))
