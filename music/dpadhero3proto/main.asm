.include <common/joypad.h>
.include <common/progbuf.h>
.include <common/ppu.h>
.include <common/ppubuffer.h>
.include <common/ldc.h>
.include <common/sprite.h>

.dataseg zeropage

random .byte[2] ; TODO: fix bug when crossing page boundary

.codeseg

.public genesis
.public prng

.extrn screen_on:proc
.extrn set_play_note_callback:proc
.extrn mixer_reset:proc
.extrn start_song:proc
.extrn set_palette:proc
.extrn write_palette:proc
.extrn game_init:proc
.extrn game_handler:proc
.extrn frame_count:proc

.proc genesis
    jsr screen_off
    lda #$ff
    jsr fill_all_nametables
    jsr reset_sprites

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

    jsr screen_on
    progbuf_load wait_start_handler
    jmp progbuf_push

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

@@tilemap_data:
.db $21,$EC,4,$D0,$D1,$D2,$D3
.db $21,$F1,5,$D2,$D4,$D5,$D6,$D4
.db $23,$DB,$03,$AA,$AA,$AA
.db 0
.endp

.proc wait_start_handler
  jsr reset_sprites
  lda joypad0_posedge
  and #JOYPAD_BUTTON_START
  bne @@start
  progbuf_load wait_start_handler
  jmp progbuf_push
  @@start:
  lda frame_count
  sta random ; initialize seed
  jsr game_init
  progbuf_load game_handler
  jmp progbuf_push
 .endp

.proc noop
  rts
.endp

.proc prng
  lda random
  lsr
  bcc +
  eor #$B4
+ sta random
  rts
.endp

.end
