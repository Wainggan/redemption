
if !game_paused() {
	global.time++;
	global.game.update();
}

global.logger.update();

if keyboard_check_pressed(ord("8")) global.config.slow = !global.config.slow;
if keyboard_check_pressed(ord("0")) global.demonstrate = !global.demonstrate;

if keyboard_check_pressed(ord("6")) game_set_freeze(!game_paused());

if keyboard_check_pressed(ord("9")) {
	if gif_state == 0 {
		log(Log.user, "ready to start recording!");
		gif_id = gif_open(WIDTH, HEIGHT);
		gif_state = 1;
	} else if gif_state == 1 {
		log(Log.user, "recording ...");
		gif_state = 2;
	} else if gif_state == 2 {
		var _name = $"{irandom(99999999)}.gif";
		log(Log.user, $"gif saved! ({game_save_id}/{_name})");
		var _status = gif_save(gif_id, _name);
		if _status == -1 {
			log(Log.user, $"recording failed?");
		}
		gif_state = 0;
	}
}

if global.config.slow {
	game_set_speed(10, gamespeed_fps)
} else {
	game_set_speed(60, gamespeed_fps)
}

game_pause_update();

game_timer_update()

