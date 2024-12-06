
if instance_number(obj_player) > 1 {
	instance_destroy();
	exit;
}

event_inherited();

defs = {
	move_speed: 2,
	move_accel: 0.5,
	move_slowdown: 0.08,
	move_slowdown_air: 0.04,
	
	gravity: 0.45,
	gravity_hold: 0.26,
	gravity_peak: 0.12,
	gravity_peak_thresh: 0.36,
	gravity_term: 0.12,
	
	boost_limit_x: 9,
	boost_limit_y: 3,
	
	jump_vel: -4.8,
	jump_time: 3,
	jump_damp: 0.6,
	jump_move_boost: 0.4,
	
	walljump_grace: 5,
	
	dashjump_time: 4,
	dashjump_fast_vel: -3.2,
	dashjump_fast_key_force: 6,
	dashjump_high_time: 8,
	
	terminal_vel: global.defs.terminal_vel,
	terminal_vel_fast: 6,
	
	wall_distance: 4,
	
	dash_total: 1,
	
	buffer: 10,
	grace: 5,
};


scale_x = 0;
scale_y = 0;

x_last = x;
y_last = y;

x_delta = 0;
y_delta = 0;

dir = 1;

light = instance_create_layer(x, y, "Lights", obj_light, {
	color: #ffffff,
	size: 60,
	intensity: 0.5,
});

buffer_jump = 0;
buffer_dash = 0;

nat_crouch = function(_value = undefined) {
	if _value != undefined {
		if _value {
			mask_index = spr_debug_player_crouch;
		} else {
			mask_index = spr_debug_player;
		}
	}
	return mask_index == spr_debug_player_crouch;
};
nat_crouch(false);

get_can_uncrouch = function() {
	if !nat_crouch() return true;
	var _pre = mask_index;
	mask_index = spr_debug_player;
	var _collide = actor_collision(x, y);
	mask_index = _pre;
	return !_collide;
};

onground = false;
onground_last = false;

grace = 0;
grace_y = 0;

vel_keygrace = 0;
vel_grace = 0;
vel_grace_timer = 0;

hold_jump = false;
hold_jump_vel = 0;
hold_jump_timer = 0;

key_force = 0;
key_force_timer = 0;

walljump_grace = 0;
walljump_grace_dir = 0;

ledge_key = 0;
ledge_buffer_dir = 0;
ledge_buffer_dir_timer = 0;
ledge_stick = 0;

dash_dir_x = 0;
dash_dir_y = 0;
dash_dir_x_vel = 0;
dash_dir_y_vel = 0;
dash_pre_x_vel = 0;
dash_pre_y_vel = 0;
dash_timer = 0;
dash_frame = 0;
dash_grace = 0;
dash_grace_kick = 0;
dash_recover = 0;

dash_left = defs.dash_total;

cam_ground_x = x;
cam_ground_y = y;

respawn_timer = 0;


tail_length = 12;
tail = yarn_create(tail_length, function(_p, i) {
	//_p.len = min(power(max(i - 4, 0) , 1.12) + 4, 8)
	_p.length = 4;
	
	_p.x = x;
	_p.y = y + i * 6;
		
	_p.size = max(parabola_mid(3, 7, 6, i) + 3, 6);
	_p.round = floor(clamp(i / (tail_length / 3), 1, 1));
});


action_tail_update_point = function(_p, i, _points) {
	var _len = array_length(_points);
	var _scale_nor = (i / _len);
	var _scale_inv = (_len - i) / _len;
	
	_p.weight = 0;
	_p.x_move = 0;
	_p.y_move = 0;
	
	//if state.is(state_swim) && swim_bullet {
	//	_p.damp = 0.5;
	//	
	//} else 
	//if holding {
		//_p.damp = 0.8;
		//_p.weight = 6;
		//
		//var _t1 = floor(_len * 0.5);
		//var _t2 = floor(_len * 0.75);
		//
		//_p.direction = (90 + 80 * -dir);
		//if i > _t1 {
			//_p.direction += (i - _t1) * -30 * dir;
			//if i > _t2 {
				//_p.direction += (i - _t2) * 60 * dir;
			//}
		//} else {
			//
		//}
	//} else {
		_p.damp = 0.8;
		
		var _d = sin(global.time / 60 - i * 0.6);
		_p.x_move = -dir * (power(_scale_inv, 6) * 6 + 0.1);
		_p.y_move = _d * (_scale_inv * 0.2 + 0.1) + 0.3 * _scale_inv;
	//}
};

action_tail_draw_point = function(_p, i, _points) {
	var _tip = dash_left == 0 ? #00ffff : #ff00ff;
	var _blend = dash_left == 0 ? #ddccdd : c_white;
	
	var _c = merge_color(c_white, _tip, clamp(i - 3, 0, tail_length) / tail_length);
	_c = multiply_color(_c, _blend);
	draw_sprite_ext(
		spr_player_tail, 0, 
		round_ext(_p.x, _p.round), round_ext(_p.y, _p.round), 
		//round_ext(_p.x, 0), round_ext(_p.y, 0), 
		_p.size / 16, _p.size / 16, 
		0, _c, 1
	);
};

action_tail_draw = function() {
	for (var i = array_length(tail.points) - 1; i >= 0; i--) {
		action_tail_draw_point(tail.points[i], i, tail.points);
	}
}


action_update_sprite = function() {
	
	tail.position(x, y);
	tail.update(, action_tail_update_point);
	
};


get_check_wall = function(_dir, _dist = defs.wall_distance) {
	return actor_collision(x + _dir * _dist, y);
};

get_lift_x = function() {
	var _out = actor_lift_get_x();
	return clamp(_out, -defs.boost_limit_x, defs.boost_limit_x);
};
get_lift_y = function() {
	var _out = actor_lift_get_y();
	return clamp(_out, -defs.boost_limit_y, 0);
};

get_check_death = function(_x, _y) {
	
	var _inst = instance_place(_x, _y, obj_spike);
	with _inst {
		if object_index == obj_spike_up && other.y_vel >= 0 return true;
		if object_index == obj_spike_down && other.y_vel <= 0 return true;
		if object_index == obj_spike_left && other.x_vel >= 0 return true;
		if object_index == obj_spike_right && other.x_vel <= 0 return true;
		return true;
	}
	
	static __size = 5;
	
	var _left = bbox_left + 1;
	var _top = bbox_top + 1;
	var _right = bbox_right - 1;
	var _bottom = bbox_bottom - 1;
	
	for (var i_level = 0; i_level < array_length(level.loaded); i_level++) {
		
		var _tm = level.loaded[i_level].tiles_spike;
		var _l_x = level.loaded[i_level].x;
		var _l_y = level.loaded[i_level].y;
		var _width = tilemap_get_width(_tm);
		var _height = tilemap_get_height(_tm);
		
		for (var _yy = max(0, (_top - _l_y) div TILESIZE - 1),
			_yy_l = min(_height, (_bottom - _l_y) div TILESIZE + 1);
			_yy < _yy_l; _yy++;
		) {
			for (var _xx = max(0, (_left - _l_x) div TILESIZE - 1),
				_xx_l = min(_width, (_right - _l_x) div TILESIZE + 1);
				_xx < _xx_l; _xx++;
			) {
				
				var _tile = tilemap_get(_tm, _xx, _yy);
				
				var _xp = _xx * TILESIZE + _l_x;
				var _yp = _yy * TILESIZE + _l_y;
				
				if _tile == 0 {
					continue;
				}
				
				switch _tile {
					case 1: {
						// 6 indents!! yippee
						if x_vel > 0 {
							break;
						}
						if !rectangle_in_rectangle(
							_left, _top, _right, _bottom,
							_xp, _yp, _xp + __size, _yp + 16
						) {
							break;
						}
						return true;
					}
					case 2: {
						if y_vel < 0 {
							break;
						}
						if !rectangle_in_rectangle(
							_left, _top, _right, _bottom,
							_xp, _yp + 16 - __size, _xp + 16, _yp + 16
						) {
							break;
						}
						return true;
					}
					case 3: {
						if x_vel < 0 {
							break;
						}
						if !rectangle_in_rectangle(
							_left, _top, _right, _bottom,
							_xp + 16 - __size, _yp, _xp + 16, _yp + 16
						) {
							break;
						}
						return true;
					}
					case 4: {
						if y_vel > 0 {
							break;
						}
						if !rectangle_in_rectangle(
							_left, _top, _right, _bottom,
							_xp, _yp, _xp + 16, _yp + __size
						) {
							break;
						}
						return true;
					}
				}
				
			}
		}
		
	}
	
	return false;
	
};


action_jump_shared = function() {
	
	buffer_jump = 0;
	grace = 0;
	
	dash_grace = 0;
	dash_grace_kick = 0;
	
	hold_jump = false;
	hold_jump_vel = defs.terminal_vel;
	hold_jump_timer = 0;
	
};

action_jump = function() {
	
	var _kh = INPUT.check("right") - INPUT.check("left");
	var _kv = INPUT.check("down") - INPUT.check("up");
	
	if grace > 0 {
		actor_move_y(grace_y - y);
	}
	
	action_jump_shared();
	
	y_vel = min(y_vel, defs.jump_vel);
	if !INPUT.check("jump") {
		y_vel *= defs.jump_damp;
	}
	
	if _kh != 0 && abs(x_vel) < defs.move_speed {
		x_vel = defs.move_speed * _kh;
	}
	x_vel += defs.jump_move_boost * _kh;
	
	hold_jump = false;
	hold_jump_vel = y_vel;
	hold_jump_timer = defs.jump_time;
	
	x_vel += get_lift_x();
	y_vel += get_lift_y();
	
	dash_left = defs.dash_total;
	
	scale_x = 0.7;
	scale_y = 1.3;
	
};

action_walljump = function() {
	
	if actor_lift_get_x() == 0 && actor_lift_get_y() == 0 {
		var _inst = instance_place(x + dir * defs.wall_distance, y, obj_Solid);
		if _inst != noone {
			actor_lift_set(_inst.lift_x, _inst.lift_y);
		}
	}
	
	action_jump();
	
	hold_jump = true;
	
	walljump_grace = defs.walljump_grace;
	walljump_grace_dir = dir;
	
};

action_dashjump = function(_key_dir) {
	
	if grace > 0 {
		actor_move_y(grace_y - y);
	}
	
	action_jump_shared();
	
	if dash_dir_y == 0 {
		if _key_dir == dash_dir_x {
			// normal long jump
			
			y_vel = defs.jump_vel;
			
			x_vel = min(abs(dash_dir_x_vel * 0.6), 5) * _key_dir;
			x_vel = max(abs(x_vel), defs.move_speed) * sign(x_vel);
			
			hold_jump_timer = defs.dashjump_time;
		} else {
			// high jump
			
			y_vel = defs.jump_vel;
			
			x_vel = abs(dash_dir_x_vel * 0.4) * _key_dir;
			x_vel = max(abs(x_vel), defs.move_speed) * sign(x_vel);
			
			hold_jump_timer = defs.dashjump_high_time;
		}
	} else {
		// fast long jump
		
		y_vel = defs.dashjump_fast_vel;
		
		var _idk = x_vel; // ????
		var _test = abs(dash_dir_x_vel) * 0.7 + 3;
		x_vel = max(abs(x_vel), _test) * _key_dir;
		
		key_force = sign(x_vel);
		key_force_timer = defs.dashjump_fast_key_force;
		
		hold_jump_timer = defs.dashjump_time;
	}
	if !INPUT.check("jump") {
		y_vel *= defs.jump_damp;
	}
	
	hold_jump = false;
	hold_jump_vel = y_vel;
	
	if get_can_uncrouch() {
		nat_crouch(false);
	}
	
	x_vel += get_lift_x();
	y_vel += get_lift_y();
	
	scale_x = 0.8;
	scale_y = 1.2;
	
};

action_dashjump_wall = function(_key_dir, _wall_dir) {
	
	action_jump_shared();
	
	if dash_recover <= 0 {
		dash_left = defs.dash_total;
	}
	
	if _key_dir == _wall_dir {
		y_vel = min(-6.5, y_vel, -min(abs(dash_dir_x_vel) + 1, 8));
		x_vel = -_wall_dir * 2;
		
		key_force_timer = 9;
	} else {
		y_vel = min(-6.2, y_vel, -min(abs(dash_dir_x_vel) + 1, 9));
		x_vel = -_wall_dir * 4;
		
		key_force_timer = 5;
	}
	
	key_force = -_wall_dir;
	dir = -_wall_dir;
	
	hold_jump = false;
	hold_jump_vel = y_vel;
	hold_jump_timer = 6;
	
	vel_grace = 0;
	vel_grace_timer = 0;
	
	x_vel += get_lift_x();
	y_vel += get_lift_y();
	
	scale_x = 0.6;
	scale_y = 1.4;
	
};


state = new State();

state_base = state.add()
.set("step", function () {
	
	buffer_jump -= 1;
	buffer_dash -= 1;
	if INPUT.check_pressed("jump") {
		buffer_jump = defs.buffer + 1;
	}
	if INPUT.check_pressed("dash") {
		buffer_dash = defs.buffer + 1;
	}
	
	if game_paused() {
		return;
	}
	
	x_delta = x - x_last;
	y_delta = y - y_last;
	
	x_last = x;
	y_last = y;
	
	scale_x = lerp(scale_x, 1, 0.2);
	scale_y = lerp(scale_y, 1, 0.2);
	
	if y_vel >= 0 {
		onground = actor_collision(x, y + 1);
	} else {
		onground = false;
	}
	
	grace -= 1;
	dash_recover -= 1;
	if onground {
		grace = defs.grace;
		grace_y = y;
	}
	
	if (grace > 0 && dash_recover <= 0) || (state.is(state_ledge)) {
		dash_left = defs.dash_total;
	}
	
	state.child();
	
	var _d = 0, _amount = 0;
	var _shifted = false;
	
	if (y_vel < 0 ||
		(dash_grace > 0 && dash_dir_y == 1 && dash_dir_x == 0)) &&
		!_shifted {
		_d = 0;
		_amount = 8;
		if actor_collision(x, y + y_vel)
			for (_d = 1; _d < _amount; _d++) {
				if actor_collision(x - _d, y + y_vel) {
				} else break;
			}
		if _d != _amount {
			actor_move_x(-_d)
			_shifted = true;
		}
		
		_d = 0;
		if actor_collision(x, y + y_vel)
			for (_d = 1; _d < _amount; _d++) {
				if actor_collision(x + _d, y + y_vel) {
				} else break;
			}
		if _d != _amount {
			actor_move_x(_d)
			_shifted = true;
		}
	}
	
	static __collide_y = function() {
		if y_vel > 0 {
			if y_vel > 1 {
				scale_x = 1.2;
				scale_y = 0.8;
			}
		}
		y_vel = 0;
	};
	actor_move_y(y_vel, __collide_y);
	
	if !_shifted {
		_d = 0;
		_amount = state.is(state_dash) ? 16 : 4;
		if actor_collision(x + x_vel, y)
			for (_d = 1; _d < _amount; _d++) {
				if actor_collision(x + x_vel, y + _d) {
				} else break;
			}
		if _d != _amount {
			actor_move_y(_d)
			_shifted = true;
		}
			
		_d = 0;
		_amount = state.is(state_dash) ? 10 : 2;
		if actor_collision(x + x_vel, y)
			for (_d = 1; _d < _amount; _d++) {
				if actor_collision(x + x_vel, y - _d) {
				} else break;
			}
		if _d != _amount {
			actor_move_y(-_d)
			_shifted = true;
		}
	}
	
	static __collide_x = function() {
		if vel_grace_timer <= 0 {
			vel_grace_timer = 14;
			vel_grace = x_vel;
		}
		x_vel = 0;
	};
	actor_move_x(x_vel, __collide_x);
	
	if instance_exists(light) {
		light.x = x;
		light.y = y - (nat_crouch() ? 14 : 22);
	}
	
	if get_check_death(x, y) {
		game_player_kill();
	}
	
	action_update_sprite();
	
	actor_lift_update();
	
	onground_last = onground;
	dash_grace -= 1;
	dash_grace_kick -= 1;
	vel_grace_timer -= 1;
	
	if state.is(state_free) && !nat_crouch() {
		if INPUT.check_pressed("menu") && place_meeting(x, y, obj_checkpoint) {
			state.change(state_menu)
			return;
		} else if INPUT.check("menu") {
			respawn_timer += 1;
			if respawn_timer > 17 {
				game_player_kill();
			}
		} else {
			respawn_timer = approach(respawn_timer, 0, 2);
		}
	} else {
		respawn_timer = approach(respawn_timer, 0, 2);
	}
	
});

state_stuck = state_base.add()
.set("step", function(){
	x_vel = approach(x_vel, 0, 0.5);
	y_vel = approach(y_vel, defs.terminal_vel, defs.gravity);
	if actor_collision(x, y + 1) {
		state.change(state_free);
	}
});

state_free = state_base.add()
.set("step", function () {
	
	var _kh = INPUT.check("right") - INPUT.check("left");
	var _kv = INPUT.check("down") - INPUT.check("up");
	
	var _k_move = _kh;
	key_force_timer -= 1;
	if key_force_timer > 0 {
		_k_move = key_force;
	}
	if onground && nat_crouch() {
		_k_move = 0;
	}
	
	if vel_grace_timer > 0 {
		if _kh != sign(vel_grace) {
			vel_grace_timer = 0;
		} else if !actor_collision(x + _kh, y) {
			x_vel = vel_grace;
			vel_grace_timer = 0;
		}
	}
	
	var _x_accel = 0;
	if abs(x_vel) > defs.move_speed && _k_move == sign(x_vel) {
		_x_accel = defs.move_slowdown;
		if !onground {
			vel_keygrace = 6;
			_x_accel = defs.move_slowdown_air;
		}
	} else {
		_x_accel = defs.move_accel;
		if nat_crouch() _x_accel = 0.2;
	}
	
	vel_keygrace -= 1;
	if vel_keygrace > 0 && _k_move != sign(x_vel) {
		if onground {
			_x_accel = defs.move_slowdown;
		} else {
			_x_accel = defs.move_slowdown_air;
		}
	}
	
	walljump_grace -= 1;
	if walljump_grace > 0 {
		if walljump_grace_dir == -dir {
			if dir != 0 && abs(x_vel) < defs.move_speed {
				x_vel = defs.move_speed * dir;
				x_vel += defs.jump_move_boost * dir;
			}
		}
	}
	
	x_vel = approach(x_vel, _k_move * defs.move_speed, _x_accel);
	
	if _kh != 0 {
		if dir != _kh && onground && nat_crouch() {
			scale_x = 0.8;
			scale_y = 1.2;
		}
		dir = _kh;
	}
	
	var _k_jump = INPUT.check("jump");
	if hold_jump {
		_k_jump = true;
	}
	
	var _y_accel = 0;
	
	if _k_jump {
		if abs(y_vel) < defs.gravity_peak_thresh {
			_y_accel = defs.gravity_peak;
		} else {
			_y_accel = defs.gravity_hold;
		}
	} else {
		_y_accel = defs.gravity;
	}
	if y_vel >= defs.terminal_vel {
		_y_accel = defs.gravity_term;
	}
	
	if INPUT.check_released("jump") && y_vel < 0 {
		y_vel *= defs.jump_damp;
	}
	
	var _termvel = defs.terminal_vel;
	if _kv == 1 {
		_termvel = defs.terminal_vel_fast;
	}
	
	if INPUT.check("jump") {
		_termvel -= 1;
	}
	
	if hold_jump_timer > 0 {
		hold_jump_timer -= 1;
		if _k_jump {
			y_vel = min(y_vel, hold_jump_vel);
		} else {
			hold_jump = false;
			hold_jump_timer = 0;
		}
	} else {
		hold_jump = false;
	}
	
	if !onground {
		y_vel = approach(y_vel, _termvel, _y_accel);
	}
	
	if !onground && onground_last && y_vel >= 0 {
		x_vel += get_lift_x();
		y_vel += get_lift_y();
	}
	
	if nat_crouch() {
		if get_can_uncrouch() {
			if onground && !INPUT.check("down") {
				nat_crouch(false);
				scale_x = 0.8;
				scale_y = 1.2;
			}
			if !onground && y_vel >= 0 && !INPUT.check("down") {
				nat_crouch(false);
				scale_x = 0.8;
				scale_y = 1.2;
			}
		}
	} else {
		if onground && INPUT.check("down") {
			nat_crouch(true);
			scale_x = 1.2;
			scale_y = 0.8;
		}
	}
	
	if buffer_dash > 0 && dash_left > 0 {
		state.change(state_dash);
		return;
	}
	
	if buffer_jump > 0 {
		if grace > 0 {
			if dash_grace > 0 {
				action_dashjump(_kh == 0 && dash_dir_y == 1 ? dir : _kh);
			} else {
				action_jump();
			}
		} else {
			var _close = actor_collision(x, y + 24) ||
				get_check_wall(-1, 20) ||
				get_check_wall(1, 20);
			if _close && dash_grace > 0 {
				dash_grace = 2;
			}
			if dash_grace > 0 && dash_dir_y != -1 && 
				((_close && grace > 0) || !_close || dash_dir_y == 0) &&
				!get_check_wall(sign(x_vel), 6) {
				action_dashjump(_kh == 0 && dash_dir_y == 1 ? dir : _kh);
			} else if dash_grace_kick > 0 && dash_dir_y == -1 {
				if get_check_wall(dir) {
					action_dashjump_wall(_kh, dir);
				} else if get_check_wall(-dir) {
					action_dashjump_wall(_kh, -dir);
				}
			} else {
				if get_check_wall(1) || get_check_wall(-1) {
					action_walljump();
				}
			}
		}
	}
	
	var _kh_p = INPUT.check_pressed("right") - INPUT.check_pressed("left");
	
	ledge_buffer_dir_timer -= 1;
	if _kh_p != 0 {
		ledge_buffer_dir = _kh_p;
		ledge_buffer_dir_timer = 4;
	}
	
	if y_vel <= -1 && _kh != 0 {
		ledge_key = _kh;
	}
	if y_vel > -1 {
		if (
			!onground && get_check_wall(_kh, 1) && !INPUT.check("down")
		) && (
			(ledge_buffer_dir_timer > 0 && ledge_buffer_dir == dir) ||
			ledge_key == dir
		) {
			ledge_buffer_dir_timer = 0;
			ledge_key = 0;
			state.change(state_ledge);
			return;
		} else {
			if y_vel > 2 {
				ledge_key = 0;
			}
		}
	}
	
});

state_ledge = state_base.add()
.set("enter", function(){
	ledge_stick = 1;
})
.set("leave", function(){
	ledge_stick = 0;
})
.set("step", function() {
	
	var _kh = INPUT.check("right") - INPUT.check("left");
	var _kv = INPUT.check("down") - INPUT.check("up");
	
	x_vel = dir;
	
	y_vel = 0;
	if !actor_collision(x + dir, y - 22) {
		y_vel = 1
	} else {
		if !actor_collision(x + dir, y - 20) {
			y_vel = -1
		}
	}
	
	if buffer_dash > 0 && dash_left > 0 {
		state.change(state_dash);
		return;
	}
	
	if buffer_jump > 0 {
		action_walljump();
		state.change(state_free);
		return;
	}
	
	if !get_check_wall(dir, 1) {
		x_vel += get_lift_x();
		y_vel += get_lift_y();
		state.change(state_free);
		return;
	}
	if onground {
		x_vel += get_lift_x();
		y_vel += get_lift_y();
		state.change(state_free);
		return;
	}
	
	if _kh != dir {
		ledge_stick -= 1;
	} else {
		ledge_stick = 4;
	}
	if _kh != dir && ledge_stick <= 0 {
		x_vel += get_lift_x();
		y_vel += get_lift_y();
		state.change(state_free);
		return;
	}
	
});


action_dash_end = function() {
	
	dash_dir_x_vel = x_vel;
	dash_dir_y_vel = y_vel;
	
	x_vel = max(abs(x_vel), defs.move_speed) * sign(x_vel);
	
	if dash_dir_y == 0 {
		// side dash
		x_vel = lerp(abs(x_vel), abs(dash_pre_x_vel), 0.8) * sign(x_vel);
		y_vel = 0;
		
		hold_jump = true;
		hold_jump_vel = defs.terminal_vel;
		hold_jump_timer = 12;
		
		key_force = dash_dir_x;
		key_force_timer = 3;
	} else if dash_dir_y == -1  {
		// up dash
		x_vel = lerp(abs(x_vel), abs(dash_pre_x_vel), 0.7) * sign(x_vel);
		
		hold_jump = true;
		hold_jump_vel = defs.terminal_vel;
		hold_jump_timer = 28;
		
		key_force = dash_dir_x;
		key_force_timer = 5;
	} else {
		// dive dash + down dash
		x_vel = lerp(abs(x_vel), abs(dash_pre_x_vel), 0.2) * sign(x_vel);
	}
	
};

state_dash = state_base.add()
.set("enter", function() {
	
	game_set_pause(3);
	
	buffer_dash = 0;
	dash_left = max(0, dash_left - 1);
	
	dash_pre_x_vel = x_vel;
	dash_pre_y_vel = y_vel;
	
	dash_dir_x = 0;
	dash_dir_y = 0;
	
	dash_dir_x_vel = 0;
	dash_dir_y_vel = 0;
	
	x_vel = 0;
	y_vel = 0;
	
	dash_timer = 6;
	dash_frame = 0; // this is stupid
	dash_grace = 15;
	dash_recover = 9;
	
})
.set("leave", function() {
	
	if get_can_uncrouch() {
		nat_crouch(false);
	}
	
})
.set("step", function() {
	
	var _kh = INPUT.check("right") - INPUT.check("left");
	var _kv = INPUT.check("down") - INPUT.check("up");
	
	if dash_frame == 0 {
		
		if _kh != 0 {
			dir = _kh;
		}
		
		if _kh == 0 && _kv == 0 {
			dash_dir_x = dir;
		} else {
			dash_dir_x = _kv == 1 ? _kh : dir;
		}
		dash_dir_y = _kv;
		
		if dash_dir_x != 0 {
			dir = dash_dir_x;
		}
		
		var _dir = point_direction(0, 0, dash_dir_x, dash_dir_y);
		
		x_vel = abs(dash_pre_x_vel);
		if dash_dir_x == sign(dash_pre_x_vel) {
			x_vel *= 0.4;
		} else {
			if dash_dir_y == -1 {
				x_vel *= 0.7;
			} else {
				x_vel *= 0.9;
			}
		}
		x_vel += abs(lengthdir_x(7, _dir));
		x_vel = max(abs(x_vel), abs(dash_pre_x_vel)) * sign(dash_dir_x);
		
		y_vel = 0;
		y_vel += lengthdir_y(7, _dir);
		if dash_dir_y == -1 {
			dash_grace_kick = 24;
			y_vel *= 0.7;
		}
	}
	
	if buffer_jump > 0 {
		if grace > 0 {
			if _kh != dir && dash_timer <= 3 {
				action_dash_end();
				action_dashjump(_kh == 0 && dash_dir_y == 1 ? dir : _kh);
				state.change(state_free);
				return;
			} else if _kh == dir {
				action_dash_end();
				action_dashjump(_kh);
				state.change(state_free);
				return;
			}
		} else {
			if get_check_wall(dir) {
				action_dash_end();
				if dash_dir_y == -1 {
					action_dashjump_wall(_kh, dir);
				} else {
					action_walljump();
				}
				state.change(state_free);
				return;
			}
			if _kh != dir && dash_timer <= 2 {
				action_dash_end();
				action_dashjump(_kh == 0 && dash_dir_y == 1 ? dir : _kh);
				state.change(state_free);
				return;
			}
		}
	}
	
	dash_frame += 1;
	dash_timer -= 1;
	if dash_timer <= 0 {
		action_dash_end();
		state.change(state_free);
		return;
	}
	
});

state_menu = state_base.add()
.set("enter", function(){
	with obj_menu system.open(page_none);
})
.set("step", function(){
	x_vel = approach(x_vel, 0, defs.move_accel);
	y_vel = approach(y_vel, defs.terminal_vel, defs.gravity);
	
	buffer_dash = 0;
	buffer_jump = 0;
	
	with obj_menu system.update();
	
	if array_length(obj_menu.system.stack) == 0 {
		obj_menu.system.stop();
		state.change(state_free);
		return;
	}
	
	if !place_meeting(x, y, obj_checkpoint) {
		obj_menu.system.stop();
		state.change(state_free);
		return;
	}
	
});

squish = function() {
	game_player_kill();
};

riding = function(_solid) {
	return place_meeting(x, y + 1, _solid) ||
		(state.is(state_ledge) && place_meeting(x + dir, y, _solid));
};

cam = function(_out) {
	
	if (state.is(state_free) && actor_collision(x, y + 1)) {
		cam_ground_x = x + dir * 64;
		cam_ground_y = y - 32;
	}
	
	var _dist = point_distance(cam_ground_x, cam_ground_y, x, y);
	
	var _x = x + power(abs(x_vel), 1.4) * sign(x_vel);
	var _y = y - 32;
	
	/*
	if state.is(state_menu) {
		_x += 48 + (array_length(menu.stack) - 1) * 12;
		_y += -4;
	}*/
	
	_out.x = lerp(cam_ground_x, _x, 1 - max(0, 1 - power(_dist / 64, 2)) * 0.0);
	_out.y = lerp(cam_ground_y, _y, 1 - max(0, 1 - power(_dist / 128, 2)) * 0.8);
	
}

outside = function() { return false; };


state.change(state_free);

