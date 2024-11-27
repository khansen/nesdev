.include <common/progbuf.h>
.include <common/joypad.h>
.include <common/ppu.h>
.include <common/ppubuffer.h>
.include <common/ldc.h>
.include <common/sprite.h>
.include <common/ptr.h>
.include <common/fixedpoint.h>

.struc big_heart_state
  pos_x .fp_8_8
  pos_y .fp_8_8
  speed_x .fp_8_8
  speed_y .fp_8_8
  accel_x .fp_8_8
  accel_y .fp_8_8
.ends

.struc object
state .byte
speed_x .fp_8_8
speed_y .fp_8_8
pos_x .fp_8_8
pos_y .fp_8_8
next .ptr
.ends

.dataseg zeropage

t0 .db
t1 .db
t2 .db
t3 .db
t4 .db
t5 .db
t6 .db
tp .ptr

big_heart .big_heart_state
spawn_heart_timer .byte

current_object .ptr
kill_me .byte
star_counter .byte

objects_head .ptr
objects_free_head .ptr

.dataseg

MAX_OBJECTS .equ 42
objects_arena .object[MAX_OBJECTS]

.codeseg

.public genesis

.extrn screen_on:proc
.extrn set_play_note_callback:proc
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

    jsr init_big_heart
    jsr init_objects
    jsr spawn_angel

    ldcay noop
    jsr set_play_note_callback
    lda #1
    jsr start_song

    jsr screen_on
    progbuf_load main_handler
    jmp progbuf_push

.charmap "song.tbl"
@@tilemap_data:
.db $20, $85, 22 : .char "There Must Be An Angel"
.db $20, $C3, 26 : .char "(Playing With Pit's Heart)"
.db $21, $48, 17 : .char "Original music by"
.db $21, $8B, 10 : .char "Eurythmics"
.db $22, $0A, 10 : .char "Remixed in"
.db $22, $15, 2, $38,$39 ; flag
.db $22, $E2, 28 : .char "Use D-pad to toggle channels"

.db $23, $E5, $01, $55 ; flag attribs

; cloud 0
.db $2B, $06, 4,  $3A, $3B, $3A, $3B
.db $2B, $23, 7,  $3A, $3C, $3A, $3F, $3F, $3E, $42
.db $2B, $41, 11, $3A, $3C, $3F, $3F, $3D, $3E, $3F, $3F, $3C, $3B, $3C
.db $2B, $61, 11, $40, $41, $3E, $3D, $3E, $3F, $3E, $42, $40, $41, $42
.db $2B, $83, 5,  $40, $41, $42, $40, $42
; cloud 1
.db $2A, $5A, 3, $3A, $3B, $3C
.db $2A, $79, 6, $3A, $3D, $3D, $3E, $3B, $3C
.db $2A, $99, 6, $40, $41, $41, $42, $41, $42
; cloud 2
.db $28, $E0, 3, $3A, $3B, $3C
.db $29, $00, 5, $3E, $3F, $3F, $3C, $3C
.db $29, $20, 5, $3F, $3D, $3E, $3E, $42
.db $29, $40, 4, $3E, $3F, $41, $42
.db $29, $60, 2, $41, $42
; cloud 3
.db $28, $55, 4,  $3A, $3B, $3B, $3C
.db $28, $73, 8,  $3A, $3B, $3F, $3F, $3E, $3F, $3C, $3C
.db $28, $92, 14, $3A, $3F, $3D, $3E, $3F, $3F, $3F, $3F, $3E, $3C, $3B, $3C, $3A, $3B
.db $28, $B2, 14, $40, $41, $41, $41, $3D, $3E, $3E, $3E, $42, $40, $41, $41, $3D, $3E
.db $28, $D6, 4,  $40, $41, $41, $42
.db $28, $DE, 2,  $40, $41
; cloud 4
.db $29, $AA, 3, $3A, $3B, $3C
.db $29, $C9, 6, $3A, $3D, $3D, $3E, $3B, $3C
.db $29, $E9, 6, $40, $41, $41, $42, $41, $42
; cloud attribs
.db $2B,$C0,$60,$AA
.db $2B,$E0,$60,$AA
.db 0

.char "MADE BY KENT HANSEN" : .db 0

@@palette:
; 0 - background and text
.db $01,$0F,$22,$30
; 1 - flag
.db $01,$15,$11,$30
; 2 - cloud
.db $01,$3C,$2C,$1C
; 3 -unused
.db $01,$0F,$0F,$0F
; 0 - angel
.db $01,$37,$26,$06
; 1 - small heart
.db $01,$37,$05,$25
; 2 - big heart
.db $01,$2C,$11,$24
  ; 3 -unused
.db $01,$0F,$0F,$0F
  .endp

.proc spawn_angel
    jsr allocate_object
    ldy #object::state
    lda #0
    sta [tp],y ; type (0=angel)
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
    lda #100
    sta [tp],y
    ldy #(object::pos_x + fp_8_8::int)
    lda #110
    sta [tp],y
    rts
.endp

.proc init_big_heart
    lda #0
    sta big_heart.pos_x.frac
    sta big_heart.pos_y.frac
    sta big_heart.speed_x.frac
    sta big_heart.speed_x.int
    sta big_heart.speed_y.frac
    sta big_heart.speed_y.int
    sta big_heart.accel_x.int
    sta big_heart.accel_y.int
    lda #256/2
    sta big_heart.pos_x.int
    lda #240/2
    sta big_heart.pos_y.int
    lda #$12
    sta big_heart.accel_x.frac
    lda #$06
    sta big_heart.accel_y.frac
    rts
.endp

.proc main_handler
    jsr reset_sprites
    jsr update_big_heart
    jsr update_cloud_palette
    jsr update_scroll
    jsr update_objects
    jsr mute_or_unmute_channels
    progbuf_load main_handler
    jmp progbuf_push
.endp

.proc update_big_heart
  lda big_heart.accel_x.int
  bmi @@check_left_collision
  lda big_heart.pos_x.int
  cmp #150
  bcc @@check_vertical_collision
  @@invert_x_accel:
  lda big_heart.accel_x.frac
  eor #$FF
  sec
  adc #0
  sta big_heart.accel_x.frac
  lda big_heart.accel_x.int
  eor #$FF
  adc #0
  sta big_heart.accel_x.int
  jmp @@check_vertical_collision
  @@check_left_collision:
  lda big_heart.pos_x.int
  cmp #96
  bcc @@invert_x_accel

  @@check_vertical_collision:
  lda big_heart.accel_y.int
  bmi @@check_top_collision
  lda big_heart.pos_y.int
  cmp #110
  bcc @@apply_x_accel
  @@invert_y_accel:
  lda big_heart.accel_y.frac
  eor #$FF
  sec
  adc #0
  sta big_heart.accel_y.frac
  lda big_heart.accel_y.int
  eor #$FF
  adc #0
  sta big_heart.accel_y.int
  jmp @@apply_x_accel
  @@check_top_collision:
  lda big_heart.pos_y.int
  cmp #100
  bcc @@invert_y_accel

  @@apply_x_accel:
  lda big_heart.accel_x.frac
  clc
  adc big_heart.speed_x.frac
  sta big_heart.speed_x.frac
  lda big_heart.accel_x.int
  adc big_heart.speed_x.int
  sta big_heart.speed_x.int
  bmi @@clip_negative_x_speed
  cmp #3
  bcc @@apply_x_speed
  lda #3
  sta big_heart.speed_x.int
  lda #0
  sta big_heart.speed_x.frac
  beq @@apply_x_speed
  @@clip_negative_x_speed:
  cmp #$FD
  bcs @@apply_x_speed
  lda #$FD
  sta big_heart.speed_x.int
  lda #0
  sta big_heart.speed_x.frac

  @@apply_x_speed:
  lda big_heart.pos_x.frac
  clc
  adc big_heart.speed_x.frac
  sta big_heart.pos_x.frac
  lda big_heart.pos_x.int
  adc big_heart.speed_x.int
  sta big_heart.pos_x.int

  ; apply y accel and speed
  lda big_heart.accel_y.frac
  clc
  adc big_heart.speed_y.frac
  sta big_heart.speed_y.frac
  lda big_heart.accel_y.int
  adc big_heart.speed_y.int
  sta big_heart.speed_y.int
  bmi @@clip_negative_y_speed
  cmp #2
  bcc @@apply_y_speed
  lda #2
  sta big_heart.speed_y.int
  lda #0
  sta big_heart.speed_y.frac
  beq @@apply_y_speed
  @@clip_negative_y_speed:
  cmp #$FE
  bcs @@apply_y_speed
  lda #$FE
  sta big_heart.speed_y.int
  lda #0
  sta big_heart.speed_y.frac

  @@apply_y_speed:
  lda big_heart.pos_y.frac
  clc
  adc big_heart.speed_y.frac
  sta big_heart.pos_y.frac
  lda big_heart.pos_y.int
  adc big_heart.speed_y.int
  sta big_heart.pos_y.int

  jmp draw_big_heart_frame0
.endp

.proc draw_big_heart_frame0
  ; left half
  jsr next_sprite_index
  tax
  lda big_heart.pos_y.int
  sta sprites._y,x
  lda big_heart.pos_x.int
  sta sprites._x,x
  lda #$07
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  lda big_heart.pos_y.int
  sta sprites._y,x
  lda big_heart.pos_x.int
  clc
  adc #8
  sta sprites._x,x
  lda #$09
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  rts
.endp

.proc update_scroll
  lda frame_count
  and #$07
  beq +
  rts
+ lda ppu.scroll_y
  bne +
  ; switch to other nametable
  lda ppu.ctrl0
  eor #2
  sta ppu.ctrl0
  lda #240
+ sec
  sbc #1
  sta ppu.scroll_y
  rts
.endp

.proc update_cloud_palette
    lda frame_count
    and #$03
    beq +
    rts
  + ldy #$3F
    lda #$09
    ldx #$03
    jsr begin_ppu_string
    lda frame_count
    and #$E0
    lsr
    lsr
    lsr ; palette index (0..7) * 4
    tay
    lda @@palettes+1,y
    sta ppu_buffer,x
    inx
    lda @@palettes+2,y
    sta ppu_buffer,x
    inx
    lda @@palettes+3,y
    sta ppu_buffer,x
    inx
    jmp end_ppu_string

@@palettes:
.db $0C,$2C,$1C,$0C
.db $0C,$3C,$2C,$1C
.db $0C,$30,$3C,$2C
.db $0C,$30,$30,$3C
.db $0C,$30,$30,$30
.db $0C,$30,$30,$3C
.db $0C,$30,$3C,$2C
.db $0C,$3C,$2C,$1C
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

.proc update_object
    ldy #object::state
    lda [current_object], y
    beq +
    jmp update_falling_heart
  + jmp update_angel
.endp

.proc update_falling_heart
    ldy #(object::pos_y + fp_8_8::int)
    lda [current_object], y
    cmp #240
    bcc @@move_down
    inc kill_me
    rts
    @@move_down:
    ldy #(object::pos_y + fp_8_8::frac)
    lda [current_object], y
    clc
    adc #$60
    sta [current_object], y
    ldy #(object::pos_y + fp_8_8::int)
    lda [current_object], y
    adc #0
    sta [current_object], y

    and #$20
    beq @@move_left
    ; move right
    ldy #(object::pos_x + fp_8_8::frac)
    lda [current_object], y
    clc
    adc #$60
    sta [current_object], y
    ldy #(object::pos_x + fp_8_8::int)
    lda [current_object], y
    adc #0
    sta [current_object], y
    jmp draw_small_heart_frame0

    @@move_left:
    ldy #(object::pos_x + fp_8_8::frac)
    lda [current_object], y
    clc
    adc #$A0
    sta [current_object], y
    ldy #(object::pos_x + fp_8_8::int)
    lda [current_object], y
    adc #$FF
    sta [current_object], y
    jmp draw_small_heart_frame0
.endp

.proc draw_small_heart_frame0
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  ldy #(object::pos_x + fp_8_8::int)
  lda [current_object], y
  sta sprites._x,x
  lda #$0B
  sta sprites.tile,x
  lda #1
  sta sprites.attr,x
  rts
.endp

.proc update_angel
    jsr maybe_spawn_falling_heart

    ; update on X axis
    lda big_heart.pos_x.int
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
    lda big_heart.pos_y.int
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
    cmp big_heart.pos_x.int
    and #8
    bcs @@face_left
    bne @@draw_right_frame1
    jmp draw_angel_right_frame0
    @@draw_right_frame1:
    jmp draw_angel_right_frame1
    @@face_left:
    bne @@draw_left_frame1
    jmp draw_angel_left_frame0
    @@draw_left_frame1:
    jmp draw_angel_left_frame1
.endp

.proc maybe_spawn_falling_heart
    inc spawn_heart_timer
    lda spawn_heart_timer
    cmp #48
    bcs +
    rts
  + lda #0
    sta spawn_heart_timer
    jmp spawn_falling_heart
.endp

.proc spawn_falling_heart
    jsr allocate_object
    ldy #object::state
    lda #1 ; type (0=angel, 1=heart)
    sta [tp],y
    lda #0
    ldy #(object::pos_y + fp_8_8::frac)
    sta [tp],y
    ldy #(object::pos_x + fp_8_8::frac)
    sta [tp],y
    ldy #(object::pos_y + fp_8_8::int)
    lda [current_object], y
    sta [tp],y
    ldy #(object::pos_x + fp_8_8::int)
    lda [current_object], y
    sta [tp],y
    rts
.endp

.proc draw_angel_left_frame0
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
  lda #0
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
  lda #0
  sta sprites.attr,x
  rts
.endp

.proc draw_angel_left_frame1
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
  lda #0
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
  lda #$05
  sta sprites.tile,x
  lda #0
  sta sprites.attr,x
  rts
.endp

.proc draw_angel_right_frame0
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
  lda #SPRITE_ATTR_H_FLIP
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
  lda #SPRITE_ATTR_H_FLIP
  sta sprites.attr,x
  rts
.endp

.proc draw_angel_right_frame1
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  ldy #(object::pos_x + fp_8_8::int)
  lda [current_object], y
  sta sprites._x,x
  lda #$05
  sta sprites.tile,x
  lda #SPRITE_ATTR_H_FLIP
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
  lda #SPRITE_ATTR_H_FLIP
  sta sprites.attr,x
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

.end
