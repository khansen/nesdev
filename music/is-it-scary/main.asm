.include <common/fixedpoint.h>
.include <common/progbuf.h>
.include <common/joypad.h>
.include <common/ppu.h>
.include <common/ppubuffer.h>
.include <common/ldc.h>
.include <common/sprite.h>
.include <common/ptr.h>
.include <sound/track.h>

.struc object
state .byte
speed_x .fp_8_8
speed_y .fp_8_8
pos_x .fp_8_8
pos_y .fp_8_8
next .ptr
.ends

.dataseg zeropage

spotlight_phase .db
spotlight_tick .db

spotlight_pos_x .fp_8_8
spotlight_pos_y .fp_8_8
spotlight_speed_x .fp_8_8
spotlight_speed_y .fp_8_8
spotlight_accel_x .fp_8_8
spotlight_accel_y .fp_8_8

t0 .db
t1 .db
t2 .db
t3 .db
t4 .db
tp .ptr

current_object .ptr
kill_me .byte
objects_head .ptr
objects_free_head .ptr
spawn_creature_timer .byte
bat_counter .byte

.dataseg

MAX_OBJECTS .equ 25
objects_arena .object[MAX_OBJECTS]

.codeseg

.public genesis

.extrn screen_on:proc
.extrn set_play_note_callback:proc
.extrn mixer_reset:proc
.extrn start_song:proc
.extrn set_palette:proc
.extrn write_palette:proc
.extrn reset_sprites:proc
.extrn sound_status:byte
.extrn frame_count:byte

.proc genesis
    jsr screen_off
    lda #0
    jsr fill_all_nametables

    lda ppu.ctrl0
    and #~(PPU_CTRL0_SPRITE_SIZE | PPU_CTRL0_BG_TABLE | PPU_CTRL0_SPRITE_TABLE)
    ora #(PPU_CTRL0_SPRITE_SIZE_8x16 | PPU_CTRL0_BG_TABLE_0000 | PPU_CTRL0_SPRITE_TABLE_1000)
    sta ppu.ctrl0
    lda #6 ; clip off
    sta ppu.ctrl1

    ldcay @@palette
    jsr set_palette
    jsr write_palette

    ldcay @@tilemap_data
    jsr write_ppu_data_at

    jsr init_spotlight
    jsr init_objects
    jsr spawn_bat

    ldcay noop
    jsr set_play_note_callback
    jsr mixer_reset
    lda #1
    jsr start_song

    jsr screen_on
    progbuf_load main_handler
    jmp progbuf_push

.charmap "song.tbl"
@@tilemap_data:
.incbin "packnam.dat"

.db $22, $69, 13 : .char "`Is It Scary`"

.db $22, $A7, 17 : .char "Original music by"
.db $22, $E8, 15 : .char "Michael Jackson"

.db $23, $26, 19 : .char "Use D-pad, A & B to"
.db $23, $48, 15 : .char "toggle channels"
.db 0

.char "MADE BY KENT HANSEN" : .db 0

@@palette:
; 0 - darkest
.db $0F,$03,$13,$23
; 1 - darker
.db $0F,$13,$23,$33
; 2 - brighter
.db $0F,$23,$33,$30
; 3 - brightest
.db $0F,$33,$30,$30
; 0 - bat
.db $0F,$02,$12,$22
; 1 - bat
.db $0F,$12,$22,$32
; 2 - bat
.db $0F,$22,$32,$30
; 3 - moon
.db $0F,$28,$08,$38
.endp

.proc main_handler
    jsr reset_sprites
    jsr update_spotlight
    jsr maybe_spawn_creature
    jsr update_objects
    jsr mute_or_unmute_channels
    progbuf_load main_handler
    jmp progbuf_push
.endp

.proc maybe_spawn_creature
    lda bat_counter
    cmp #2
    bcc +
    rts
  + inc spawn_creature_timer
    lda spawn_creature_timer
    cmp #120
    bcc @@no_spawn
    lda #0
    sta spawn_creature_timer
    beq spawn_bat
@@no_spawn:
    sta spawn_creature_timer
    rts
.endp

.proc spawn_bat
    jsr allocate_object
    ldy #object::state
    lda #0
    sta [tp],y ; type (0=bat)
    ldy #object::speed_x
    sta [tp],y
    iny
    sta [tp],y
    ldy #object::speed_y
    sta [tp],y
    iny
    sta [tp],y
    ldy #(object::pos_y + fp_8_8::frac)
    sta [tp],y
    ldy #(object::pos_x + fp_8_8::frac)
    sta [tp],y
    ldy #(object::pos_y + fp_8_8::int)
    lda #68
    sta [tp],y
    ldy #(object::pos_x + fp_8_8::int)
    lda #134
    sta [tp],y
    inc bat_counter
    rts
.endp

.proc update_bat
    ; calculate distance to spotlight
    ldy #(object::pos_x + fp_8_8::int)
    lda [current_object],y
    cmp spotlight_pos_x.int
    bcs +
    lda spotlight_pos_x.int
    sec
    sbc [current_object],y
    jmp ++
  + sbc spotlight_pos_x.int
 ++ lsr
    lsr
    lsr
    lsr
    sta t0

    ldy #(object::pos_y + fp_8_8::int)
    lda [current_object],y
    cmp spotlight_pos_y.int
    bcs +
    lda spotlight_pos_y.int
    sec
    sbc [current_object],y
    jmp ++
  + sbc spotlight_pos_y.int
 ++ lsr
    lsr
    lsr
    lsr
    clc
    adc t0
    cmp #4
    bcc +
    lda #3
  + eor #3
    sta t0

    ; update on X axis
    lda spotlight_pos_x.int
    ldy #(object::pos_x + fp_8_8::int)
    cmp [current_object], y
    bcc @@accelerate_left
    ; accelerate right
    ldy #(object::speed_x + fp_8_8::frac)
    lda [current_object], y
    clc
    adc #$0C ; accel_x.frac
    sta [current_object], y
    ldy #(object::speed_x + fp_8_8::int)
    lda [current_object], y
    adc #$00 ; accel_x.int
    sta [current_object], y
    bmi @@clip_negative_x_speed
    bpl @@clip_positive_x_speed

    @@accelerate_left:
    ldy #(object::speed_x + fp_8_8::frac)
    lda [current_object], y
    clc
    adc #$F4 ; accel_x.frac
    sta [current_object], y
    ldy #(object::speed_x + fp_8_8::int)
    lda [current_object], y
    adc #$FF ; accel_x.int
    sta [current_object], y
    bmi @@clip_negative_x_speed
    @@clip_positive_x_speed:
    cmp #2
    bcc @@apply_x_speed
    ; clip X speed
    lda #2
    sta [current_object], y
    ldy #(object::speed_x + fp_8_8::frac)
    lda #0
    sta [current_object], y
    beq @@apply_x_speed
    @@clip_negative_x_speed:
    cmp #$FE
    bcs @@apply_x_speed
    ; clip X speed
    lda #$FE
    sta [current_object], y
    ldy #(object::speed_x + fp_8_8::frac)
    lda #0
    sta [current_object], y

    @@apply_x_speed:
    ldy #(object::speed_x + fp_8_8::frac)
    lda [current_object], y
    ldy #(object::pos_x + fp_8_8::frac)
    clc
    adc [current_object], y
    sta [current_object], y
    ldy #(object::speed_x + fp_8_8::int)
    lda [current_object], y
    ldy #(object::pos_x + fp_8_8::int)
    adc [current_object], y
    sta [current_object], y

    ; update on Y axis
    lda spotlight_pos_y.int
    ldy #(object::pos_y + fp_8_8::int)
    cmp [current_object], y
    bcc @@accelerate_up
    ; accelerate down
    ldy #(object::speed_y + fp_8_8::frac)
    lda [current_object], y
    clc
    adc #$10 ; accel_y.frac
    sta [current_object], y
    ldy #(object::speed_y + fp_8_8::int)
    lda [current_object], y
    adc #$00 ; accel_y.int
    sta [current_object], y
    bmi @@clip_negative_y_speed
    bpl @@clip_positive_y_speed

    @@accelerate_up:
    ldy #(object::speed_y + fp_8_8::frac)
    lda [current_object], y
    clc
    adc #$F0 ; accel_y.frac
    sta [current_object], y
    ldy #(object::speed_y + fp_8_8::int)
    lda [current_object], y
    adc #$FF ; accel_y.int
    sta [current_object], y
    bmi @@clip_negative_y_speed
    @@clip_positive_y_speed:
    cmp #2
    bcc @@apply_y_speed
    lda #2
    sta [current_object], y
    ldy #(object::speed_y + fp_8_8::frac)
    lda #0
    sta [current_object], y
    @@clip_negative_y_speed:
    cmp #$FE
    bcs @@apply_y_speed
    ; clip Y speed
    lda #$FE
    sta [current_object], y
    ldy #(object::speed_y + fp_8_8::frac)
    lda #0
    sta [current_object], y

    @@apply_y_speed:
    ldy #(object::speed_y + fp_8_8::frac)
    lda [current_object], y
    ldy #(object::pos_y + fp_8_8::frac)
    clc
    adc [current_object], y
    sta [current_object], y
    ldy #(object::speed_y + fp_8_8::int)
    lda [current_object], y
    ldy #(object::pos_y + fp_8_8::int)
    adc [current_object], y
    sta [current_object], y

    ; draw
    ldy #(object::pos_x + fp_8_8::int)
    lda [current_object], y
    cmp spotlight_pos_x.int
    and #8
    bcs @@face_left
    bne @@draw_right_frame1
    jmp draw_bat_right_frame0
    @@draw_right_frame1:
    jmp draw_bat_right_frame1
    @@face_left:
    bne @@draw_left_frame1
    jmp draw_bat_left_frame0
    @@draw_left_frame1:
    jmp draw_bat_left_frame1
.endp

.proc draw_bat_left_frame0
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  ldy #(object::pos_x + fp_8_8::int)
  lda [current_object], y
  sta sprites._x,x
  lda #$01
  sta sprites.tile,x
  lda t0
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  ldy #(object::pos_x + fp_8_8::int)
  lda [current_object], y
  clc
  adc #8
  sta sprites._x,x
  lda #$01
  sta sprites.tile,x
  lda t0
  ora #SPRITE_ATTR_H_FLIP
  sta sprites.attr,x
  rts
.endp

.proc draw_bat_left_frame1
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  ldy #(object::pos_x + fp_8_8::int)
  lda [current_object], y
  sta sprites._x,x
  lda #$03
  sta sprites.tile,x
  lda t0
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  ldy #(object::pos_x + fp_8_8::int)
  lda [current_object], y
  clc
  adc #8
  sta sprites._x,x
  lda #$03
  sta sprites.tile,x
  lda t0
  ora #SPRITE_ATTR_H_FLIP
  sta sprites.attr,x
  rts
.endp

.proc draw_bat_right_frame0
    jmp draw_bat_left_frame0
.endp

.proc draw_bat_right_frame1
    jmp draw_bat_left_frame1
.endp

.proc init_spotlight
    lda #0
    sta spotlight_tick
    sta spotlight_pos_x.frac
    sta spotlight_pos_y.frac
    sta spotlight_speed_x.frac
    sta spotlight_speed_y.frac
    sta spotlight_speed_x.int
    sta spotlight_speed_y.int
    lda #128
    sta spotlight_pos_x.int
    lda #64
    sta spotlight_pos_y.int

    lda #$14
    sta spotlight_accel_x.frac
    lda #0
    sta spotlight_accel_x.int
    lda #$08
    sta spotlight_accel_y.frac
    lda #0
    sta spotlight_accel_y.int
    rts
.endp

.proc update_spotlight
    lda spotlight_accel_x.int
    bmi @@check_left_collision
    lda spotlight_pos_x.int
    cmp #160
    bcc @@check_vertical_collision
    @@invert_x_accel:
    lda spotlight_accel_x.frac
    eor #$FF
    sec
    adc #0
    sta spotlight_accel_x.frac
    lda spotlight_accel_x.int
    eor #$FF
    adc #0
    sta spotlight_accel_x.int
    jmp @@check_vertical_collision
    @@check_left_collision:
    lda spotlight_pos_x.int
    cmp #96
    bcc @@invert_x_accel

    @@check_vertical_collision:
    lda spotlight_accel_y.int
    bmi @@check_top_collision
    lda spotlight_pos_y.int
    cmp #136
    bcc @@apply_x_accel
    @@invert_y_accel:
    lda spotlight_accel_y.frac
    eor #$FF
    sec
    adc #0
    sta spotlight_accel_y.frac
    lda spotlight_accel_y.int
    eor #$FF
    adc #0
    sta spotlight_accel_y.int
    jmp @@apply_x_accel
    @@check_top_collision:
    lda spotlight_pos_y.int
    cmp #96
    bcc @@invert_y_accel

    @@apply_x_accel:
    lda spotlight_accel_x.frac
    clc
    adc spotlight_speed_x.frac
    sta spotlight_speed_x.frac
    lda spotlight_accel_x.int
    adc spotlight_speed_x.int
    sta spotlight_speed_x.int
    bmi @@clip_negative_x_speed
    cmp #3
    bcc @@apply_x_speed
    lda #3
    sta spotlight_speed_x.int
    lda #0
    sta spotlight_speed_x.frac
    beq @@apply_x_speed
    @@clip_negative_x_speed:
    cmp #$FD
    bcs @@apply_x_speed
    lda #$FD
    sta spotlight_speed_x.int
    lda #0
    sta spotlight_speed_x.frac

    @@apply_x_speed:
    lda spotlight_pos_x.frac
    clc
    adc spotlight_speed_x.frac
    sta spotlight_pos_x.frac
    lda spotlight_pos_x.int
    adc spotlight_speed_x.int
    sta spotlight_pos_x.int

    ; apply y accel and speed
    lda spotlight_accel_y.frac
    clc
    adc spotlight_speed_y.frac
    sta spotlight_speed_y.frac
    lda spotlight_accel_y.int
    adc spotlight_speed_y.int
    sta spotlight_speed_y.int
    bmi @@clip_negative_y_speed
    cmp #2
    bcc @@apply_y_speed
    lda #2
    sta spotlight_speed_y.int
    lda #0
    sta spotlight_speed_y.frac
    beq @@apply_y_speed
    @@clip_negative_y_speed:
    cmp #$FE
    bcs @@apply_y_speed
    lda #$FE
    sta spotlight_speed_y.int
    lda #0
    sta spotlight_speed_y.frac

    @@apply_y_speed:
    lda spotlight_pos_y.frac
    clc
    adc spotlight_speed_y.frac
    sta spotlight_pos_y.frac
    lda spotlight_pos_y.int
    adc spotlight_speed_y.int
    sta spotlight_pos_y.int

    lda spotlight_pos_y.int
    and #$E0
    lsr
    lsr
    sta t0
    lda spotlight_pos_x.int
    lsr
    lsr
    lsr
    lsr
    lsr
    ora t0 ; byte offset of hotspot (0..63)
    ora #$C0 ; low PPU address of hotspot
    sta t0

    lda spotlight_pos_y.int
    and #$10
    sta t1
    lda spotlight_pos_x.int
    and #$10
    lsr
    ora t1
    sta t1 ; table offset

    ; draw sprite
    ; left, top
    jsr next_sprite_index
    tax
    lda spotlight_pos_y.int
    sec
    sbc #12
    sta sprites._y,x
    lda spotlight_pos_x.int
    sec
    sbc #12
    sta sprites._x,x
    lda #5
    sta sprites.tile,x
    lda #3
    sta sprites.attr,x
    ; left, bottom
    jsr next_sprite_index
    tax
    lda spotlight_pos_y.int
    clc
    adc #4
    sta sprites._y,x
    lda spotlight_pos_x.int
    sec
    sbc #12
    sta sprites._x,x
    lda #11
    sta sprites.tile,x
    lda #3
    sta sprites.attr,x
    ; middle, top
    jsr next_sprite_index
    tax
    lda spotlight_pos_y.int
    sec
    sbc #12
    sta sprites._y,x
    lda spotlight_pos_x.int
    sec
    sbc #4
    sta sprites._x,x
    lda #7
    sta sprites.tile,x
    lda #3
    sta sprites.attr,x
    ; middle, bottom
    jsr next_sprite_index
    tax
    lda spotlight_pos_y.int
    clc
    adc #4
    sta sprites._y,x
    lda spotlight_pos_x.int
    sec
    sbc #4
    sta sprites._x,x
    lda #13
    sta sprites.tile,x
    lda #3
    sta sprites.attr,x
    ; right, top
    jsr next_sprite_index
    tax
    lda spotlight_pos_y.int
    sec
    sbc #12
    sta sprites._y,x
    lda spotlight_pos_x.int
    clc
    adc #4
    sta sprites._x,x
    lda #9
    sta sprites.tile,x
    lda #3
    sta sprites.attr,x
    ; right, bottom
    jsr next_sprite_index
    tax
    lda spotlight_pos_y.int
    clc
    adc #4
    sta sprites._y,x
    lda spotlight_pos_x.int
    clc
    adc #4
    sta sprites._x,x
    lda #15
    sta sprites.tile,x
    lda #3
    sta sprites.attr,x

    ;jsr write_quadrant

    lda #4
    sta t4
    @@row_loop:
    ldx t1
    lda @@spotlight_pointers+0,x
    sta tp.lo
    lda @@spotlight_pointers+1,x
    sta tp.hi

    ldy #0
    lda [tp],y ; relative offset from hotspot
    clc
    adc t0
    pha ; low PPU address
    iny
    lda [tp],y ; count
    sta t2
    tax
    sty t3
    pla
    ldy #$23
    jsr begin_ppu_string
    ldy t3
    @@column_loop:
    iny
    lda [tp],y
    sta ppu_buffer,x : inx
    dec t2
    bne @@column_loop
    jsr end_ppu_string

    dec t4
    beq @@done
    inc t1
    inc t1
    bne @@row_loop
    @@done:
    rts

@@spotlight_pointers:
.dw @@spot0_0
.dw @@spot0_1
.dw @@spot0_2
.dw @@spot0_3
.dw @@spot1_0
.dw @@spot1_1
.dw @@spot1_2
.dw @@spot1_3
.dw @@spot2_0
.dw @@spot2_1
.dw @@spot2_2
.dw @@spot2_3
.dw @@spot3_0
.dw @@spot3_1
.dw @@spot3_2
.dw @@spot3_3

; spotlight in upper left quadrant
@@spot0_0:
.db -17,$02,$00,$00 ; hotspot - 17
@@spot0_1:
.db -10,$04,$00,$40,$61,$00 ; hotspot - 10
@@spot0_2:
.db -2,$04,$00,$49,$6B,$01 ; hotspot - 2
@@spot0_3:
.db 7,$03,$00,$01,$00 ; hotspot + 7
; spotlight in upper right quadrant
@@spot1_0:
.db -16,$02,$00,$00 ; hotspot - 16
@@spot1_1:
.db -9,$04,$00,$94,$10,$00 ; hotspot - 9
@@spot1_2:
.db -1,$04,$04,$9E,$16,$00 ; hotspot - 1
@@spot1_3:
.db 7,$04,$00,$04,$00,$00 ; hotspot + 7
; spotlight in lower left quadrant
@@spot2_0:
.db -9,$03,$00,$10,$00 ; hotspot - 9
@@spot2_1:
.db -2,$04,$00,$94,$B6,$10 ; hotspot - 2
@@spot2_2:
.db 6,$04,$00,$04,$16,$00 ; hotspot + 6
@@spot2_3:
.db 15,$03,$00,$00,$00 ; hotspot + 15
; spotlight in lower right quadrant
@@spot3_0:
.db -9,$03,$00,$40,$00 ; hotspot - 9
@@spot3_1:
.db -1,$04,$40,$E9,$61,$00 ; hotspot - 1
@@spot3_2:
.db 7,$04,$00,$49,$01,$00 ; hotspot + 7
@@spot3_3:
.db 16,$02,$00,$00 ; hotspot + 16
.endp

.proc mute_or_unmute_channels
    lda joypad0_posedge
    and #JOYPAD_BUTTON_UP
    beq @@up_not_pressed
    ; toggle channel 1
    lda sound_status
    eor #1
    sta sound_status
    @@up_not_pressed:
    lda joypad0_posedge
    and #JOYPAD_BUTTON_DOWN
    beq @@down_not_pressed
    ; toggle channel 2
    lda sound_status
    eor #2
    sta sound_status
    @@down_not_pressed:
    lda joypad0_posedge
    and #JOYPAD_BUTTON_LEFT
    beq @@left_not_pressed
    ; toggle channel 3
    lda sound_status
    eor #4
    sta sound_status
    @@left_not_pressed:
    lda joypad0_posedge
    and #JOYPAD_BUTTON_RIGHT
    beq @@right_not_pressed
    ; toggle channel 4
    lda sound_status
    eor #8
    sta sound_status
    @@right_not_pressed:
    lda joypad0_posedge
    and #(JOYPAD_BUTTON_A | JOYPAD_BUTTON_B)
    beq @@a_or_b_not_pressed
    ; toggle channel 5
    lda sound_status
    eor #16
    sta sound_status
    @@a_or_b_not_pressed:
    rts
.endp

.proc noop
  rts
.endp

.proc init_objects
    lda #>objects_arena
    sta objects_free_head.hi
    sta tp.hi
    lda #<objects_arena
    sta objects_free_head.lo
    sta tp.lo
    ldy #object::next
    ldx #MAX_OBJECTS-1
    @@10:
    clc
    adc #sizeof object
    sta [tp],y ; next.lo
    iny
    pha ; next.lo
    lda tp.hi
    adc #0
    sta [tp],y ; next.hi
    sta tp.hi
    pla ; next.lo
    sta tp.lo
    dey
    dex
    bne @@10
    lda #0
    sta [tp],y ; next.lo
    iny
    sta [tp],y ; next.hi
    sta objects_head.lo
    sta objects_head.hi
    rts
.endp

.proc allocate_object
    ; take the first object from free list
    lda objects_free_head.lo
    sta tp.lo
    lda objects_free_head.hi
    sta tp.hi
    ora tp.lo
    bne @@10
    ; out of memory
    brk
    @@10:
    ldy #object::next
    ; make free next the new free head
    lda [tp],y ; next.lo
    iny
    sta objects_free_head.lo
    lda [tp],y ; next.hi
    sta objects_free_head.hi
    ; make old objects head the next object
    lda objects_head.hi
    sta [tp],y ; next.hi
    dey
    lda objects_head.lo
    sta [tp],y ; next.lo
    ; make allocated object the new objects head
    lda tp.lo
    sta objects_head.lo
    lda tp.hi
    sta objects_head.hi
    rts
.endp

.proc update_objects
    lda #0
    sta kill_me
    lda objects_head.hi
    sta current_object.hi
    lda objects_head.lo
    sta current_object.lo
    pha
    ; clear the objects list
    lda #0
    sta objects_head.lo
    sta objects_head.hi
    pla
    @@object_loop:
    ora current_object.hi
    beq @@exit

    jsr update_object

    ldy #object::next
    lda [current_object],y ; next.lo
    iny
    pha ; next.lo
    lda [current_object],y ; next.hi
    pha ; next.hi
    lsr kill_me
    bcc @@keep_object
  ; move to free list
    lda objects_free_head.hi
    sta [current_object],y ; next.hi
    dey
    lda objects_free_head.lo
    sta [current_object],y ; next.lo
    lda current_object.lo
    sta objects_free_head.lo
    lda current_object.hi
    sta objects_free_head.hi

    pla ; next.hi
    sta current_object.hi
    pla ; next.lo
    sta current_object.lo
    jmp @@object_loop

    @@keep_object:
    ; make current object new head of objects
    lda objects_head.hi
    sta [current_object],y ; next.hi
    dey
    lda objects_head.lo
    sta [current_object],y ; next.lo
    lda current_object.lo
    sta objects_head.lo
    lda current_object.hi
    sta objects_head.hi

    pla ; next.hi
    sta current_object.hi
    pla ; next.lo
    sta current_object.lo
    jmp @@object_loop

    @@exit:
    rts
.endp

.proc update_object
    jmp update_bat
.endp

.end
