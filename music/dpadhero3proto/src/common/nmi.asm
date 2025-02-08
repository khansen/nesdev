.include "joypad.h"
.include "ppu.h"
.include "sprite.h"

.dataseg

.extrn ppu:ppu_state
.extrn sprites:byte

in_nmi .byte
frame_count .byte

.public frame_count

.codeseg

.public nmi

.extrn __progbuf_exec:proc
.extrn flush_ppu_buffer:proc
.extrn update_timers:proc
.ifndef NO_SOUND
.extrn update_sound:proc
.endif

nmi:
    sei
    pha                     ; preserve A
    txa
    pha                     ; preserve X
    tya
    pha                     ; preserve Y

    lda     ppu.ctrl1
    sta     PPU_CTRL1_REG

    lda     in_nmi
    bne     skip_nmi        ; skip the next part if the frame couldn't
                            ; finish before the NMI was triggered
    inc     in_nmi
    inc     frame_count

    jsr     flush_ppu_buffer

; update PPU control register 0
    lda     ppu.ctrl0
    sta     PPU_CTRL0_REG

; update scroll registers
    lda     PPU_STATUS_REG  ; reset H/V scroll flip flop
    lda     ppu.scroll_x
    sta     PPU_SCROLL_REG
    lda     ppu.scroll_y
    sta     PPU_SCROLL_REG

.ifndef NO_SPRITE_DMA
    lda     #0
    sta     SPRITE_ADDR_REG ; reset SPR-RAM address
    lda     #>sprites
    sta     SPRITE_DMA_REG
.endif

; read joypad(s)
.ifndef NO_JOYPAD0
    jsr     read_joypad
.endif
.ifndef NO_JOYPAD1
    jsr     read_joypad1
.endif

.ifndef NO_SOUND
    jsr     update_sound
.endif

    jsr     update_timers

    jsr     __progbuf_exec

    dec     in_nmi          ; = 0, NMI done
    skip_nmi:
    pla
    tay                     ; restore Y
    pla
    tax                     ; restore X
    pla                     ; restore A
    rti

.end
