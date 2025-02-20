.include <common/joypad.h>
.include <common/ldc.h>
.include <common/ppu.h>
.include <common/progbuf.h>
.include <common/ptr.h>
.include <common/sprite.h>
.include "player.h"
.include "target.h"

.dataseg zeropage

game_type .db

selected_song .db

play_count .dw

; 0 = normal time, 1 = bullet time
time_mode .db
.public time_mode

; 0 = full length, 1 = clip
play_mode .db

clip_index .db

displayed_energy_level .db[2]

display_letter_index .db

damage_blink_counter .db
screen_shake_counter .db

; 0 - normal, 1 - dead, 2 - done
game_state .db

transition_timer .db
bullet_timer .db

; Number of targets until the next heart should be spawned
heart_spawn_counter .db
HEART_SPAWN_INTERVAL .equ 32
spawned_heart_state .db

; Damage levels
miss_damage .db
error_damage .db
skull_damage .db

; Holds mapping from virtual to physical button, for 2 players.
button_mapping .byte[5*2]
.public button_mapping

; The extent of the vertical area where hits are acknowledged, in pixels.
hit_extent .db
; The Y position where the hit area begins.
hit_start_y .db

; Mask of the lanes mapped to each player.
player_lanes .db[2]

normal_target_attributes .db[5]

; Calculated each frame from joypad input.
lane_input_posedge .db[2]
lane_input .db[2]

LOCKED_LANES_MAX .equ 2

lockable_lanes .db
locked_lanes .db
locked_lane_timers .db[5]

; Pointer to the data that describes targets+timings
target_data .ptr ; 0044
target_data_bit_ctr .db
target_data_bits .db

; linked lists
free_targets_list .db
active_targets_head .db
active_targets_tail .db
hit_targets_head .db
hit_targets_tail .db
missed_targets_head .db
missed_targets_tail .db

.public free_targets_list
.public active_targets_head
.public active_targets_tail

TARGET_DATA_DELAY_WIDTH .equ 3 ; number of bits for delay

target_data_speed .db  ; frames per data timer decrement
target_data_timer .db
should_load_targets .db
target_data_chunk_length .db ; Number of targets per progress increment

begin_song_timer .dw ; 004A

target_song .db
target_song_order_skip .db
target_song_row_skip .db

; The player's state.
player .player_state
.public player

stat_changed .db ; b0: score, b1: top score, b2: progress, b3: energy, b4: lives, b5: points level, b6: letters

progress_level .db
progress_countdown .db

moving_bg_column .db
moving_bg_offset .db

selected_menu_item .db

lane_switch_request .db
lane_switcher_offset .db

speed_bump_request .db

; temp variables
powable_lanes .db
saved_muted_channels .db
was_music_paused .db
tmp .db
checked_lanes .db
hit_lanes .db
hittable_lanes .db
error_lanes .db[2]
prev .db
menu_row .db
menu_col .db

; division-related
; ### move to its own file
AC0 .db  ; initial dividend & resulting quotient
AC1 .db
AC2 .db
XTND0 .db  ; remainder
XTND1 .db
XTND2 .db
AUX0 .db  ; divisor
AUX1 .db
AUX2 .db
TMP0 .db
Count .db

.public AC0
.public AC1
.public AC2
.public AUX0
.public AUX1
.public AUX2

.dataseg

; array of targets, used to populate the linked list
targets_1 .target_1[MAX_TARGETS]
targets_2 .target_2[MAX_TARGETS]
.public targets_1
.public targets_2

.codeseg

;.define DEBUG_TARGET_DATA_TIMER

.public game_init
.public game_handler

.extrn prng:proc
.extrn start_song:proc
.extrn maybe_start_song:proc
.extrn pause_music:proc
.extrn unpause_music:proc
.extrn is_music_paused:proc
.extrn set_pattern_row_callback:proc
.extrn global_transpose:byte
.extrn mixer_get_muted_channels:proc
.extrn mixer_set_muted_channels:proc
.extrn start_sfx:proc
.extrn copy_bytes_to_ppu_buffer:proc
.extrn bitmasktable:label
.extrn frame_count:byte
.extrn ppu_buffer_offset:byte
.extrn ppu_buffer:label
.extrn begin_ppu_string:proc
.extrn end_ppu_string:proc
.extrn put_ppu_string_byte:proc
.extrn reset_timers:proc
.extrn start_timer:proc
.extrn set_timer_callback:proc
.extrn reset:label

.extrn song_:label

target_data_table:
; Bank, song, song start delay, data pointers
.db 0, 1, 44, 20, 15, 12, 10, 8, 7, 6 : .dw song_, song_, song_

; Reads the next N bits from the target data stream.
; In: A = number of bits to read (1..8)
; Out: A = value of N bits (upper bits zero)
; Destroys: Y
.proc read_target_data_bits
    tay
    lda #0 ; output will be shifted into here
    @@read_one_bit:
    dec target_data_bit_ctr
    bpl +
    ; reset counter, read next byte
    pha
    tya
    pha
    lda #7
    sta target_data_bit_ctr
    ldy #0
    lda [target_data],y
    sta target_data_bits
    inc target_data.lo
    bne ++
    inc target_data.hi
 ++ pla
    tay
    pla
  + asl target_data_bits
    rol
    dey
    bne @@read_one_bit
    rts
.endp

.proc fetch_target_data_byte
    lda #8
    jmp read_target_data_bits
.endp

target_data_timer_table:
.db 1,2,4,8,12,16,24,32

.proc init_begin_song_timer_lo
    lda time_mode
    lsr
    lda target_data_speed
    bcc +
    asl
  + sta begin_song_timer+1
    rts
.endp

.proc maybe_begin_song
    lda begin_song_timer+0
    ora begin_song_timer+1
    bne +
    rts
  + ; jsr maybe_seek_to_target_pattern TODO
    dec begin_song_timer+1
    beq +
    rts
  + lda begin_song_timer+0
    cmp #4
    bne +
    lda target_song
    jsr start_song
    jsr pause_music
  + jsr on_pattern_row_change
    dec begin_song_timer+0
    beq +
    jmp init_begin_song_timer_lo
  + jsr unpause_music
    ldcay on_pattern_row_change
    jmp set_pattern_row_callback
.endp

.proc game_init ; E0A5
; TODO
;    jsr wipeout
    jsr screen_off
    jsr reset_timers

    ldx #4 ; player 1
    jsr set_default_button_mapping
    ldx #9 ; player 2
    jsr set_default_button_mapping

.ifdef MMC
.if MMC == 3
    lda #16 : sta chr_banks[0]
    lda #18 : sta chr_banks[1]
    lda #20 : sta chr_banks[2]
    lda #21 : sta chr_banks[3]
    lda #22 : sta chr_banks[4]
    lda #23 : sta chr_banks[5]
.endif
.endif

 ; TODO
 ;   lda #5
 ;   jsr swap_bank ; for game ui data
 ;   ldcay game_ui_data
 ;   jsr write_ppu_data_at
 ;   ldcay pad3d_data
 ;   jsr write_ppu_data_at

 ;   ldcay game_palette
 ;   jsr load_palette

    lda #0
    sta selected_song

    jsr initialize_target_lists

;    lda #2
;    sta game_type

    ; reset stats
.if 0
    lda player.checkpoint_score+0
    sta player.score+0
    lda player.checkpoint_score+1
    sta player.score+1
    lda player.checkpoint_score+2
    sta player.score+2
.endif
    lda #0
    sta player.score+0
    sta player.score+1
    sta player.score+2
    sta player.current_streak+0
    sta player.current_streak+1
    sta player.longest_streak+0
    sta player.longest_streak+1
    sta player.missed_count+0
    sta player.missed_count+1
    sta player.hit_count+0
    sta player.hit_count+1
    sta player.err_count+0
    sta player.err_count+1
    sta player.acquired_letters
    sta player.skull_hit_count
    sta player.pow_hit_count
    sta player.star_hit_count
    sta player.clock_hit_count
    sta player.fake_skull_hit_count
    sta player.heart_spawn_count
    sta player.skull_miss_count
    sta player.pow_miss_count
    sta player.star_miss_count
    sta player.clock_miss_count
    sta player.fake_skull_miss_count
    sta player.points_level
    sta player.vu_level
    sta player.letter_index
    sta progress_level
    sta lockable_lanes
    sta locked_lanes
    sta spawned_heart_state
    sta stat_changed
    sta global_transpose
    sta time_mode
    sta bullet_timer
    sta display_letter_index
    sta damage_blink_counter
    sta screen_shake_counter
    sta lane_switch_request
    sta speed_bump_request
    lda #$FF
    sta lane_switcher_offset
    lda #HEART_SPAWN_INTERVAL
    sta heart_spawn_counter
    lda player.difficulty
    sta player.speed_level

    ; damage levels
    lda #3 : sta miss_damage
    lda #2 : sta error_damage
    lda #6 : sta skull_damage

    lda play_mode
    beq +
    ; in clip mode, bump speed and double damage levels
    inc player.speed_level
    asl miss_damage
    asl error_damage
    asl skull_damage

  + jsr game_type_init

    jsr inc_play_count

    lda #0
    sta game_state

;    lda #2
;    sta player.difficulty

;    lda #6
;    sta player.speed_level

;    lda #1
;    sta time_mode

    jsr sync_hit_area

;    lda #1
;    sta play_mode

    lda play_mode
    beq +
    ldy player.difficulty
; TODO
    lda #0
;    lda @@clip_mode_chunk_lengths,y
;    sta target_data_chunk_length
;    sta progress_countdown
;    lda clip_index
;    asl : tay
;    lda clips+0,y
;    sta selected_song
;    lda clips+1,y ; marker
  + jsr init_target_data

    ldcay @@tilemap_data
    jsr write_ppu_data_at

    lda #0
    jsr mixer_set_muted_channels
    lda #0
    jsr start_song ; mute
    jmp screen_on

.charmap "song.tbl"
@@tilemap_data:
.incbin "gameboyskintilemap.bin"
.db $20,$00,$60,$00
.db $20,$20,$60,$00
.db $23,$00,$01,$00
.db $23,$1C,$65,$00
.db $23,$58,$49,$00
.db $23,$78,$68,$00
.db $23,$80,$60,$00
.db $23,$A0,$60,$00
; packnam --width=20 --vram-address=0x2086 packchr.nam
.incbin "gamescreentilemap.bin"
; attribute data
.db $23,$D0,$01,$40 ; battery indicator
.db $23,$C9,$01,$88 ; play field
.db $23,$CA,$44,$AA ; play field
.db $23,$CE,$01,$22 ; play field
.db $23,$D1,$01,$88 ; play field
.db $23,$D2,$44,$AA ; play field
.db $23,$D6,$01,$22 ; play field
.db $23,$D9,$01,$88 ; play field
.db $23,$DA,$44,$AA ; play field
.db $23,$DE,$01,$22 ; play field
.db $23,$E1,$01,$88 ; play field
.db $23,$E2,$44,$AA ; play field
.db $23,$E6,$01,$22 ; play field
.db $23,$E9,$01,$08 ; play field
.db $23,$EA,$44,$0A ; play field
.db $23,$EE,$01,$02 ; play field
.db 0

.char "MADE BY KENT HANSEN" : .db 0
.endp

.proc inc_play_count
    inc play_count+0
    bne +
    inc play_count+1
  + rts
.endp

.proc initialize_target_lists
    lda #$FF
    sta active_targets_head
    sta active_targets_tail
    sta hit_targets_head
    sta hit_targets_tail
    sta missed_targets_head
    sta missed_targets_tail
    ldx #0
    stx free_targets_list
  - txa
    clc
    adc #sizeof target_1
    sta targets_2.next,x
    tax
    cpx #(sizeof target_1 * (MAX_TARGETS-1))
    bne -
    lda #$FF
    sta targets_2.next,x
    rts
.endp

; Destroys: A, Y
.proc sync_hit_area
    ; set hit pos and extent according to speed level
    ldy player.speed_level
    lda @@hit_extent_table,y
    sta hit_extent
    lda @@hit_start_y_table,y
    sta hit_start_y
    rts
@@hit_extent_table:
.db 20,21,22,23,24,28,32,34
@@hit_start_y_table:
.db 154,153,152,151,150,149,148,147
.endp

; A = marker (0 = beginning)
.proc init_target_data ; E195
    pha
    lda selected_song
;    lda #2
    asl : asl : asl : asl ; each entry is 16 bytes
    tay
    lda target_data_table+1,y
    sta target_song

    tya
    ora player.speed_level
    tax
    lda target_data_table+2,x ; delay until song is started
    pha
    lda target_data_table+0,y ; 16K bank to load @ $8000
    pha

    ; set target data pointer based on difficulty
    tya
    clc
    adc player.difficulty
    adc player.difficulty
    tay
    lda target_data_table+10,y
    sta target_data.lo
    lda target_data_table+11,y
    sta target_data.hi

    lda #0
    sta target_data_bit_ctr

    pla
; TODO
;    jsr swap_bank

    ; Target data header: speed (1 byte), chunk length (1 byte)
    jsr fetch_target_data_byte
    sta target_data_speed
    jsr fetch_target_data_byte
    ldx play_mode
    bne +
    sta target_data_chunk_length
    sta progress_countdown

  + lda #1
    sta target_data_timer

    lda #0
    jsr mixer_set_muted_channels
    ; the song is started later, to be in sync with the target data
    pla
    sta begin_song_timer+0
    jsr init_begin_song_timer_lo

    pla ; marker
    tax
    ; data base pointer
    jsr fetch_target_data_byte
    pha ; low
    jsr fetch_target_data_byte
    pha ; hi

    ; marker data
    txa
    asl : asl : tay
    lda [target_data],y ; offset low
    sta tmp
    iny
    lda [target_data],y ; offset high
    pha
    iny
    lda [target_data],y ; order start
    sta target_song_order_skip
    iny
    lda [target_data],y ; pattern row start
    sta target_song_row_skip
    pla
    sta target_data.hi
    lda tmp
    sta target_data.lo

    ; divide by 8 (since the offset is in bits)
    lsr target_data.hi
    ror target_data.lo
    lsr target_data.hi
    ror target_data.lo
    lsr target_data.hi
    ror target_data.lo

    ; add base pointer
    pla ; hi
    tax
    pla ; lo
    clc
    adc target_data.lo
    sta target_data.lo
    txa
    adc target_data.hi
    sta target_data.hi

    lda tmp
    and #7
    beq +
    jsr read_target_data_bits
  + rts
.endp

; Initialization that's specific to the game type.
.proc game_type_init
    ; for 1-player, target attributes are fixed
    ; for 2-player, they must be in sync with lane mapping
    lda #0
    sta normal_target_attributes+0 ; left
    sta normal_target_attributes+1 ; right
    ldx game_type
    bne +
    lda #2 ; 1 player: middle targets always yellow
  + sta normal_target_attributes+2 ; middle
    lda #3
    sta normal_target_attributes+3 ; B
    sta normal_target_attributes+4 ; A

    lda #ENERGY_MAX
    sta player.energy_level+0
    sta displayed_energy_level+0
    ldx game_type
    cpx #2 ; versus?
    beq +
    lda #0
  + sta player.energy_level+1
    sta displayed_energy_level+1

    cpx #2
    beq + ; no score in versus
; TODO
;    jsr print_score
; TODO
;.ifndef NO_TOP_SCORE
;    jsr print_top_score
;.endif
; TODO
;.ifdef LIFE_SUPPORT
;    jsr print_life_count
;.endif

  + lda game_type
    beq @@one_player_init

    ; 2 players
    lda #%00111
    sta player_lanes+0 ; player 1 lanes
    lda #%11000
    sta player_lanes+1 ; player 2 lanes

    lda game_type
    cmp #1
    beq @@write_normal_interface
    ; versus
    ; who starts with middle lane is determined by play count
    lda play_count : and #2 : asl
    eor player_lanes+0
    sta player_lanes+0
    and #4 : eor #4
    eor player_lanes+1
    sta player_lanes+1
    lda play_count : and #1
    beq +
    ; swap the lanes
    lda player_lanes+0
    eor #%11111
    sta player_lanes+0
    lda player_lanes+1
    eor #%11111
    sta player_lanes+1
  + jsr sync_normal_target_attributes
; TODO
    rts
;    lda #$10
;    sta palette+5 ; gray instead of dark green
;    ldcay @@versus_interface_data
;    jmp write_ppu_data_at

    @@one_player_init:
    lda #%11111
    sta player_lanes+0 ; player 1 lanes
    lda #%00000
    sta player_lanes+1 ; player 2 lanes
    @@write_normal_interface:
; TODO
;    ldcay @@normal_interface_data
;    jmp write_ppu_data_at
    rts
.endp

; X = 4 or 9
.proc set_default_button_mapping
    ldy #4
  - lda @@mapping,y
    sta button_mapping,x
    dex
    dey
    bpl -
    rts
@@mapping:
; LEFT, RIGHT, SELECT, B, A
.db 1, 0, 5, 6, 7
.endp

.if 0
.proc set_emu_button_mapping
    ldy #4
  - lda @@mapping,y
    sta button_mapping,x
    dex
    dey
    bpl -
    rts
@@mapping:
; B, A, SELECT, LEFT, RIGHT
.db 6, 7, 5, 1, 0
.endp

.proc set_guitar_button_mapping
    ldy #4
  - lda @@mapping,y
    sta button_mapping,x
    dex
    dey
    bpl -
    rts
@@mapping:
.db 7, 6, 5, 0, 1
.endp
.endif

; Y = lane index (0..4)
; Destroys: A, X
.proc draw_lane_indicator
    ; left half
    jsr next_sprite_index
    tax
    lda #41
    sta sprites.tile,x
    lda lane_slot_y_coords,y
    sta sprites._y,x
    lda lane_slot_x_coords,y
    sta sprites._x,x
    lda #2
    sta sprites.attr,x
    ; right half
    jsr next_sprite_index
    tax
    lda #41+2
    sta sprites.tile,x
    lda lane_slot_y_coords,y
    sta sprites._y,x
    lda lane_slot_x_coords,y
    clc
    adc #8
    sta sprites._x,x
    lda #2
    sta sprites.attr,x
    rts
.endp

lane_slot_x_coords:
; LEFT, RIGHT, SELECT, B, A
.db 80,96,112,128,144
lane_slot_y_coords:
.db 158,158,158,158,158

; Puts sprites that show which of the lanes are "pressed".
.proc draw_pressed_lanes
; TODO
;    lda game_mode
;    beq + ; only draw buttons if we're in play mode
;    rts
;  +
    ldy #4
  - lda lane_input+0
    ora lane_input+1
    and bitmasktable,y
    beq +
    jsr draw_lane_indicator
  + dey
    bpl -
    rts
.endp

.proc on_pattern_row_change
    dec target_data_timer
.ifdef DEBUG_TARGET_DATA_TIMER
    php
    txa : pha
    tya : pha
    jsr print_target_data_timer
    pla : tay
    pla : tax
    plp
.endif
    beq +
    rts
  + lda #1
    sta should_load_targets
    rts
.endp

.proc maybe_load_targets
    lda should_load_targets
    bne +
    rts
  + lda #0
    sta should_load_targets
    jmp process_target_data
.endp

; X = offset of target being added
; Destroys: A, Y
.proc add_to_active_targets_list
    lda #$FF
    sta targets_2.next,x
    ldy active_targets_tail
    stx active_targets_tail
    cpy #$FF
    bne +
    stx active_targets_head
    rts
  + txa
    sta targets_2.next,y
    rts
.endp

; Adds a target.
; A = lane (bits 2..0), type (bits 5..3)
; Y = duration
; Returns: X = offset of added target
.proc add_target
; grab target from free list
    pha
    ldx free_targets_list
    cpx #$FF
    bne +
    ; fatal, no more free targets
    jmp reset
  + lda targets_2.next,x
    sta free_targets_list
    pla
; initialize the target
    sta targets_1.state,x
    tya
    sta targets_2.duration,x
    lda #0
    sta targets_1.pos_y.frac,x
    sta targets_1.pos_x.frac,x
    lda #24    ; initial Y position
    sta targets_1.pos_y.int,x
    lda targets_1.state,x
    and #7
    tay
    lda @@initial_x,y
    sta targets_1.pos_x.int,x
    ; X speed
    lda #0
    sta targets_2.speed_x.frac,x
    sta targets_2.speed_x.int,x
    ; Y speed
    lda player.speed_level
    asl
    tay
    lda @@speed_y_table+0,y
    sta targets_2.speed_y.int,x
    lda @@speed_y_table+1,y
    sta targets_2.speed_y.frac,x
    jmp add_to_active_targets_list
; LEFT, RIGHT, SELECT, B, A
    @@initial_x:
    .db 80,96,112,128,144

@@speed_y_table:
.db $01,$00 ; 1.0
.db $01,$80 ; 1.5
.db $02,$00 ; 2.0
.db $02,$80 ; 2.5
.db $03,$00 ; 3.0
.db $03,$80 ; 3.5
.db $04,$00 ; 4.0
.db $04,$80 ; 4.5
.endp

; Reads cue data and adds targets to lanes accordingly.
; Sets the timer for the next data processing.
.proc process_target_data
    lda #4
    jsr read_target_data_bits ; difficulty level
    cmp #$0E
    bcc @@process_row
    beq @@end_of_clip
    ; 0F = end of data
    lda #0
    sta target_data.lo
    sta target_data.hi
    rts

    @@end_of_clip:
    lda play_mode
    beq process_target_data ; ignore if not in clip mode
    lda #0
    sta target_data.lo
    sta target_data.hi
    rts

    @@process_row:
    ora #0
    beq ++ ; just a delay, no targets
    jsr prng
    and #$0f
    bne +
    ora #1
  + cmp #12
    bcc ++
    sbc #4
 ++ tay
    lda @@lanes_specifier_mask,y
    ldx #0
    @@lane_loop:
    lsr
    bcc @@next
    pha ; save lanes mask
    txa ; lane index
    pha
    ; TODO - in boss mode, it becomes a skull (ora #$08) -- unless it is a lane switcher
    ldy #1 ; duration
    jsr add_target
    lda lane_switch_request
    beq @@done_adding
    pla ; lane index
    pha
    cmp #2 ; lane switcher only occurs in middle lane
    bne @@done_adding
    stx lane_switcher_offset ; this is the lane switcher target!
    lda #0
    sta lane_switch_request
    @@done_adding:
    pla
    tax ; restore lane index
    pla ; restore lanes mask
    @@next:
    inx
    cpx #5
    bne @@lane_loop

    dec progress_countdown
    bne @@set_next_delay
    inc progress_level
; TODO
;    jsr maybe_request_lane_switch
;    jsr maybe_request_speed_bump
    lda stat_changed
    ora #4
    sta stat_changed
    lda target_data_chunk_length
    sta progress_countdown

    @@set_next_delay:
    lda #TARGET_DATA_DELAY_WIDTH
    jsr read_target_data_bits
    tay
    lda target_data_timer_table,y
    ldy speed_bump_request
    beq +
    sta tmp
    lda #0
    sta speed_bump_request
    ; Add the difference between next speed level and this one,
    ; in order to keep the target data in sync.
    lda selected_song
    asl : asl : asl : asl ; * 16
    ora player.speed_level
    inc player.speed_level
    tay
    lda target_data_table+2,y
    sec
    sbc target_data_table+3,y
    clc : adc tmp
    pha
    jsr sync_hit_area
; TODO
;    jsr play_speed_bump_sfx
    pla
  + sta target_data_timer
.ifdef DEBUG_TARGET_DATA_TIMER
    jmp print_target_data_timer
.else
    rts
.endif

@@lanes_specifier_mask:
.db %00000 ; 0 - none
.db %00001 ; 1 - left
.db %00010 ; 2 - right
.db %01000 ; 3 - B
.db %10000 ; 4 - A
.db %01001 ; 5 - left + B
.db %10001 ; 6 - left + A
.db %01010 ; 7 - right + B
.db %10010 ; 8 - right + A
.db %11000 ; 9 - B + A
.db %11001 ; 10 - left + B + A
.db %11010 ; 11 - right + B + A
.endp

.ifdef DEBUG_TARGET_DATA_TIMER
.proc print_target_data_timer
    lda target_data_timer : sta AC0
    lda #0 : sta AC1 : sta AC2
    ldx #2 : lda #$20 : ldy #$9B
    jmp print_value
.endp
.endif

.proc toggle_time_mode
    lda time_mode
    eor #1
    sta time_mode
    lda global_transpose
    eor #$F4
    sta global_transpose
    jsr is_music_paused
    sta was_music_paused
    bne +
    jsr pause_music
  + jsr mixer_get_muted_channels
    sta saved_muted_channels
    lda #$1F
    jsr mixer_set_muted_channels
    lda time_mode
    ora #4
    ldx #4
    jsr start_sfx
    lda #80
    sta transition_timer
    rts
.endp

; Counts number of 1 bits in A.
; Returns: X=number of 1 bits
; Destroys: A, Y
.proc count_bits
    ldy #7
    ldx #0
  - lsr
    bcc +
    inx
  + dey
    bpl -
    rts
.endp

; X = player (0 or 1)
.proc check_for_errors
    lda hittable_lanes
    and player_lanes,x
    eor lane_input_posedge,x
    and lane_input_posedge,x
    sta error_lanes,x
    lda locked_lanes
    ora lockable_lanes
    eor #$FF
    and error_lanes,x
    sta error_lanes,x
    bne +
    rts
  + jsr deal_error_pain
    jsr inc_error_count
    jsr reset_points_level
    jsr reset_streak
    jsr dec_vu_level
    rts
.endp

; The most important piece of game logic.
; Finds out which targets are hittable and hit,
; explodes hit targets unless no errors (cheating),
; updates stats.
; Moves missed targets to missed list.
.proc process_active_targets
    lda #0
    sta checked_lanes
    sta hittable_lanes
    sta hit_lanes
    lda #$FF
    sta prev
    ldy active_targets_head

    @@loop:
    cpy #$FF ; end of list?
    bne @@do_target

    ldx #0
    jsr check_for_errors
    ldx #1
    jsr check_for_errors
    jmp sweep_active_targets

    @@do_target:
    jsr draw_target
    jsr move_target

    lda targets_1.state,y
    and #7 ; lane
    tax
    lda bitmasktable,x
    and checked_lanes
    beq +
    jmp @@next ; we already checked this lane, target can't possible be within hit range
  + lda bitmasktable,x
    ora checked_lanes
    sta checked_lanes
    ; not hittable, hittable or missed?
    lda targets_1.pos_y.int,y
    sec
    sbc hit_start_y
    bcc @@next ; not hittable
    sbc hit_extent
    bcs @@missed

    ; it's hittable
    lda bitmasktable,x
    ora hittable_lanes
    sta hittable_lanes
    ; is it actually hit?
    lda lane_input_posedge+0
    and bitmasktable,x
    bne @@hit_by_player_1
  - lda lane_input_posedge+1
    and bitmasktable,x
    bne @@hit_by_player_2
    ; if the lane is locked, hit anyway unless it's a skull
 -- lda bitmasktable,x
    and locked_lanes
    beq @@next
    lda targets_1.state,y
    and #$38 ; type
    cmp #$08
    beq @@next
    bne @@hit

    @@hit_by_player_1:
    lda player_lanes+0
    and bitmasktable,x
    beq - ; ignore, player 1 does not control this lane
    jmp @@hit

    @@hit_by_player_2:
    lda player_lanes+1
    and bitmasktable,x
    beq -- ; ignore, player 2 does not control this lane

    @@hit:
    lda bitmasktable,x
    ora hit_lanes
    sta hit_lanes

    @@next:
    lda targets_2.next,y
    sty prev
    tay
    jmp @@loop

    @@missed:
    lda targets_1.state,y
    and #$38 ; type
    beq @@miss_normal
    cmp #$08
    beq @@miss_skull
    cmp #$10
    beq @@miss_pow
    cmp #$18
    beq @@miss_star
    cmp #$20
    beq @@miss_clock
    cmp #$28
    beq @@miss_letter
    cmp #$30
    beq @@miss_fake_skull

    @@miss_skull:
    ; TODO - in boss mode, hurt the player!
    jmp @@move_to_missed_list

    @@miss_pow:
    inc player.pow_miss_count
    jmp @@move_to_missed_list

    @@miss_star:
    inc player.star_miss_count
    jmp @@move_to_missed_list

    @@miss_clock:
    inc player.clock_miss_count
    jmp @@move_to_missed_list

    @@miss_letter:
    jmp @@move_to_missed_list

    @@miss_fake_skull:
    inc player.fake_skull_miss_count
    tya : pha
    lda #13 : ldx #4
    jsr start_sfx
    pla : tay
    jmp @@move_to_missed_list

    @@miss_normal:
    ; missing a normal target is punished - if player(s) alive
    lda player.energy_level+0
    beq @@move_to_missed_list
    lda game_type
    eor #2
    ora player.energy_level+1 ; versus && player 2 dead
    beq @@move_to_missed_list
    cpy lane_switcher_offset
    bne +
    ; fake a hit, to enable automatic lane switch
    lda #4 ; middle lane mask
    ora hit_lanes
    sta hit_lanes
    lda #$FF
    sta lane_switcher_offset
    jsr switch_player_lane_mapping
    jmp @@next

  + jsr inc_missed_count
    jsr reset_points_level
    jsr reset_streak
    jsr dec_vu_level

    ldx #0 ; default: 1st player
    lda game_type
    cmp #2 ; versus?
    bne +
    ; in versus mode, hurt player is determined by lane
    lda targets_1.state,y
    and #7 ; lane
    tax
    jsr player_for_lane
  + lda miss_damage
    jsr sub_energy_with_pain

    ; turn off the sound channel
    jsr mixer_get_muted_channels
    ora #3
    jsr mixer_set_muted_channels

    @@move_to_missed_list:
    lda targets_2.next,y
    pha
    lda #$FF
    sta targets_2.next,y
    ldx missed_targets_tail
    sty missed_targets_tail
    cpx #$FF
    bne +
    sty missed_targets_head
    jmp ++
  + tya
    sta targets_2.next,x
 ++ pla
    ldx prev
    cpy active_targets_tail
    bne +
    stx active_targets_tail
  + tay
    cpx #$FF
    bne +
    sty active_targets_head
    jmp @@loop
  + sta targets_2.next,x
    jmp @@loop
.endp

; In: X = lane index
; Out: X = player
.proc player_for_lane
    lda bitmasktable,x
    ldx #0
    and player_lanes+0
    bne +
    inx
  + rts
.endp

; X = player (0 or 1)
.proc deal_error_pain
    ldy #0
    @@loop:
    lda bitmasktable,y
    and error_lanes,x
    beq @@next
    lda error_damage
    jsr sub_energy_with_pain
    @@next:
    iny
    cpy #5
    bne @@loop
    rts
.endp

; process_active_targets() helper function.
; Explodes active targets that were hit and moves them to the hit list.
.proc sweep_active_targets
    lda #$FF
    sta prev
    ldy active_targets_head
    @@loop:
    lda hit_lanes
    bne @@check_target
    rts

    @@check_target:
    lda targets_1.state,y
    and #7 ; lane
    tax
    lda bitmasktable,x
    and hit_lanes
    bne @@hit_target
    lda targets_2.next,y
    sty prev
    tay
    jmp @@loop

    @@hit_target:
    lda bitmasktable,x
    eor #$FF
    and hit_lanes
    sta hit_lanes

    ; type determines what happens
    lda targets_1.state,y
    and #$38 ; type
    bne +
    jmp  @@hit_normal
  + cmp #$08
    beq @@hit_skull
    cmp #$10
    beq @@hit_pow
    cmp #$18
    beq @@hit_star
    cmp #$20
    beq @@hit_clock
    cmp #$28
    beq @@hit_letter
    cmp #$30
    beq @@hit_fake_skull

    @@hit_skull:
    inc player.skull_hit_count
    ; TODO - in boss mode, always subtract from 2nd player (boss), and shake screen
    ; @@hit_bad:
    lda targets_1.state,y
    and #7 ; lane
    tax
    jsr player_for_lane
    lda skull_damage
    jsr sub_energy_with_pain
    jmp @@loop

    @@hit_pow:
    lda #8
    jsr shake_screen
    inc player.pow_hit_count
    jsr sync_powable_lanes
    tya : pha
    lda #1: ldx #4
    jsr start_sfx
    pla : tay
    jmp pow_active_targets

    @@hit_star:
    inc player.star_hit_count
    lda #0
    sta locked_lanes
    lda #%11111
    sta lockable_lanes
    tya : pha
    lda #10: ldx #4
    jsr start_sfx
    pla : tay
    jmp @@explode_in_place

    @@hit_clock:
    inc player.clock_hit_count
    lda time_mode
    bne +
    tya
    pha
    jsr toggle_time_mode
    pla
    tay
  + jmp @@explode_in_place

    @@hit_letter:
    ldx player.letter_index
    cpx #8
    bcs + ; it's really an error in the mapping, there shouldn't be more than eight
    lda bitmasktable,x
    ora player.acquired_letters
    sta player.acquired_letters
    inc player.letter_index
    lda stat_changed
    ora #$40
    sta stat_changed
    tya : pha
    lda #12 : ldx #4
    jsr start_sfx
    pla : tay
  + jmp @@explode_in_place

    @@hit_fake_skull:
    inc player.fake_skull_hit_count
    tya : pha
    lda #11 : ldx #4
    jsr start_sfx
    pla : tay
    jmp @@explode_in_place

    @@hit_normal:
    ; TODO - in boss mode, hitting normal targets is bad
    ; jmp @@hit_bad
    jsr on_normal_target_hit
    cpy lane_switcher_offset
    bne +
    lda #$FF
    sta lane_switcher_offset
    jsr switch_player_lane_mapping
    jmp @@explode_in_place
  + lda game_type
    cmp #2 ; 2 player versus?
    beq @@explode_in_place ; if so, no hearts ever spawned
    lda targets_1.state,y
    and #7 ; lane
    tax
    jsr maybe_spawn_heart

    @@explode_in_place:
    lda #158
    sta targets_1.pos_y,y
    jsr explode_target
    jmp @@loop
.endp

; Y = offset of POW target
.proc sync_powable_lanes
    lda game_type
    cmp #2 ; versus?
    beq +
    ; in 1-player and co-op, all lanes are POWable
    lda player_lanes+0
    ora player_lanes+1
    sta powable_lanes
    rts
    ; in versus, only the lanes of the player that
    ; hit the POW are POWable
  + lda targets_1.state,y
    and #7 ; lane
    tax
    jsr player_for_lane
    lda player_lanes,x
    sta powable_lanes
    rts
.endp

; sync attributes based on player 1 mapping
; (mapped to player 1 is blue, otherwise red)
; Destroys: A, X
.proc sync_normal_target_attributes
    lda player_lanes
    ldx #0
  - pha
    and #1 : eor #1 : cmp #1 : rol ; 0 or 3
    sta normal_target_attributes,x
    pla
    lsr
    inx
    cpx #5
    bne -
    rts
.endp

.proc switch_player_lane_mapping
.if 0
    ; "random" switch (makes it very difficult)
    lda player_lanes+0
    and #4
    pha
    lda frame_count
  - and #7
    cmp #6
    bcc +
    sbc #6
  + tax
    lda @@player_1_lanes,x
    cmp player_lanes+0
    bne +
    inx
    txa
    jmp -
  + sta player_lanes+0
    lda @@player_2_lanes,x
    sta player_lanes+1
    pla
    pha
    ora player_lanes+1
    sta player_lanes+1
    pla
    eor #4
    ora player_lanes+0
    sta player_lanes+0
.else
    lda player_lanes+0
    eor #%11111
    sta player_lanes+0
    lda player_lanes+1
    eor #%11111
    sta player_lanes+1
.endif
    jsr sync_normal_target_attributes
    ; play switch SFX
    tya : pha
    lda #6 : ldx #4
    jsr start_sfx
    pla : tay
    rts
.if 0
@@player_1_lanes:
.db %00011
.db %11000
.db %01001
.db %10010
.db %10001
.db %01010
@@player_2_lanes:
.db %11000
.db %00011
.db %10010
.db %01001
.db %01010
.db %10001
.endif
.endp

.proc on_normal_target_hit
    lda player.energy_level
    bne +
    rts ; dead, don't care
    ; turn on the sound channel
  + jsr mixer_get_muted_channels
    and #$FC
    jsr mixer_set_muted_channels

    ; increase stats
    jsr inc_hit_count
    jsr inc_streak
    lda player.current_streak+0
    and #3
    bne +
    jsr inc_vu_level
  + lda game_type
    cmp #2 ; versus?
    bne +
    rts
    ; inc score
  + tya
    pha
    lda player.points_level
    asl
    tax
    lda @@scores+1,x
    tay
    lda @@scores+0,x
    jsr add_score
    pla
    tay
    rts

    @@scores:
    .dw 25, 50, 75, 100
.endp

; Explodes target with offset in Y.
; Variable prev must contain the offset of the previous target,
; or $FF if it's the head of the list.
; Destroys: A, X, Y
.proc explode_target
    lda targets_1.state,y
    ora #$80 ; bit 7 indicates that the target is exploded (used by draw routine)
    and #~$38 ; clear type bits
    sta targets_1.state,y
    ; move to hit list
    lda targets_2.next,y
    pha
    lda #$FF
    sta targets_2.next,y
    ldx hit_targets_tail
    sty hit_targets_tail
    cpx #$FF
    bne +
    sty hit_targets_head
    jmp ++
  + tya
    sta targets_2.next,x
 ++ pla ; next
    ldx prev
    cpy active_targets_tail
    bne +
    stx active_targets_tail
  + tay
    cpx #$FF
    bne +
    sty active_targets_head
    rts
  + sta targets_2.next,x
    rts
.endp

.proc pow_active_targets
    lda #$FF
    sta prev
    ldy active_targets_head
    @@loop:
    cpy #$FF ; end of list?
    bne +
    rts
  + lda targets_1.state,y
    and #$38 ; type
    cmp #$28
    bcc +
    ; don't pow letters and fake skulls
    @@skip:
    lda targets_2.next,y
    sty prev
    tay
    jmp @@loop
  + ora #0
    bne +
    cpy lane_switcher_offset
    beq @@skip
    lda targets_1.state,y
    and #7 ; lane
    tax
    lda bitmasktable,x
    and powable_lanes
    beq @@skip
    jsr on_normal_target_hit
  + jsr explode_target
    ; Y contains next pointer
    jmp @@loop
.endp

; Draws a target.
; Y = offset of target to draw
.proc draw_target
; left half
    jsr next_sprite_index
    tax
    lda targets_1.pos_x.int,y
    sta sprites._x,x
    lda targets_1.pos_y.int,y
    sta sprites._y,x
    lda targets_1.state,y
    bpl + ; jump if not exploding
    and #$70
    lsr : lsr ; explosion frame * 4
    adc #45
    jmp ++
  + lda targets_1.state,y
    and #7 ; lane
    asl
    asl ; lane * 4
    adc #$01
 ++ sta sprites.tile,x
    tya
    pha
    lda targets_1.state,y
    bmi + ; jump if exploding
    and #$38 ; type
    beq +
    ; for special types, the attributes are determined by the type
    lsr
    lsr
    lsr
    tay
    lda @@special_type_attributes-1,y
    jmp ++
  + lda targets_1.state,y
    and #7 ; lane
    tay
    lda normal_target_attributes,y ; TODO: highlight if hittable
 ++ sta sprites.attr,x
    pla
    tay
; right half
    jsr next_sprite_index
    tax
    lda targets_1.pos_x.int,y
    clc
    adc #8
    sta sprites._x,x
    lda targets_1.pos_y.int,y
    sta sprites._y,x
    lda targets_1.state,y
    bpl + ; jump if not exploding
    and #$70
    lsr : lsr ; explosion frame * 4
    adc #45+2
    jmp ++
  + lda targets_1.state,y
    and #7 ; lane
    asl
    asl ; lane * 4
    adc #$03
 ++ sta sprites.tile,x
    tya
    pha
    lda targets_1.state,y
    bmi + ; jump if exploding
    and #$38 ; type
    beq +
    ; for special types, the attributes are determined by the type
    lsr
    lsr
    lsr
    tay
    lda @@special_type_attributes-1,y
    jmp ++
    ; for normal targets, the attributes are determined by lane number
    ; -- unless it's a lane switch indicator, which is always 2
  + cpy lane_switcher_offset
    bne +
    lda #2
    bne ++
  + lda targets_1.state,y
    and #7
    tay
    lda normal_target_attributes,y ; TODO: highlight if hittable
 ++ sta sprites.attr,x
    pla
    tay
    rts

@@special_type_attributes:
.db 3 ; skull
.db 3 ; POW
.db 2 ; star
.db 0 ; clock
.db 1 ; letter
.db $80 | 0 ; fake skull
.endp

; Moves a target.
; Y = offset of target to move
.proc move_target
    lda time_mode
    beq +

    ; temporarily divide speed by two
    lda targets_2.speed_y.int,y
    cmp #$80
    ror
    sta targets_2.speed_y.int,y
    lda targets_2.speed_y.frac,y
    ror
    sta targets_2.speed_y.frac,y
    lda targets_2.speed_x.int,y
    cmp #$80
    ror
    sta targets_2.speed_x.int,y
    lda targets_2.speed_x.frac,y
    ror
    sta targets_2.speed_x.frac,y

    ; Y
  + lda targets_1.pos_y.frac,y
    clc
    adc targets_2.speed_y.frac,y
    sta targets_1.pos_y.frac,y
    lda targets_1.pos_y.int,y
    adc targets_2.speed_y.int,y
    sta targets_1.pos_y.int,y
    ; X
    lda targets_1.pos_x.frac,y
    clc
    adc targets_2.speed_x.frac,y
    sta targets_1.pos_x.frac,y
    lda targets_1.pos_x.int,y
    adc targets_2.speed_x.int,y
    sta targets_1.pos_x.int,y

    lda time_mode
    beq +
    ; restore speed (multiply by 2)
    lda targets_2.speed_y.frac,y
    asl
    sta targets_2.speed_y.frac,y
    lda targets_2.speed_y.int,y
    rol
    sta targets_2.speed_y.int,y
    lda targets_2.speed_x.frac,y
    asl
    sta targets_2.speed_x.frac,y
    lda targets_2.speed_x.int,y
    rol
    sta targets_2.speed_x.int,y
  + rts
.endp

.proc process_hit_targets
    lda #$FF
    sta prev
    ldy hit_targets_head
    @@loop:
    cpy #$FF
    bne +
    rts
  + jsr draw_target
    lda frame_count
    lsr
    bcc +
    lda targets_1.state,y
    and #$70
    cmp #$70 ; reached last frame?
    beq @@evaporated
    lda targets_1.state,y
    clc
    adc #$10 ; advance to next frame
    sta targets_1.state,y
  + lda targets_2.next,y
    tay
    jmp @@loop

    @@evaporated:
    lda targets_2.next,y
    pha
    ; put on free list
    lda free_targets_list
    sta targets_2.next,y
    sty free_targets_list
    pla
    ; remove from hit targets list
    cpy hit_targets_tail
    bne +
    sta hit_targets_tail
  + tay
    ldx prev
    cpx #$FF
    bne +
    sty hit_targets_head
    jmp @@loop
  + sta targets_2.next,x
    jmp @@loop
.endp

.proc process_missed_targets
    lda #$FF
    sta prev
    ldy missed_targets_head
    @@loop:
    cpy #$FF
    bne +
    rts
  + jsr draw_target
    jsr move_target

    lda targets_1.pos_y.int,y
    cmp #160
    bcs @@fell_off
    lda targets_2.next,y
    sty prev
    tay
    jmp @@loop

    @@fell_off:
    lda targets_2.next,y
    pha
    ; put on free list
    lda free_targets_list
    sta targets_2.next,y
    sty free_targets_list
    pla
    ; remove from missed targets list
    cpy missed_targets_tail
    bne +
    sta missed_targets_tail
  + tay
    ldx prev
    cpx #$FF
    bne +
    sty missed_targets_head
    jmp @@loop
  + sta targets_2.next,x
    jmp @@loop
.endp

.proc inc_hit_count
    inc player.hit_count+0
    bne +
    inc player.hit_count+1
  + rts
.endp

.proc inc_missed_count
    inc player.missed_count+0
    bne +
    inc player.missed_count+1
  + rts
.endp

.proc inc_error_count
    inc player.err_count+0
    bne +
    inc player.err_count+1
  + rts
.endp

.proc inc_streak
    inc player.current_streak+0
    bne +
    inc player.current_streak+1
  + lda game_type
    cmp #2 ; versus?
    beq + ; no points level
    lda player.current_streak+1
    bne +
    lda player.current_streak+0
    cmp #8
    beq @@inc_points_level
    cmp #16
    beq @@inc_points_level
    cmp #24
    bne +
    @@inc_points_level:
    inc player.points_level
    lda stat_changed
    ora #$20
    sta stat_changed
  + jmp sync_longest_streak
.endp

.proc sync_longest_streak
    lda player.longest_streak+0
    sec
    sbc player.current_streak+0
    lda player.longest_streak+1
    sbc player.current_streak+1
    bcs +
; new longest streak
    lda player.current_streak+0
    sta player.longest_streak+0
    lda player.current_streak+1
    sta player.longest_streak+1
  + rts
.endp

.proc reset_points_level
    lda #0
    sta player.points_level
    lda stat_changed
    ora #$20
    sta stat_changed
    rts
.endp

.proc reset_streak
    lda #0
    sta player.current_streak+0
    sta player.current_streak+1
    rts
.endp

.proc inc_vu_level
    lda player.vu_level
    cmp #12
    bcs +
    inc player.vu_level
  + rts
.endp

.proc dec_vu_level
    lda player.vu_level
    beq +
    dec player.vu_level
  + rts
.endp

; A = amount
; X = player (0 or 1)
.proc sub_energy
    eor #$FF
    clc
    adc #1
    adc player.energy_level,x
    bcs @@set
    lda player.energy_level,x
    bne @@set_zero
    rts ; already dead
    @@set_zero:
    lda #0
    @@set:
    sta player.energy_level,x
    lda stat_changed
    ora #8
    sta stat_changed
    rts
.endp

; A = amount
; X = player (0 or 1)
.proc sub_energy_with_pain
    jsr sub_energy
    lda #4
    sta damage_blink_counter
    tya : pha
    txa : pha
    lda #7 : ldx #4
    jsr start_sfx
    pla : tax
    pla : tay
    rts
.endp

.proc add_energy
    clc
    adc player.energy_level
    bcs @@clip
    cmp #ENERGY_MAX
    bcc @@set
    @@clip:
    lda #ENERGY_MAX
    @@set:
    sta player.energy_level
    lda stat_changed
    ora #8
    sta stat_changed
    rts
.endp

.proc sub_score
    eor #$FF
    clc
    adc #1
    adc player.score+0
    sta player.score+0
    lda player.score+1
    adc #$FF
    sta player.score+1
    lda player.score+2
    adc #$FF
    sta player.score+2
    bcs +
    lda #0
    sta player.score+0
    sta player.score+1
    sta player.score+2
  + lda stat_changed
    ora #1
    sta stat_changed
    rts
.endp

; Adds number in A,Y to score.
; Destroys: A, Y
.proc add_score
    clc
    adc player.score+0
    sta player.score+0
    tya
    adc player.score+1
    sta player.score+1
    lda #0
    adc player.score+2
    sta player.score+2
    beq +
    cmp #$02
    bcs ++
    lda player.score+1
    cmp #$86
    bcc +
    bne ++
    lda player.score+0
    cmp #$A0
    bcc +
    ; clamp
 ++ lda #$9F : sta player.score+0
    lda #$86 : sta player.score+1
    lda #$01 : sta player.score+2
  + lda game_type
    cmp #2 ; versus?
    bne +
    rts
  + lda stat_changed
    ora #1
    sta stat_changed
;    lda game_mode
;    beq + ; only sync the top score if we're in play mode
;    rts
;  +
    ; ### possibly award extra life
.ifndef NO_TOP_SCORE
    jmp sync_top_score
.else
    rts
.endif
.endp

.ifndef NO_TOP_SCORE
.proc sync_top_score
    lda player.top_score
    sec
    sbc player.score
    lda player.top_score+1
    sbc player.score+1
    lda player.top_score+2
    sbc player.score+2
    bcs +
; new top score
    lda player.score
    sta player.top_score
    lda player.score+1
    sta player.top_score+1
    lda player.score+2
    sta player.top_score+2
    lda stat_changed
    ora #2
    sta stat_changed
  + rts
.endp
.endif

.proc draw_vu_pin
    ldy player.vu_level
    lda @@sprite_data_offsets,y
    tay
  - lda @@sprite_data+0,y
    bne +
    rts
  + jsr next_sprite_index
    tax
    lda @@sprite_data+0,y
    sta sprites._y,x
    lda @@sprite_data+1,y
    sta sprites.tile,x
    lda @@sprite_data+2,y
    sta sprites.attr,x
    lda @@sprite_data+3,y
    sta sprites._x,x
    iny
    iny
    iny
    iny
    jmp -
    @@sprite_data_offsets:
    .db @@l0-@@sprite_data
    .db @@l1-@@sprite_data
    .db @@l2-@@sprite_data
    .db @@l3-@@sprite_data
    .db @@l4-@@sprite_data
    .db @@l5-@@sprite_data
    .db @@l6-@@sprite_data
    .db @@l7-@@sprite_data
    .db @@l8-@@sprite_data
    .db @@l9-@@sprite_data
    .db @@l10-@@sprite_data
    .db @@l11-@@sprite_data
    .db @@l12-@@sprite_data
    @@sprite_data:
    @@l0:
    .db 170-99,$D7,0,194
    .db 170-99,$D9,0,194+8
    .db 170-99,$DB,0,194+16
    .db 0
    @@l1:
    .db 167-99,$DD,0,195
    .db 167-99,$DF,0,195+8
    .db 167-99,$E1,0,195+16
    .db 0
    @@l2:
    .db 163-99,$D1,0,198
    .db 163-99,$D3,0,198+8
    .db 163-99+8,$D5,0,198+16
    .db 0
    @@l3:
    .db 161-99,$E3,0,202
    .db 161-99+8,$E5,0,202+8
    .db 0
    @@l4:
    .db 160-99,$E7,0,205
    .db 160-99+16,$E9,0,205+8
    .db 0
    @@l5:
    .db 160-99,$EB,0,210
    .db 160-99+16,$ED,0,210
    .db 0
    @@l6:
    .db 159-99,$EF,0,215
    .db 159-99+16,$F1,0,215
    .db 0
    @@l7:
    .db 160-99,$EB,$40+0,210+3
    .db 160-99+16,$ED,$40+0,210+3
    .db 0
    @@l8:
    .db 160-99,$E7,$40+0,205+13
    .db 160-99+16,$E9,$40+0,205+13-8
    .db 0
    @@l9:
    .db 161-99,$E3,$40+0,202+19
    .db 161-99+8,$E5,$40+0,202+19-8
    .db 0
    @@l10:
    .db 163-99,$D1,$40+0,198+27
    .db 163-99,$D3,$40+0,198+27-8
    .db 163-99+8,$D5,$40+0,198+27-16
    .db 0
    @@l11:
    .db 167-99,$DD,$40+0,195+33
    .db 167-99,$DF,$40+0,195+33-8
    .db 167-99,$E1,$40+0,195+33-16
    .db 0
    @@l12:
    .db 170-99,$D7,$40+0,196+33
    .db 170-99,$D9,$40+0,196+33-8
    .db 170-99,$DB,$40+0,196+33-16
    .db 0
.endp

.proc draw_points_level_indicator
    lda player.points_level
    asl
    tay
    lda @@points_level_indicator_data_table+0,y
    pha
    lda @@points_level_indicator_data_table+1,y
    tay
    pla
    ldx #10
    jmp copy_bytes_to_ppu_buffer

@@points_level_indicator_data_table:
.dw @@points_level_0_data
.dw @@points_level_1_data
.dw @@points_level_2_data
.dw @@points_level_3_data
@@points_level_0_data:
.db $21,$7A,$02,$00,$00
.db $21,$9A,$02,$00,$00
@@points_level_1_data:
.db $21,$7A,$02,$BC,$BE
.db $21,$9A,$02,$BD,$BF
@@points_level_2_data:
.db $21,$7A,$02,$BC,$C0
.db $21,$9A,$02,$BD,$C1
@@points_level_3_data:
.db $21,$7A,$02,$BC,$C2
.db $21,$9A,$02,$BD,$C3
.endp

.proc update_points_level_indicator
    lda stat_changed
    and #$20
    bne +
    rts
  + lda stat_changed
    and #~$20
    sta stat_changed
    jmp draw_points_level_indicator
.endp

.ifdef LIFE_SUPPORT
.proc update_lives_display
    lda stat_changed
    and #$10
    bne +
    rts
  + lda stat_changed
    and #~$10
    sta stat_changed
    jmp print_life_count
.endp

.proc print_life_count
    ldy #$20 : lda #$68 : ldx #1
    jsr begin_ppu_string
    lda player.life_count
    ora #$D0
    jsr put_ppu_string_byte
    jmp end_ppu_string
.endp
.endif

.proc update_score_displays
    lda stat_changed
    lsr
    bcs @@update_score
.ifndef NO_TOP_SCORE
    lsr
    bcs @@update_top_score
.endif
    rts
    @@update_score:
    asl
    sta stat_changed
    jmp print_score
.ifndef NO_TOP_SCORE
    @@update_top_score:
    lda stat_changed
    and #~2
    sta stat_changed
    jmp print_top_score
.endif
.endp

.proc print_score
    lda player.score+0 : sta AC0
    lda player.score+1 : sta AC1
    lda player.score+2 : sta AC2
    ldx #5 : lda #$20 : ldy #$4E
    jmp print_value
.endp

.ifndef NO_TOP_SCORE
.proc print_top_score
    lda player.top_score+0 : sta AC0
    lda player.top_score+1 : sta AC1
    lda player.top_score+2 : sta AC2
    ldx #6 : lda #$20 : ldy #$59
    jmp print_value
.endp
.endif

; AC0, AC1, AC2 = value to print
; X = # of digits to output
; A = PPU high address
; Y = PPU low address
.proc print_value
    stx     Count
    ldx     ppu_buffer_offset
    sta     ppu_buffer,x
    inx
    tya
    sta     ppu_buffer,x
    inx
    lda     Count
    sta     ppu_buffer,x
    inx
    lda     #10
    sta     AUX0
    lda     #0
    sta     AUX1
    sta     AUX2
    ldy     Count
    cpy     #0
    bne     +
    ; figure out how many digits to print
  - iny
    cpy     #7
    beq     +
    lda     AC0
    sec
    sbc     @@DecPos0-1,y
    lda     AC1
    sbc     @@DecPos1-1,y
    lda     AC2
    sbc     @@DecPos2-1,y
    bcs     -
  + sty     Count
  - jsr     divide
    lda     XTND0
    pha
    dey
    bne     -
  - pla
    clc
    adc     #$C5
    sta     ppu_buffer,x
    inx
    iny
    cpy     Count
    bne     -
    jmp     end_ppu_string
@@DecPos0:
.db $0A,$64,$E8,$10,$A0,$40
@@DecPos1:
.db $00,$00,$03,$27,$86,$42
@@DecPos2:
.db $00,$00,$00,$00,$01,$0F
.endp

.proc divide
    txa
    pha
    tya
    pha
    ldy #24      ; bitwidth
    lda #0
    sta XTND0
    sta XTND1
    sta XTND2
  - asl AC0      ;DIVIDEND/2, CLEAR QUOTIENT BIT
    rol AC1
    rol AC2
    rol XTND0
    rol XTND1
    rol XTND2
    lda XTND0    ;TRY SUBTRACTING DIVISOR
    sec
    sbc AUX0
    sta TMP0
    lda XTND1
    sbc AUX1
    tax
    lda XTND2
    sbc AUX2
    bcc +    ;TOO SMALL, QBIT=0
    stx XTND1    ;OKAY, STORE REMAINDER
    sta XTND2
    lda TMP0
    sta XTND0
    inc AC0      ;SET QUOTIENT BIT = 1
  + dey          ;NEXT STEP
    bne -
    pla
    tay
    pla
    tax
    rts
.endp

; TODO: grows from bottom to top
.proc update_progress_display
    lda stat_changed
    and #4
    bne +
    rts
  + lda stat_changed
    and #~4
    sta stat_changed
    lda progress_level
    cmp #41
    bcc +
    rts
  + sec
    sbc #1
    lsr
    clc
    adc #$6B
    ldx game_type
    cpx #2 ; versus?
    bcc +
    sbc #$40 ; 2 rows up
  + ldy #$20
    ldx #$01 ; 1 tile
    jsr begin_ppu_string
    lda progress_level
    and #1 ; odd or even
    clc
    adc #$0D
    jsr put_ppu_string_byte
    jmp end_ppu_string
.endp

.proc update_energy_display
    lda stat_changed
    and #8
    bne +
    rts
  + lda stat_changed
    and #~8
    sta stat_changed
    ldy #0
    jsr update_player_energy_meter
    lda game_type
    cmp #2 ; versus?
    beq +
    rts
  + ldy #1
    jmp update_player_energy_meter
.endp

; Y = player (0 or 1)
.proc update_player_energy_meter
    lda player.energy_level,y
    cmp displayed_energy_level,y
    bcc @@less

    lda player.energy_level,y
    clc : adc #4
    sec
    sbc displayed_energy_level,y
    lsr : lsr : lsr
    beq @@draw_last

    ; fill full hearts on the left
    ora #$40 ; set RLE bit
    tax
    tya : pha ; save player index
    lda displayed_energy_level,y
    clc : adc #1
    lsr : lsr : lsr
    clc : adc #$6B
    cpy #0
    beq +
    clc : adc #$20
  + ldy game_type
    cpy #2
    beq +
    clc : adc #$20
  + ldy #$20
    jsr begin_ppu_string
    lda #$0A ; full heart
    jsr put_ppu_string_byte
    jsr end_ppu_string
    pla : tay ; restore player index
    jmp @@draw_last

    @@less:
    lda displayed_energy_level,y
    clc
    adc #7
    cmp #ENERGY_MAX
    bcc +
    lda #ENERGY_MAX
  + sec
    sbc player.energy_level,y
    lsr : lsr : lsr
    beq @@draw_last

    ; fill empty hearts on the right
    ora #$40 ; set RLE bit
    tax
    tya : pha ; save player index
    lda player.energy_level,y
    clc : adc #7
    lsr : lsr : lsr
    clc : adc #$6B
    cpy #0
    beq +
    clc : adc #$20
  + ldy game_type
    cpy #2
    beq +
    clc : adc #$20
  + ldy #$20
    jsr begin_ppu_string
    lda #$0C ; empty heart
    jsr put_ppu_string_byte
    jsr end_ppu_string
    pla : tay ; restore player index

    @@draw_last:
    tya : pha ; save player index
    lda player.energy_level,y
    lsr : lsr : lsr
    clc : adc #$6B
    cpy #0
    beq +
    clc : adc #$20
  + ldy game_type
    cpy #2
    beq +
    clc : adc #$20
  + ldy #$20 : ldx #$01
    jsr begin_ppu_string
    pla : tay ; restore player index
    pha ; save player index
    lda player.energy_level,y
    ldy #$0C ; empty heart
    and #7
    beq +
    dey      ; half heart
    cmp #5
    bcc +
    dey      ; full heart
  + tya
    jsr put_ppu_string_byte
    jsr end_ppu_string
    pla : tay ; restore player index
    lda player.energy_level,y
    sta displayed_energy_level,y
    rts
.endp

.proc update_letters_display
    lda stat_changed
    and #$40
    bne +
    rts
  + lda stat_changed
    and #~40
    sta stat_changed

  - ldy display_letter_index
    cpy player.letter_index
    bcc +
    rts
  + lda @@offsets,y
    clc
    adc #$55
    ldx #1
    cpy #1
    bne +
    inx ; for the hyphen
  + ldy #$20
    jsr begin_ppu_string
    ldy display_letter_index
    cpy #1
    bne +
    lda #$8F ; '-'
    jsr put_ppu_string_byte
  + lda @@tiles,y
    jsr put_ppu_string_byte
    jsr end_ppu_string
    inc display_letter_index
    bne -

@@offsets:
.db 0,1,3,4,6,7,8,9
@@tiles:
.db $99,$9A,$9B,$99,$9C,$9D,$9E,$9F
.endp

.proc check_pause
    lda joypad0_posedge
    and #JOYPAD_BUTTON_START
    bne @@pause
    rts
    @@pause:
; TODO
;    lda #0 : ldy #27
;    jsr set_fade_range
;    jsr palette_to_temp_palette
;    jsr fade_out_step

    jsr is_music_paused
    sta was_music_paused
    bne +
    jsr pause_music
  + jsr mixer_get_muted_channels
    sta saved_muted_channels
    lda #$1F
    jsr mixer_set_muted_channels

    lda #3 : ldx #0
    jsr start_sfx

    lda #0
    sta selected_menu_item

    ; TODO
    ; inc main_cycle ; game_paused_main
    ; pla : pla ; skip the rest of the game loop!
    rts
.endp

.proc game_paused_main
    jsr reset_sprites
;    jsr draw_vu_pin
;    jsr draw_pause_menu
;    jsr draw_all_targets
    jmp check_pause_input
.endp

.proc check_pause_input
    lda joypad0_posedge
    and #(JOYPAD_BUTTON_START) ; | JOYPAD_BUTTON_A)
    bne @@select_menu_item

.if 0
    lda joypad0_posedge
    and #(JOYPAD_BUTTON_UP | JOYPAD_BUTTON_DOWN)
    bne @@change_menu_item
.endif
    rts

.if 0
    @@change_menu_item:
    lda joypad0_posedge
    and #JOYPAD_BUTTON_UP
    bne @@prev_item
    ; next item
    lda selected_menu_item
    cmp #2
    bcs +
    inc selected_menu_item
    lda #0 : ldx #0
    jsr start_sfx
  + rts
    @@prev_item:
    lda selected_menu_item
    beq +
    dec selected_menu_item
    lda #0 : ldx #0
    jsr start_sfx
  + rts
.endif
    @@select_menu_item:
    ldy selected_menu_item
    beq @@unpause
.if 0
    dey
    beq @@restart
    jmp @@quit
.endif

    @@unpause:
; TODO
;    jsr write_palette
    lda was_music_paused
    bne +
    jsr unpause_music
  + lda saved_muted_channels
    jsr mixer_set_muted_channels
; TODO
;    dec main_cycle ; game main
    rts

.if 0
    @@restart:
    lda #0
    jsr mixer_set_muted_channels
    lda #0 ; no song
    jsr start_song
    jsr unpause_music

; TODO
;    lda #0
;    sta main_cycle
    lda #7
    ldy #7
    jsr start_timer
    ldcay @@really_restart
    jsr set_timer_callback
; TODO
;    lda #0
;    ldy #31
;    jsr set_fade_range
;    lda #7
;    jsr set_fade_delay
;    jmp start_fade_to_black
    rts

    @@quit:
    lda #0
    jsr mixer_set_muted_channels
    lda #0 ; no song
    jsr start_song
    jsr unpause_music

; TODO
;    lda #0
;    sta main_cycle
    lda #7
    ldy #7
    jsr start_timer
    ldcay @@really_quit
    jsr set_timer_callback
; TODO
;    lda #0
;    ldy #31
;    jsr set_fade_range
;    lda #7
;    jsr set_fade_delay
;    jmp start_fade_to_black
    rts

    @@really_restart:
; TODO
;    lda #7
;    sta main_cycle
    rts

    @@really_quit:
; TODO
;    lda #0
;    jsr swap_bank
;    lda #5
;    sta main_cycle
    rts
.endif
.endp

.if 0
.proc draw_pause_menu
    lda #0
    sta menu_row
    sta menu_col
    tay
  - lda @@text_data,y
    bne +
    iny
    lda @@text_data,y
    bne ++
    rts
 ++ inc menu_row
    lda #0
    sta menu_col
    jmp -
  + jsr next_sprite_index
    tax
    lda selected_menu_item
    cmp menu_row
    beq +
    clc
    bcc ++
  + sec
 ++ lda @@text_data,y
    bcs +
    adc #$20 ; dimmed
  + iny
    sta sprites.tile,x
    lda menu_row
    asl
    asl
    asl
    asl
    adc #96
    sta sprites._y,x
    lda #1
    sta sprites.attr,x
    lda menu_col
    asl
    asl
    asl
    adc #96
    sta sprites._x,x
    inc menu_col
    jmp -
    @@text_data:
.charmap "data/pausemenu.tbl"
.char "RESUME" : .db 0
.char "RESTART" : .db 0
.char "QUIT" : .db 0
.db 0
    rts
.endp
.endif

.proc check_if_done
    lda active_targets_head
    cmp #$FF
    beq +
    rts
  + lda hit_targets_head
    cmp #$FF
    beq +
    rts
  + lda missed_targets_head
    cmp #$FF
    beq +
    rts
  + lda target_data.lo
    ora target_data.hi
    beq +
    rts
    ; no more targets
  + jsr mixer_get_muted_channels
    and #$FC
    jsr mixer_set_muted_channels
    ldcay 0
    sta saved_muted_channels ; in case we are in bullet time
    jsr set_pattern_row_callback

    lda bullet_timer
    beq +
    ; make bullet time expire
    lda #1 : sta bullet_timer

  + lda game_type
    cmp #2 ; versus?
    bne +
    ; loop!
    ; wipe progress
    ldy #$20 : lda #$2B : ldx #$54
    jsr begin_ppu_string
    lda #$0F
    jsr put_ppu_string_byte
    jsr end_ppu_string
    lda target_data_chunk_length
    sta progress_countdown
    lda #0
    sta progress_level
    jsr init_target_data
    lda target_song
    jsr start_song
    jmp pause_music

  + lda play_mode
    beq +
    ; clip mode
    inc clip_index
    lda clip_index
    cmp #15 ; all clips played?
    beq +
    ; start next clip
    asl : tay
; TODO
;    lda clips+0,y
;    sta selected_song
;    lda clips+1,y ; marker
;    jsr init_target_data
    lda #0
    jsr mixer_set_muted_channels
; TODO
    rts
;    lda #16
;    jmp start_song

  + lda player.energy_level
    sta player.final_energy_level

    ; delay a bit
    lda #38 : ldy #6 ; ### customize delay for song?
    jsr start_timer
    ldcay @@add_points_for_energy
    jsr set_timer_callback
;    lda player.energy_level
;    ora #4
;    and #~3 ; ### CHECKME
;    sta player.energy_level
    lda #2
    sta game_state
    rts

    @@add_points_for_energy:
    lda #0
    jsr maybe_start_song ; mute
    lda player.energy_level
    beq @@done_adding_points_for_energy
    ldx #0
    lda #4
    jsr sub_energy
    ldy #0 : lda #100
    jsr add_score
    lda #3 : ldx #0
    jsr start_sfx
    lda #5 : ldy #1
    jsr start_timer
    ldcay @@add_points_for_energy
    jmp set_timer_callback

    @@done_adding_points_for_energy:
    lda #0
    sta time_mode
    sta global_transpose

    jsr compute_completed_challenges
    sta player.last_completed_challenges

    ; calculate new completed challenges
    ldy selected_song
    lda player.completed_challenges,y
    eor player.last_completed_challenges
    and player.last_completed_challenges
    sta player.new_completed_challenges

    ; calculate earned credit
    lda player.new_completed_challenges
    jsr count_bits
    stx player.won_credit

    ; delay a bit
    lda #12 : ldy #8
    jsr start_timer
    ldcay @@fade_out
    jmp set_timer_callback

    @@fade_out:
    lda #7 : ldy #7
    jsr start_timer
    ldcay @@goto_stats_screen
    jsr set_timer_callback
; TODO
    rts
;    lda #0 : ldy #31
;    jsr set_fade_range
;    lda #7
;    jsr set_fade_delay
;    jmp start_fade_to_black

    @@goto_stats_screen:
; TODO
;    lda #6
;    jsr swap_bank
;    lda #14
;    sta main_cycle
    rts
.endp

; Computes the set of challenges that were completed, based
; on the stats gathered from the game.
; Returns: A = set of completed challenges (1-bit = completed, 0-bit = not completed)
.proc compute_completed_challenges
    lda #0
    ; 1. Make it to the end: unconditonal
    sec
    ror

    ; 2. High scorer: player.score > rock score
    pha
    lda player.difficulty
    asl : asl : asl : asl : asl ; 8*4=32 bytes per difficulty
    adc selected_song ; four
    adc selected_song ; bytes
    adc selected_song ; per
    adc selected_song ; score
    tay
    lda player.score+0
    sec
    sbc rock_score_table+0,y
    lda player.score+1
    sbc rock_score_table+1,y
    lda player.score+2
    sbc rock_score_table+2,y
    pla
    ror

    ; 3. Streaker: player.longest_streak > 100
    pha
    lda player.longest_streak+0
    sec
    sbc #100
    lda player.longest_streak+1
    sbc #0
    pla
    ror

    ; 4. Letters: player.acquired_letters == FF
    pha
    lda player.acquired_letters
    cmp #$FF
    pla
    ror

    ; 5. 3 fake skulls: fake_skull_hit_count == 3
    pha
    lda player.fake_skull_hit_count
    cmp #3
    pla
    ror

    ; 6. Blow up all POWs: pow_miss_count == 0
    pha
    lda player.pow_miss_count
    eor #$FF
    cmp #$FF
    pla
    ror

    ; 7. No special items: pow_hit_count | star_hit_count | clock_hit_count == 0
    pha
    lda player.pow_hit_count
    ora player.star_hit_count
    ora player.clock_hit_count
    eor #$FF
    cmp #$FF
    pla
    ror

    ; 8. finish with full energy: energy_level == ENERGY_MAX
    pha
    lda player.final_energy_level
    cmp #(ENERGY_MAX-2) ; -2 because that level is displayed as a full heart
    pla
    ror
    rts

.endp

rock_score_table:
;   LED   LOVE  WHIP  FREE  DETH  LIFE
.dd 30000,20000,20000,20000,25000,25000,20000,20000 ; easy
.dd 50000,25000,30000,30000,30000,40000,30000,30000 ; normal
.dd 50000,30000,40000,35000,50000,50000,50000,50000 ; hard

; KILLME
.proc game_done_main
     rts
.endp

.proc show_stats
; IMPLEMENTME
    jmp reset
.endp

.proc update_moving_background_step
    lda moving_bg_column
    cmp #12
    bne +
    lda #0
    sta moving_bg_column
    inc moving_bg_offset
  + inc moving_bg_column
    asl : asl
    tay
    lda @@bg_data+2,y
    tax
    lda @@bg_data+1,y
    pha
    lda @@bg_data+0,y
    tay
    pla
    jsr begin_ppu_string
    lda moving_bg_offset
    and #7
    ora #$80
    jsr put_ppu_string_byte
    jmp end_ppu_string
@@bg_data:
.db $22,$6E,$C4,0
.db $22,$71,$C4,0
.db $22,$6D,$C4,0
.db $22,$72,$C4,0
.db $22,$8C,$C3,0
.db $22,$93,$C3,0
.db $22,$89,$C3,0
.db $22,$96,$C3,0
.db $22,$A8,$C2,0
.db $22,$B7,$C2,0
.db $22,$C7,$C1,0
.db $22,$D8,$C1,0
.endp

.proc update_moving_background
    jsr update_moving_background_step
    jsr update_moving_background_step
    jmp update_moving_background_step
.endp

.proc update_damage_blink
    lda damage_blink_counter
    bne +
    rts
  + cmp #4
    bne +
    ; start the blink - set palette red
    dec damage_blink_counter
    ldy #$3F : lda #$00 : ldx #$01
    jsr begin_ppu_string
    lda #$06
    jsr put_ppu_string_byte
    jmp end_ppu_string
  + dec damage_blink_counter
    beq +
    ; do nothing (palette remains red)
    rts
    ; end the blink - set palette black
  + ldy #$3F : lda #$00 : ldx #$01
    jsr begin_ppu_string
    lda #$0F
    jsr put_ppu_string_byte
    jmp end_ppu_string
.endp

; X = lane to spawn in
.proc maybe_spawn_heart
    dec heart_spawn_counter
    beq +
    rts
  + lda #HEART_SPAWN_INTERVAL
    sta heart_spawn_counter
    lda player.energy_level
    cmp #ENERGY_MAX
    bcc +
    rts
    ; spawn heart
  + inc player.heart_spawn_count
    txa
    ora #$80
    sta spawned_heart_state
    lda #8
    jsr add_energy
    tya : pha
    lda #6 : ldx #4
    jsr start_sfx
    pla : tay
    rts
.endp

.proc update_spawned_heart
    lda spawned_heart_state
    bmi +
    rts
  + and #7 ; lane
    tay
    jsr draw_big_heart
    lda frame_count
    and #7
    beq +
    rts
    ; next frame
  + lda spawned_heart_state
    and #$18 ; frame
    pha
    lda spawned_heart_state
    and #~$18
    sta spawned_heart_state
    pla
    clc
    adc #8 ; next frame
    and #$18
    php
    ora spawned_heart_state
    sta spawned_heart_state
    plp
    bne +
    ; next iteration
    lda spawned_heart_state
    and #$60 ; iteration
    pha
    lda spawned_heart_state
    and #~$60
    sta spawned_heart_state
    pla
    clc
    adc #$20 ; next iteration
    and #$60
    ora spawned_heart_state
    sta spawned_heart_state
  + lda spawned_heart_state
    and #$78
    cmp #$48
    bne +
    ; kill the heart
    lda #0
    sta spawned_heart_state
  + rts
.endp

.proc draw_big_heart
    ; left half
    jsr next_sprite_index
    tax
    lda spawned_heart_state
    and #$18
    lsr ; frame * 4
    ora #$C1
    pha
    sta sprites.tile,x
    lda spawned_heart_state
    and #$78
    lsr
    eor #$FF
    sec
    adc lane_slot_y_coords,y
    sec
    sbc #16
    sta sprites._y,x
    lda lane_slot_x_coords,y
    sta sprites._x,x
    lda #3
    sta sprites.attr,x
    ; right half
    jsr next_sprite_index
    tax
    pla
    ora #2
    sta sprites.tile,x
    lda spawned_heart_state
    and #$78
    lsr
    eor #$FF
    sec
    adc lane_slot_y_coords,y
    sec
    sbc #16
    sta sprites._y,x
    lda lane_slot_x_coords,y
    clc
    adc #8
    sta sprites._x,x
    lda #3
    sta sprites.attr,x
    rts
.endp

.proc get_player_1_input
    lda #0
    sta lane_input_posedge+0
    sta lane_input+0
    ldx #4
    @@lane_loop:
    lda button_mapping,x
    tay
    lda bitmasktable,y
    pha
    and joypad0_posedge
    beq +
    lda bitmasktable,x
    ora lane_input_posedge+0
    sta lane_input_posedge+0
  + pla
    and joypad0
    beq @@next_lane
    lda bitmasktable,x
    ora lane_input+0
    sta lane_input+0
    @@next_lane:
    dex
    bpl @@lane_loop
    rts
.endp

.proc get_player_2_input
    lda #0
    sta lane_input_posedge+1
    sta lane_input+1
    lda game_type
    bne +
    ; one-player, no points in reading 2nd input
    rts
  + ldx #4
    @@lane_loop:
    lda button_mapping+5,x
    tay
    lda bitmasktable,y
    pha
    and joypad1_posedge
    beq +
    lda bitmasktable,x
    ora lane_input_posedge+1
    sta lane_input_posedge+1
  + pla
    and joypad1
    beq @@next_lane
    lda bitmasktable,x
    ora lane_input+1
    sta lane_input+1
    @@next_lane:
    dex
    bpl @@lane_loop
    rts
.endp

.proc process_locked_lanes
    lda locked_lanes
    bne +
    rts
  + ldx #4
  - lda bitmasktable,x
    and locked_lanes
    beq +
    lda frame_count
    lsr
    bcc +
    dec locked_lane_timers,x
    bne +
    ; unlock
    lda bitmasktable,x
    eor #$FF
    and locked_lanes
    sta locked_lanes
  + dex
    bpl -
    rts
.endp

.proc process_lockable_lanes
    lda lockable_lanes
    bne +
    rts
  + ldx #4
    @@loop:
    lda lane_input_posedge+0
    ora lane_input_posedge+1
    and bitmasktable,x
    and lockable_lanes
    beq @@next
    ; lock it!
    ora locked_lanes
    sta locked_lanes
    lda bitmasktable,x
    eor #$FF
    and lockable_lanes
    sta lockable_lanes
    lda #$FF
    sta locked_lane_timers,x
    txa
    pha ; save lane index
;    lda #6 : ldx #4
;    jsr start_sfx
    lda locked_lanes
    jsr count_bits
    cpx #LOCKED_LANES_MAX
    bcc +
    ; no more lanes can be locked
    lda #0
    sta lockable_lanes
  + pla
    tax ; restore lane index
    @@next:
    dex
    bpl @@loop
    rts
.endp

.proc draw_lockable_lanes
    ldx #4
  - lda bitmasktable,x
    and lockable_lanes
    beq +
    txa
    lsr
    lda frame_count
    bcc ++
    eor #$08
 ++ and #$08
    beq +
    txa
    pha
    tay
    jsr draw_lane_indicator
    pla
    tax
  + dex
    bpl -
    rts
.endp

.proc draw_locked_lanes
    ldx #4
    @@loop:
    lda bitmasktable,x
    and locked_lanes
    beq @@next
    lda locked_lane_timers,x
    cmp #$30
    bcs @@draw
    ; blink when it's about to time out
    lda frame_count
    and #2
    beq @@next
    @@draw:
    txa
    pha
    tay
    jsr draw_lane_indicator
    pla
    tax
    @@next:
    dex
    bpl @@loop
    rts
.endp

.proc draw_active_targets
    ldy active_targets_head
    draw_target_list:
    cpy #$FF ; end of list?
    beq @@out
    jsr draw_target
    lda targets_2.next,y
    tay
    jmp draw_target_list
    @@out:
    rts
.endp

.proc draw_hit_targets
    ldy hit_targets_head
    jmp draw_target_list
.endp

.proc draw_missed_targets
    ldy missed_targets_head
    jmp draw_target_list
.endp

.proc process_bullet_time
    lda bullet_timer
    bne +
    rts
  + lda frame_count
    lsr
    bcs +
    rts
  + lsr
    bcs +
    rts
  + dec bullet_timer
    beq +
    rts
  + jmp toggle_time_mode
.endp

.proc draw_all_targets
    jsr draw_active_targets
    jsr draw_hit_targets
    jmp draw_missed_targets
.endp

; Y = lane index
.proc draw_player_lane_indicator
    jsr next_sprite_index
    tax
    lda #$F5
    sta sprites.tile,x
    lda lane_slot_y_coords,y
    clc : adc #17
    sta sprites._y,x
    lda lane_slot_x_coords,y
    clc : adc #4
    sta sprites._x,x
    lda bitmasktable,y
    and player_lanes+1
    beq +
    lda #3
  + sta sprites.attr,x
    rts
.endp

.proc maybe_draw_player_lane_indicators
    lda game_type
    bne + ; only if 2-player
    rts
  + ldy #4
  - jsr draw_player_lane_indicator
    dey
    bpl -
    rts
.endp

.proc check_if_dead
    lda player.energy_level
    beq @@die
    lda game_type
    eor #2
    ora player.energy_level+1
    beq @@die ; versus && player 2 health == 0
    rts
    @@die:
    lda #1
    sta game_state
    lda #42 : ldy #5
    jsr start_timer
    ldcay @@death_delay_done
    jsr set_timer_callback
    lda #$1F
    jsr mixer_set_muted_channels
    lda #1
    ldx #4
    jmp start_sfx

    @@death_delay_done:
    lda #12 : ldy #5
    jsr start_timer
    ldcay @@fade_out_done
    jsr set_timer_callback
; TODO
;    lda #0 : ldy #31
;    jsr set_fade_range
;    jmp start_fade_to_black
    rts

    @@fade_out_done:
.ifdef LIFE_SUPPORT
    dec player.life_count
    bmi @@game_over
    ; start next life
; TODO
;    dec main_cycle ; game_init
    rts

    @@game_over:
.endif
    lda #0
    sta time_mode
    sta global_transpose
    jsr start_song ; mute
    lda #0
    jsr mixer_set_muted_channels
    ldcay 0
    jsr set_pattern_row_callback

; TODO
;    lda #6
;    jsr swap_bank
;    lda #12 ; game over init
    ldx game_type
    cpx #2 ; versus?
    bne +
    lda #28 ; winner/loser screen
  + ; sta main_cycle
    rts
.endp

.proc update_screen_shake
    lda screen_shake_counter
    bne +
    rts
  + lda frame_count
    lsr
    bcc +
    rts
  + dec screen_shake_counter
    lda screen_shake_counter
    and #1 : asl
    sta ppu.scroll_y
    rts
.endp

; A = number of frames to shake
.proc shake_screen
    sta screen_shake_counter
    rts
.endp

.proc update_palette_for_time_mode
; TODO
    rts
.endp

.proc set_palette_for_time_mode
; we need to fix up palette entry 5
; if we are in Versus mode...
    lda time_mode
    beq +
    rts
  + lda game_type
    cmp #2 ; versus?
    beq +
    rts
  + ; TODO
;    lda #$10
;    sta palette+5 ; gray instead of dark green
;    ldy #$3F : lda #$05 : ldx #1
;    jsr begin_ppu_string
;    lda palette+5
;    jsr put_ppu_string_byte
;    jmp end_ppu_string
    rts
.endp

.proc game_core
    jsr process_lockable_lanes
    jsr draw_lockable_lanes
    jsr process_locked_lanes
    jsr draw_locked_lanes
    jsr process_bullet_time
    jsr maybe_begin_song
    jsr maybe_load_targets
    jsr process_active_targets
    jsr process_hit_targets
    jsr process_missed_targets
; TODO: debug hit extent
; TODO
;    jsr update_score_displays
;    jsr update_progress_display
;    jsr update_energy_display
    jsr update_screen_shake
;.ifdef LIFE_SUPPORT
;    jsr update_lives_display
;.endif
;    jsr update_moving_background
    jsr update_damage_blink
    jsr update_spawned_heart
; TODO
;    jsr update_points_level_indicator
    jsr update_letters_display
    jsr maybe_draw_player_lane_indicators
;    jsr draw_vu_pin
    rts
.endp

;.define PLAYER_2_CPU
.ifdef PLAYER_2_CPU
.proc lock_player_2_lanes
    lda player_lanes+1
    sta locked_lanes
    lda #0
    sta lockable_lanes
    lda #60
    sta locked_lane_timers+0
    sta locked_lane_timers+1
    sta locked_lane_timers+2
    sta locked_lane_timers+3
    sta locked_lane_timers+4
    rts
.endp
.endif

.proc game_handler ; F4C4
    jsr reset_sprites
    lda transition_timer
    bne @@update_transition
    lda game_state
    beq @@normal
    ; dead or done
    lda #0
    sta lane_input_posedge+0
    sta lane_input_posedge+1
    jsr game_core
    progbuf_load game_handler
    jmp progbuf_push

    @@update_transition:
    jsr draw_all_targets
    jsr draw_locked_lanes
    jsr draw_vu_pin
    jsr maybe_draw_player_lane_indicators
    jsr update_palette_for_time_mode
    dec transition_timer
    beq +
    rts
    ; back to normal game mode
  + jsr set_palette_for_time_mode
    lda was_music_paused
    bne +
    jsr unpause_music
  + lda saved_muted_channels
    jsr mixer_set_muted_channels
    lda time_mode
    beq +
    lda #144
    sta bullet_timer ; how long bullet time shall last
  + rts

    @@normal: ; F50C
    jsr get_player_1_input
    jsr get_player_2_input
; TODO
;    jsr check_pause
.ifdef PLAYER_2_CPU
    jsr lock_player_2_lanes
.endif
    jsr draw_pressed_lanes
    jsr game_core
    jsr check_if_done
    jsr check_if_dead
; turn on for dynamic "profiling" (the screen goes black when processing is done)
.if 0
    lda ppu.ctrl1
    and #~PPU_CTRL1_BG_VISIBLE
    sta $2001
.endif
    progbuf_load game_handler
    jmp progbuf_push
.endp

.end
