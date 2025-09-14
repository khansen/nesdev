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
state_0 .byte  ; 0
state_1 .byte  ; 1
pos_x .fp_16_8 ; 2
pos_y .fp_8_8  ; 5
screen_x .byte ; 7
next .ptr      ; 8
.ends

.dataseg zeropage

random .byte
world_page .byte
tp .ptr
current_object .ptr
kill_me .byte
objects_head .ptr
objects_free_head .ptr
spawn_bubble_timer .byte
spawn_creature_timer .byte

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

    jsr init_objects
    ; initialize seed
    lda #237
    sta random

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
; Screen 0

; surface
db $20, $00, $60, $41
db $20, $20, $60, $41
db $20, $40, $60, $41
db $20, $60, $60, $41
db $20, $80, $60, $38

; sea floor
db $23, $40, 32, $39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A
db $23, $60, 32, $3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C
db $23, $80, 32, $39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A
db $23, $A0, 32, $3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C
db $23, $F0, $48, $55
db $23, $F8, $48, $55

; chest 1
db $23, $0C, 2, $42,$43
db $23, $2C, 2, $44,$45
db $23, $F3, 1, $5F

; chests 2 & 3
db $23, $10, 4, $42,$43,$42,$43
db $23, $30, 4, $44,$45,$44,$45
db $23, $F4, $42, $5F

; chests 4, 5, and 6
db $23, $16, 6, $42,$43,$42,$43,$42,$43
db $23, $36, 6, $44,$45,$44,$45,$44,$45
db $23, $F6, 2, $5F,$5F

; chests 7 & 8
db $23, $02, 4, $42,$43,$42,$43
db $23, $22, 4, $44,$45,$44,$45
db $23, $F0, $2, $5F,$5F

; seaweed 1
db $22, $48, 2, $3D,$3E
db $22, $68, 2, $3F,$40
db $22, $88, 2, $3D,$3E
db $22, $A8, 2, $3F,$40
db $22, $C8, 2, $3D,$3E
db $22, $E8, 2, $3F,$40
db $23, $08, 2, $3D,$3E
db $23, $28, 2, $3F,$40
db $23, $E2, $01, $AA
db $23, $EA, $01, $AA
db $23, $F2, $01, $5A

; platform 1
db $21, $54, $06, $39,$3A,$39,$3A,$39,$3A
db $21, $74, $06, $3B,$3C,$3B,$3C,$3B,$3C
db $23, $D5, $02, $5A, $50

; platform 2
db $21, $44, $08, $39,$3A,$39,$3A,$39,$3A,$39,$3A
db $21, $64, $08, $3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C
db $23, $D1, $42, $50

; seaweed 2
db $20, $D6, 2, $3D,$3E
db $20, $F6, 2, $3F,$40
db $21, $16, 2, $3D,$3E
db $21, $36, 2, $3F,$40
db $23, $CD, $01, $A0

.db $21, $EC, 18 : .char "`Dire, Dire Docks`"

.db $22, $4C, 17 : .char "Original music by"
.db $22, $8F, 10 : .char "Koji Kondo"

; Screen 1

; surface
db $24, $00, $60, $41
db $24, $20, $60, $41
db $24, $40, $60, $41
db $24, $60, $60, $41
db $24, $80, $60, $38

; sea floor
db $27, $40, 32, $39,$3A,$39,$3A,$00,$00,$00,$00,$00,$00,$00,$00,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A
db $27, $60, 32, $3B,$3C,$3B,$3C,$00,$00,$00,$00,$00,$00,$00,$00,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C
db $27, $80, 32, $39,$3A,$39,$3A,$00,$00,$00,$00,$00,$00,$00,$00,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A,$39,$3A
db $27, $A0, 32, $3B,$3C,$3B,$3C,$00,$00,$00,$00,$00,$00,$00,$00,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C,$3B,$3C
db $27, $F0, $48, $55
db $27, $F8, $48, $55

; chasm left
db $26, $02, $02, $39,$3A
db $26, $22, $02, $3B,$3C
db $26, $42, $02, $39,$3A
db $26, $62, $02, $3B,$3C
db $26, $80, $04, $39,$3A,$39,$3A
db $26, $A0, $04, $3B,$3C,$3B,$3C
db $26, $C0, $04, $39,$3A,$39,$3A
db $26, $E0, $04, $3B,$3C,$3B,$3C
db $27, $00, $04, $39,$3A,$39,$3A
db $27, $20, $04, $3B,$3C,$3B,$3C
db $27, $E0, $01, $44
db $27, $E8, $01, $55

; chasm right
db $26, $0C, $02, $39,$3A
db $26, $2C, $02, $3B,$3C
db $26, $4C, $02, $39,$3A
db $26, $6C, $02, $3B,$3C
db $26, $8C, $04, $39,$3A,$39,$3A
db $26, $AC, $04, $3B,$3C,$3B,$3C
db $26, $CC, $04, $39,$3A,$39,$3A
db $26, $EC, $04, $3B,$3C,$3B,$3C
db $27, $0C, $04, $39,$3A,$39,$3A
db $27, $2C, $04, $3B,$3C,$3B,$3C
db $27, $E3, $01, $11
db $27, $EB, $01, $55

; passageway top
db $24, $9C, $04, $39,$3A,$39,$3A
db $24, $BC, $04, $3B,$3C,$3B,$3C
db $24, $DC, $04, $39,$3A,$39,$3A
db $24, $FC, $04, $3B,$3C,$3B,$3C
db $25, $1C, $04, $39,$3A,$39,$3A
db $25, $3C, $04, $3B,$3C,$3B,$3C
db $27, $CF, $01, $55
db $27, $D7, $01, $05

; passageway bottom
db $26, $9C, $04, $39,$3A,$39,$3A
db $26, $BC, $04, $3B,$3C,$3B,$3C
db $26, $DC, $04, $39,$3A,$39,$3A
db $26, $FC, $04, $3B,$3C,$3B,$3C
db $27, $1C, $04, $39,$3A,$39,$3A
db $27, $3C, $04, $3B,$3C,$3B,$3C
db $27, $EF, $01, $55

; seaweed 1
db $26, $D2, 2, $3D,$3E
db $26, $F2, 2, $3F,$40
db $27, $12, 2, $3D,$3E
db $27, $32, 2, $3F,$40
db $27, $E5, 1, $88
db $27, $EC, 2, $80, $88
db $27, $F4, 2, $58, $58

; seaweed 2
db $26, $56, 2, $3D,$3E
db $26, $76, 2, $3F,$40
db $26, $96, 2, $3D,$3E
db $26, $B6, 2, $3F,$40
db $26, $D6, 2, $3D,$3E
db $26, $F6, 2, $3F,$40
db $27, $16, 2, $3D,$3E
db $27, $36, 2, $3F,$40

; chest 1
db $27, $18, 2, $42,$43
db $27, $38, 2, $44,$45
db $27, $F6, 1, $5F

.db $24, $E2, 12 : .char "Remixed with"
.db $25, $24, 9  : .char "in Norway"

.db $25, $91, 12 : .char "Use D-pad to"
.db $25, $D0, 15 : .char "toggle channels"

.db 0

.char "MADE BY KENT HANSEN" : .db 0

@@palette:
; 0 - background and text
.db $01,$06,$12,$30
; 1 - rocks
.db $01,$23,$03,$0F
; 2 - seaweed
.db $01,$19,$0B,$2A
; 3 - chest
.db $01,$0F,$17,$27
; 0 - bubble
.db $01,$22,$37,$32
; 1 - red fish
.db $01,$06,$20,$17
; 2 - gray fish
.db $01,$00,$20,$10
; 3 - big fish
.db $01,$08,$20,$15
.endp

.proc prng
    lda random
    lsr
    bcc +
    eor #$B4
  + sta random
    rts
.endp

.proc main_handler
    jsr reset_sprites
    jsr scroll_screen
    jsr maybe_spawn_creature
    jsr maybe_spawn_bubble
    jsr update_objects
    jsr update_pulsating_heart
    jsr mute_or_unmute_channels
    progbuf_load main_handler
    jmp progbuf_push
.endp

.proc update_pulsating_heart
    lda frame_count
    and #7
    beq +
    rts
  + ; upper half
    ldy #$24
    lda #$EF
    ldx #2
    jsr begin_ppu_string
    lda frame_count
    lsr : lsr : lsr
    and #3
    tay
    lda #$46
    adc @@tile_offsets,y
    sta ppu_buffer,x
    inx
    lda #$47
    adc @@tile_offsets,y
    sta ppu_buffer,x
    inx
    jsr end_ppu_string
    ; lower half
    ldy #$25
    lda #$0F
    ldx #2
    jsr begin_ppu_string
    lda frame_count
    lsr : lsr : lsr
    and #3
    tay
    lda #$48
    adc @@tile_offsets,y
    sta ppu_buffer,x
    inx
    lda #$49
    adc @@tile_offsets,y
    sta ppu_buffer,x
    inx
    jmp end_ppu_string
    @@tile_offsets:
    db 0, 4, 8, 4
    rts
.endp

.proc scroll_screen
    lda frame_count
    and #15
    bne @@no_scroll
    inc ppu.scroll_x
    bne @@no_scroll
    lda world_page
    clc
    adc #1
    sta world_page
    lda ppu.ctrl0
    eor #1
    sta ppu.ctrl0
    @@no_scroll:
    rts
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
    ldy #object::state_0
    lda [current_object], y
    and #3 ; type
    beq @@is_bubble
    cmp #1
    beq @@is_fish
    cmp #2
    beq @@is_blooper
    jmp update_big_fish
    @@is_bubble:
    jmp update_bubble
    @@is_fish:
    jmp update_fish
    @@is_blooper:
    jmp update_blooper
.endp

.proc maybe_spawn_creature
    inc spawn_creature_timer
    lda spawn_creature_timer
    cmp #230
    bcc @@no_spawn
    lda #0
    sta spawn_creature_timer
    beq spawn_creature
@@no_spawn:
    sta spawn_creature_timer
    rts
.endp

.proc spawn_creature
    jsr allocate_object
    jsr prng
    cmp #192
    bcc @@spawn_fish
    cmp #232
    bcc @@spawn_blooper
    ; spawn big fish
    lda #3
    bne +
    @@spawn_fish:
    lda #1
    bne +
    @@spawn_blooper:
    lda #2
  + ldy #object::state_0
    sta [tp],y ; type
    jsr prng
    pha
    and #1 ; direction
    asl
    asl
    ora [tp], y ; state_0
    sta [tp], y
    pla
    cmp #176
    bcc +
    lda [tp], y ; state_0
    ora #8 ; special species
    sta [tp], y
  + lda #0
    ldy #object::state_1
    sta [tp],y
    ldy #(object::pos_y + fp_8_8::frac)
    sta [tp],y
    ldy #(object::pos_x + fp_16_8::frac)
    sta [tp],y
    ldy #(object::pos_y + fp_8_8::int)
    jsr prng
    cmp #64
    bcs +
    adc #64
    bcc ++
  + cmp #208
    bcc ++
    sbc #48
 ++ sta [tp],y
    ldx #8
    ldy #object::state_0
    lda [tp], y
    and #4
    beq +
    ldx #255
  + txa
    adc ppu.scroll_x
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    sta [tp],y
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda world_page
    bcc +
    adc #0
  + sta [tp],y
    rts
.endp

.proc maybe_spawn_bubble
    inc spawn_bubble_timer
    lda spawn_bubble_timer
    cmp #118
    bcc @@no_spawn
    lda #0
    sta spawn_bubble_timer
    beq spawn_bubble
@@no_spawn:
    sta spawn_bubble_timer
    rts
.endp

.proc spawn_bubble
    jsr allocate_object
    ldy #object::state_0
    lda #0 ; type (0=bubble)
    sta [tp],y
    ldy #object::state_1
    sta [tp],y
    ldy #(object::pos_y + fp_8_8::frac)
    sta [tp],y
    ldy #(object::pos_x + fp_16_8::frac)
    sta [tp],y
    ldy #(object::pos_y + fp_8_8::int)
    lda #247
    sta [tp],y
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    jsr prng
    clc
    adc ppu.scroll_x
    sta [tp],y
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda world_page
    bcc +
    adc #0
  + sta [tp],y
    rts
.endp

.proc convert_object_world_position_to_screen_position
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    sec
    sbc ppu.scroll_x
    ldy #object::screen_x
    sta [current_object], y
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    sbc world_page
    beq @@is_on_screen
    ldy #object::state_0
    lda [current_object], y
    ora #$80 ; off screen
    sta [current_object], y
    rts
    @@is_on_screen:
    ldy #object::state_0
    lda [current_object], y
    and #$7F ; on screen
    sta [current_object], y
    rts
.endp

.proc update_big_fish
    ldy #object::state_0
    lda [current_object], y
    and #4
    beq @@move_right
    ; move left
    ldy #(object::pos_x + fp_16_8::frac)
    lda [current_object], y
    sec
    sbc #192
    sta [current_object], y
    bcs +
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    sbc #0
    sta [current_object], y
    bcs +
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    sbc #0
    sta [current_object], y
  + jsr convert_object_world_position_to_screen_position
    bmi @@kill_it
    ldy #object::screen_x
    lda [current_object], y
    cmp #8
    bcc @@kill_it
    and #8
    beq +
    jmp draw_big_fish_left_frame0
    @@kill_it:
    inc kill_me
    rts
  + jmp draw_big_fish_left_frame1
    @@move_right:
    ldy #(object::pos_x + fp_16_8::frac)
    lda [current_object], y
    clc
    adc #192
    sta [current_object], y
    bcc +
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    adc #0
    sta [current_object], y
    bcc +
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    adc #0
    sta [current_object], y
  + jsr convert_object_world_position_to_screen_position
    bmi @@kill_it
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    and #8
    beq +
    jmp draw_big_fish_right_frame0
  + jmp draw_big_fish_right_frame1
.endp

.proc draw_big_fish_right_frame0
  ; top, left
  jsr next_sprite_index
  tax
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #12
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$1B
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; top, middle
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #4
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$19
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; top, right
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  clc
  adc #4
  bcs +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$17
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; bottom, left
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #12
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$21
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; bottom, middle
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #4
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$1F
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; bottom, right
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  clc
  adc #4
  bcs +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$1D
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
+ rts
.endp

.proc draw_big_fish_right_frame1
  ; top, left
  jsr next_sprite_index
  tax
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #12
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$27
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; top, middle
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #4
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$25
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; top, right
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  clc
  adc #4
  bcs +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$23
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; bottom, left
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #12
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$2D
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; bottom, middle
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #4
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$2B
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; bottom, right
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  clc
  adc #4
  bcs +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$29
  sta sprites.tile,x
  lda #(3 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
+ rts
.endp

.proc draw_big_fish_left_frame0
  ; top, left
  jsr next_sprite_index
  tax
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #12
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$17
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
  ; top, middle
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #4
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$19
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
  ; top, right
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  clc
  adc #4
  bcs +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$1B
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
  ; bottom, left
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #12
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$1D
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
  ; bottom, middle
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #4
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$1F
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
  ; bottom, right
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  clc
  adc #4
  bcs +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$21
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
+ rts
.endp

.proc draw_big_fish_left_frame1
  ; top, left
  jsr next_sprite_index
  tax
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #12
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$23
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
  ; top, middle
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #4
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$25
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
  ; top, right
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  clc
  adc #4
  bcs +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  lda #$27
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
  ; bottom, left
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #12
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$29
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
  ; bottom, middle
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #4
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$2B
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
  ; bottom, right
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  clc
  adc #4
  bcs +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  lda #$2D
  sta sprites.tile,x
  lda #3
  sta sprites.attr,x
+ rts
.endp

.proc update_fish
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    and #$20
    bne @@move_down
    ; move up
    ldy #(object::pos_y + fp_8_8::frac)
    lda [current_object], y
    clc
    adc #24
    sta [current_object], y
    bcc @@move_horizontally
    ldy #(object::pos_y + fp_8_8::int)
    lda [current_object], y
    adc #0
    sta [current_object], y
    jmp @@move_horizontally
    @@move_down:
    ldy #(object::pos_y + fp_8_8::frac)
    lda [current_object], y
    sec
    sbc #24
    sta [current_object], y
    bcs @@move_horizontally
    ldy #(object::pos_y + fp_8_8::int)
    lda [current_object], y
    sbc #0
    sta [current_object], y
    @@move_horizontally:
    ldy #object::state_0
    lda [current_object], y
    and #4
    beq @@move_right
    ; move left
    ldy #(object::pos_x + fp_16_8::frac)
    lda [current_object], y
    sec
    sbc #64
    sta [current_object], y
    bcs +
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    sbc #0
    sta [current_object], y
    bcs +
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    sbc #0
    sta [current_object], y
  + jsr convert_object_world_position_to_screen_position
    bmi @@kill_it
    ldy #object::screen_x
    lda [current_object], y
    cmp #8
    bcc @@kill_it
    and #4
    bne +
    jmp draw_fish_left_frame0
    @@kill_it:
    inc kill_me
    rts
  + jmp draw_fish_left_frame1
    @@move_right:
    ldy #(object::pos_x + fp_16_8::frac)
    lda [current_object], y
    clc
    adc #64
    sta [current_object], y
    bcc +
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    adc #0
    sta [current_object], y
    bcc +
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    adc #0
    sta [current_object], y
  + jsr convert_object_world_position_to_screen_position
    bmi @@kill_it
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    and #4
    bne +
    beq draw_fish_right_frame0
  + jmp draw_fish_right_frame1
.endp

.proc draw_fish_right_frame0
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  lda #$01
  sta sprites.tile,x
  ldy #object::state_0
  lda [current_object], y
  and #8 ; sub-species
  lsr
  lsr
  lsr
  adc #1
  pha
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  lda #$03
  sta sprites.tile,x
  pla
  sta sprites.attr,x
  rts
.endp

.proc draw_fish_right_frame1
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  lda #$05
  sta sprites.tile,x
  ldy #object::state_0
  lda [current_object], y
  and #8 ; sub-species
  lsr
  lsr
  lsr
  adc #1
  pha
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  lda #$03
  sta sprites.tile,x
  pla
  sta sprites.attr,x
  rts
.endp

.proc draw_fish_left_frame0
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  lda #$03
  sta sprites.tile,x
  ldy #object::state_0
  lda [current_object], y
  and #8 ; sub-species
  lsr
  lsr
  lsr
  adc #1
  ora #SPRITE_ATTR_H_FLIP
  pha
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  lda #$01
  sta sprites.tile,x
  pla
  sta sprites.attr,x
  rts
.endp

.proc draw_fish_left_frame1
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  lda #$03
  sta sprites.tile,x
  ldy #object::state_0
  lda [current_object], y
  and #8 ; sub-species
  lsr
  lsr
  lsr
  adc #1
  ora #SPRITE_ATTR_H_FLIP
  pha
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  lda #$05
  sta sprites.tile,x
  pla
  sta sprites.attr,x
  rts
.endp

.proc update_blooper
    ldy #object::state_0
    lda [current_object], y
    and #$10 ; phase. 0 = propelling, 1 = resting
    beq @@is_propelling
    jmp @@is_resting
    @@is_propelling:
    lda [current_object], y
    and #4 ; direction. 0=right, 1=left
    beq @@propel_right
    ; propel left
    ldy #(object::pos_x + fp_16_8::frac)
    lda [current_object], y
    sec
    sbc #128
    sta [current_object], y
    bcs @@propel_up
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    sbc #0
    sta [current_object], y
    bcs @@propel_up
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    sbc #0
    sta [current_object], y
    @@propel_up:
    ldy #(object::pos_y + fp_8_8::frac)
    lda [current_object], y
    sec
    sbc #64
    sta [current_object], y
    bcs @@done_propel
    ldy #(object::pos_y + fp_8_8::int)
    lda [current_object], y
    sbc #0
    sta [current_object], y
    @@done_propel:
    ldy #object::state_1
    lda [current_object], y
    clc
    adc #1
    sta [current_object], y
    cmp #64
    bcc @@no_rest
    ; switch to resting
    lda #0
    sta [current_object], y
    ldy #object::state_0
    lda [current_object], y
    ora #$10
    sta [current_object], y
    @@no_rest:
    jsr convert_object_world_position_to_screen_position
    bmi @@kill_it
    ldy #object::screen_x
    lda [current_object], y
    cmp #8
    bcc @@kill_it
    jmp draw_blooper_frame0
    @@kill_it:
    inc kill_me
    rts
    @@propel_right:
    ldy #(object::pos_x + fp_16_8::frac)
    lda [current_object], y
    clc
    adc #128
    sta [current_object], y
    bcc @@propel_up
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    adc #0
    sta [current_object], y
    bcc @@propel_up
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    adc #0
    sta [current_object], y
    jmp @@propel_up
    @@is_resting:
    ldy #(object::pos_y + fp_8_8::frac)
    lda [current_object], y
    clc
    adc #64
    sta [current_object], y
    bcc @@no_y_inc
    ldy #(object::pos_y + fp_8_8::int)
    lda [current_object], y
    adc #0
    sta [current_object], y
    @@no_y_inc:
    ldy #object::state_1
    lda [current_object], y
    clc
    adc #1
    sta [current_object], y
    cmp #64
    bcc @@no_propel
    ; switch to propelling
    lda #0
    sta [current_object], y
    ldy #object::state_0
    lda [current_object], y
    and #~$10
    sta [current_object], y
    @@no_propel:
    jsr convert_object_world_position_to_screen_position
    bmi @@kill_it
    bpl draw_blooper_frame1
.endp

.proc draw_blooper_frame0
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  lda #$07
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  lda #$07
  sta sprites.tile,x
  lda #(2 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  rts
.endp

.proc draw_blooper_frame1
  ; left half, top
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  lda #$09
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; right half, top
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  lda #$09
  sta sprites.tile,x
  lda #(2 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  ; left half, bottom
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  clc
  adc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  lda #$0B
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; right half, bottom
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  clc
  adc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  lda #$0B
  sta sprites.tile,x
  lda #(2 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  rts
.endp

.proc update_bubble
    ldy #object::state_1
    lda [current_object], y
    bmi @@is_bursting
    ; is rising
    clc
    adc #1
    and #$7F
    sta [current_object], y
    ; move up
    ldy #(object::pos_y + fp_8_8::frac)
    lda [current_object], y
    sec
    sbc #80
    sta [current_object], y
    bcs +
    ldy #(object::pos_y + fp_8_8::int)
    lda [current_object], y
    sec
    sbc #1
    sta [current_object], y
    cmp #32 ; reached the surface?
    bcs +
    @@burst_it:
    ldy #object::state_1
    lda #$80
    sta [current_object], y
    rts
  + ldy #(object::pos_y + fp_8_8::int)
    lda [current_object], y
    and #$10
    bne @@move_right
    ; move left
    ldy #(object::pos_x + fp_16_8::frac)
    lda [current_object], y
    sec
    sbc #48
    sta [current_object], y
    bcs @@done_moving
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    sec
    sbc #1
    sta [current_object], y
    jmp @@done_moving
    @@move_right:
    ldy #(object::pos_x + fp_16_8::frac)
    lda [current_object], y
    clc
    adc #48
    sta [current_object], y
    bcc @@done_moving
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    clc
    adc #1
    sta [current_object], y
    @@done_moving:
    jsr convert_object_world_position_to_screen_position
    bmi @@kill_it
    ldy #object::screen_x
    lda [current_object], y
    cmp #9
    bcc @@burst_it
    bcs draw_bubble_frame0
    @@is_bursting:
    clc
    adc #1
    sta [current_object], y
    cmp #$A8
    bcc @@no_kill
    @@kill_it:
    inc kill_me
    rts
    @@no_kill:
    cmp #$90
    bcc @@draw_frame1
    jmp draw_bubble_frame2
    @@draw_frame1:
    jmp draw_bubble_frame1
.endp

.proc draw_bubble_frame0
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  lda #$0D
  sta sprites.tile,x
  lda #0
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  lda #$0F
  sta sprites.tile,x
  lda #0
  sta sprites.attr,x
  rts
.endp

.proc draw_bubble_frame1
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  lda #$11
  sta sprites.tile,x
  lda #0
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  lda #$11
  sta sprites.tile,x
  lda #(0 | SPRITE_ATTR_H_FLIP)
  sta sprites.attr,x
  rts
.endp

.proc draw_bubble_frame2
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  lda #$13
  sta sprites.tile,x
  lda #0
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  lda #$15
  sta sprites.tile,x
  lda #0
  sta sprites.attr,x
  rts
.endp

.end
