.include <common/progbuf.h>
.include <common/joypad.h>
.include <common/ppu.h>
.include <common/ppubuffer.h>
.include <common/ldc.h>
.include <common/sprite.h>
.include <common/ptr.h>

.dataseg zeropage

t0 .db
t1 .db
t2 .db
t3 .db
t4 .db
t5 .db
t6 .db
tp .ptr

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

    ldcay noop
    jsr set_play_note_callback
    lda #1
    jsr start_song

    jsr screen_on
    progbuf_load main_handler
    jmp progbuf_push

.charmap "song.tbl"
@@tilemap_data:
.db $21, $E6, 19 : .char "Welcome to Paradise"
.db $22, $47, 17 : .char "Original music by"
.db $22, $8B, 9 : .char "Green Day"
.db $22, $E9, 10 : .char "Remixed in"
.db $22, $F4, 2, $20,$21 ; flag
.db $23, $42, 28 : .char "Use D-pad to toggle channels"

.db $23, $ED, $01, $55 ; flag attribs

.incbin "logo.bin"
.db 0

.char "MADE BY KENT HANSEN" : .db 0

@@palette:
; 0 - background and text
.db $21,$0F,$18,$30
; 1 - flag
.db $21,$15,$11,$30
; 2 - unused
.db $21,$3C,$2C,$1C
; 3 - unused
.db $21,$0F,$0F,$0F
; orbs
.db $21,$06,$16,$36
.db $21,$09,$19,$39
.db $21,$01,$11,$31
.db $21,$0C,$1C,$3C
.endp

.proc main_handler
    jsr reset_sprites
    jsr mute_or_unmute_channels
    progbuf_load main_handler
    jmp progbuf_push
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

.end
