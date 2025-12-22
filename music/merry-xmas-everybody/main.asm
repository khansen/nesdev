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
state .byte    ; 0
pos_x .fp_8_8  ; 1
pos_y .fp_8_8  ; 3
next .ptr      ; 5
.ends

.dataseg zeropage

random .byte
tp .ptr
current_object .ptr
kill_me .byte
objects_head .ptr
objects_free_head .ptr
spawn_creature_timer .byte

.dataseg

MAX_OBJECTS .equ 32
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
; packnam --width=18 --vram-address=0x2047 sladelogo.nam
.incbin "sladelogo.dat"
; packnam --width=24 --vram-address=x2104 sladeband.nam
.incbin "sladeband.dat"
.db $23,$26,20 : .char "MERRY XMAS EVERYBODY"
.db $23,$D0,$48,$50
.db $23,$D8,$58,$55
.db $23,$F0,$48,$AA
.db 0

.db "MADE BY KENT HANSEN" : .db 0

@@palette:
; 0 - logo
.db $0F,$16,$26,$37
; 1 - band
.db $0F,$00,$10,$20
; 2 - text
.db $0F,$1A,$3A,$3A
; 3
.db $0F,$0F,$2A,$1A
; 0 - snowflakes
.db $0F,$12,$22,$32
; 1
.db $0F,$07,$17,$20
; 2
.db $0F,$20,$06,$0F
; 3
.db $0F,$20,$06,$0F
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
    jsr maybe_spawn_creature
    jsr update_objects
    jsr mute_or_unmute_channels
    progbuf_load main_handler
    jmp progbuf_push
.endp

.proc maybe_spawn_creature
    inc spawn_creature_timer
    lda spawn_creature_timer
    cmp #37
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
    and #7 ; type
    ldy #object::state
    sta [tp],y
    lda #0
    ldy #(object::pos_y + fp_8_8::frac)
    sta [tp],y
    ldy #(object::pos_y + fp_8_8::int)
    sta [tp],y
    ldy #(object::pos_x + fp_8_8::frac)
    sta [tp],y
    jsr prng
    cmp #16
    bcs @@10
    adc #16
    @@10:
    cmp #240
    bcc @@20
    sbc #16
    @@20:
    ldy #(object::pos_x + fp_8_8::int)
    sta [tp],y
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
    ; move down
    ldy #(object::pos_y + fp_8_8::frac)
    lda [current_object],y
    clc
    adc #140
    sta [current_object],y
    ldy #(object::pos_y + fp_8_8::int)
    lda [current_object],y
    bcc @@10
    adc #0
    sta [current_object],y
    cmp #240
    bcc @@10
    ; fell off screen
    inc kill_me
    rts
@@10:
    ; move left or right
    ldy #(object::pos_x + fp_8_8::frac)
    and #$10
    beq @@move_right
    ; move left
    lda [current_object],y
    sec
    sbc #64
    sta [current_object],y
    bcs @@20
    ldy #(object::pos_x + fp_8_8::int)
    lda [current_object],y
    sbc #0
    sta [current_object],y
    jmp @@20
@@move_right:
    lda [current_object],y
    clc
    adc #64
    sta [current_object],y
    bcc @@20
    ldy #(object::pos_x + fp_8_8::int)
    lda [current_object],y
    adc #0
    sta [current_object],y
@@20:
    jmp draw_snowflake_frame0
.endp

.proc draw_snowflake_frame0
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #(object::pos_x + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  ldy #object::state
  lda [current_object], y
  and #7 ; type
  asl : asl
  pha
  ora #$01
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
  ldy #(object::pos_x + fp_8_8::int)
  lda [current_object], y
  sta sprites._x,x
  pla ; type * 4
  ora #$03
  sta sprites.tile,x
  lda #0
  sta sprites.attr,x
  rts
.endp

.end
