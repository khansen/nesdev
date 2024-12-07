.include "progbuf.h"
.include "ppu.h"

.codeseg

.extrn genesis:proc
.extrn nmi_on:proc

.public reset

reset:
    cld                     ; clear decimal mode
    sei
    ldx #$00
    stx PPU_CTRL0_REG       ; disable NMI and stuff
    stx PPU_CTRL1_REG       ; disable BG & SPR visibility and stuff
    dex                     ; X = FF
    txs                     ; S points to end of stack page (1FF)

  - lda PPU_STATUS_REG
    bpl -
  - lda PPU_STATUS_REG
    bpl -

    lda #$40
    sta $4017               ; disable erratic IRQ triggering

; clear RAM
    lda     #$00
    tax
  - sta     $00,x
    sta     $0100,x
    sta     $0200,x
    sta     $0300,x
    sta     $0400,x
    sta     $0500,x
    sta     $0600,x
    sta     $0700,x
    inx
    bne     -

    progbuf_load genesis
    jsr progbuf_init

; on with the NMI
    jsr     nmi_on
; enable interrupts
    cli

; eternal loop, everything happens in NMI
  - jmp     -

.end
