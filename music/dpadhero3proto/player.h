.ifndef PLAYER_H
.define PLAYER_H

; Why the magic number 40? Because the health meter has 40 "slots" (half-hearts)
ENERGY_MAX .equ (40*4-1)

.struc player_state
difficulty .db[2] ; 0 = easy, 1 = normal, 2 = hard
speed_level .db[2]
credit .db[2]
unlocked_songs .db[2]
completed_challenges .db[6] ; 8 challenges (bits) per song
last_completed_challenges .db[2]
new_completed_challenges .db[2]
won_credit .db[2]
acquired_pad_pieces .db[2]
life_count .db[2]
energy_level .db[2]
final_energy_level .db[2]
vu_level .db[2]
letter_index .db[2]
points_level .db[2]
score .db[3*2]
checkpoint_score .db[3*2]
top_score .db[3*2]
current_streak .dw[2]
longest_streak .dw[2]
missed_count .dw[2]
hit_count .dw[2]
err_count .dw[2]
acquired_letters .db[2]
skull_hit_count .db[2]
pow_hit_count .db[2]
star_hit_count .db[2]
clock_hit_count .db[2]
fake_skull_hit_count .db[2]
heart_spawn_count .db[2]
skull_miss_count .db[2]
pow_miss_count .db[2]
star_miss_count .db[2]
clock_miss_count .db[2]
fake_skull_miss_count .db[2]
beat_game .db[2]
.ends

.extrn player:player_state

.endif
