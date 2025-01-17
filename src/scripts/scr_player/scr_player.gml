

function game_player_kill() {
	
	if !instance_exists(obj_player) return;
	
	var _x = obj_player.x, _y = obj_player.y;
	game_render_particle(_x, _y - 16, ps_player_death_0);
	global.game.schedule.add_wait(2, method({ _x, _y }, function(){
		game_render_particle(_x, _y - 16, ps_player_death_1);
		game_camera_set_shake(8, 0.8);
		game_set_pause(1);
		game_render_wave(_x, _y - 16, 256, 90, 1, spr_wave_wave);
		
		with obj_Entity {
			reset();
		}
		global.onoff = 1;
	}));
	
	game_sound_play(sfx_death);
	game_set_pause(14);
	game_camera_set_shake(2, 0.4);
	
	game_timer_stop()
	instance_create_layer(obj_player.x, obj_player.y, "Instances", obj_player_death);
	instance_destroy(obj_player);
	
}
