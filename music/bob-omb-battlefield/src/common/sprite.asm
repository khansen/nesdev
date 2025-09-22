; Description:
; Basic sprite stuff.

.include "sprite.h"

.dataseg

; variables used to implement "sprite shuffling" from frame to frame
.public sprite_index    .byte
.public sprite_base     .byte

; sprite memory
.public sprites .sprite_state[64]

; must be page-aligned since we use sprite DMA
.align sprites 256

.codeseg

.public reset_sprites
.public next_sprite_index

; Sets Y coordinate of all sprites to outside screen
; and resets the sprite index.
; Params:  None
; Returns: Nothing
.proc reset_sprites
    lda #$F4
    ldx #0
  - sta sprites._y,x
    inx
    inx
    inx
    inx
    bne -
    lda sprite_base
    sta sprite_index
    clc
    adc #SPRITE_BASE_INCR
    sta sprite_base
    rts
.endp

.proc next_sprite_index
    lda     sprite_index
    clc
    adc     #SPRITE_INDEX_INCR
    sta     sprite_index
    rts
.endp

.end
