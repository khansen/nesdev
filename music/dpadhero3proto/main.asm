.include <common/progbuf.h>
.include <common/ppu.h>
.include <common/ppubuffer.h>
.include <common/ldc.h>
.include <common/sprite.h>

.codeseg

.public genesis

.extrn screen_on:proc
.extrn set_play_note_callback:proc
.extrn mixer_reset:proc
.extrn start_song:proc
.extrn set_palette:proc
.extrn write_palette:proc
.extrn game_init:proc
.extrn game_handler:proc

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

    ldcay noop
    jsr set_play_note_callback
    jsr mixer_reset

    jsr game_init
    jsr screen_on
    progbuf_load game_handler
    jmp progbuf_push

.charmap "song.tbl"
@@tilemap_data:
.incbin "gameboyskintilemap.bin"
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

@@palette:
; 0 - skin
.db $0F,$01,$00,$10
; 1 - battery indicator
.db $0F,$01,$06,$16
; 2 - play field
.db $0F,$1C,$27,$39
; 3 - unused
.db $0F,$0F,$0F,$0F
; 4 - buttons
.db $0F,$1C,$0F,$39
; 5 - unused
.db $0F,$1C,$0F,$39
; 6 - unused
.db $0F,$1C,$0F,$39
; 7 - unused
.db $0F,$1C,$0F,$39
.endp

.proc draw_button_sprites
    ; B button
    ; left part
    jsr next_sprite_index
    tax
    lda #128
    sta sprites._y,x
    lda #128
    sta sprites._x,x
    lda #1
    sta sprites.tile,x
    lda #0
    sta sprites.attr,x
    ; right part
    jsr next_sprite_index
    tax
    lda #128
    sta sprites._y,x
    lda #(128+8)
    sta sprites._x,x
    lda #3
    sta sprites.tile,x
    lda #0
    sta sprites.attr,x

    ; A button
    ; left part
    jsr next_sprite_index
    tax
    lda #128
    sta sprites._y,x
    lda #(128+16)
    sta sprites._x,x
    lda #5
    sta sprites.tile,x
    lda #0
    sta sprites.attr,x
    ; right part
    jsr next_sprite_index
    tax
    lda #128
    sta sprites._y,x
    lda #(128+16+8)
    sta sprites._x,x
    lda #7
    sta sprites.tile,x
    lda #0
    sta sprites.attr,x

    ; Left arrow
    ; left part
    jsr next_sprite_index
    tax
    lda #128
    sta sprites._y,x
    lda #80
    sta sprites._x,x
    lda #9
    sta sprites.tile,x
    lda #0
    sta sprites.attr,x
    ; right part
    jsr next_sprite_index
    tax
    lda #128
    sta sprites._y,x
    lda #(80+8)
    sta sprites._x,x
    lda #11
    sta sprites.tile,x
    lda #0
    sta sprites.attr,x

    ; left part
    jsr next_sprite_index
    tax
    lda #128
    sta sprites._y,x
    lda #(80+16)
    sta sprites._x,x
    lda #13
    sta sprites.tile,x
    lda #0
    sta sprites.attr,x
    ; right part
    jsr next_sprite_index
    tax
    lda #128
    sta sprites._y,x
    lda #(80+16+8)
    sta sprites._x,x
    lda #15
    sta sprites.tile,x
    lda #0
    sta sprites.attr,x
    rts
.endp

.proc noop
  rts
.endp

.end
