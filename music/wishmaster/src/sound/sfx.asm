; Description:
; Routines for starting and updating sound effects.

.include "mixer.h"

.dataseg zeropage

sfx .ptr

.codeseg

.public start_sfx
.public start_square_sfx
.public start_tri_sfx
.public start_noise_sfx
.public sfx_tick

.extrn mixer:mixer_state
.extrn sfx_table:ptr
.extrn mixer_invalidate_period_save:proc

; Starts playing a sound effect on given channel.
; Params:   A = SFX #
;           X = channel # * 4
; Destroys: Y
.proc start_sfx
    asl
    tay
    lda sfx_table.lo,y
    sta mixer.sfx.ptr.lo,x
    lda sfx_table.hi,y
    sta mixer.sfx.ptr.hi,x
    lda #1
    sta mixer.sfx.counter,x ; triggers on next sfx_tick()
    rts
.endp

; Starts playing a sound effect on square channel 1.
; Params:   Y = *_SFX (see sfx.h)
; Destroys: A, Y

.proc start_square_sfx
    txa
    pha
    ldx #4  ; square channel 1
    go_sfx:
    tya
    jsr start_sfx
    pla
    tax
    rts
.endp

.proc start_tri_sfx
    txa
    pha
    ldx #8  ; triangle channel
    jmp go_sfx
.endp

.proc start_noise_sfx
    txa
    pha
    ldx #12 ; noise channel
    jmp go_sfx
.endp

; Does one "tick" of SFX processing.
; Params:   X = offset into sfx array

.proc sfx_tick
    dec     mixer.sfx.counter,x
    bne     ++
    lda     mixer.sfx.ptr.lo,x
    sta     sfx.lo
    lda     mixer.sfx.ptr.hi,x
    sta     sfx.hi
    ldy     #0
    lda     [sfx],y
    bne     +
; end sfx
    sta     mixer.sfx.ptr.hi,x  ; NULL
    cpx     #8
    bcs     ++
    ; for square channels, force the mixer to refresh HW regs
    jmp     mixer_invalidate_period_save
 ++ rts
  + sta     mixer.sfx.counter,x ; # of ticks until next update
    iny
    ; write new values to sound regs
    lda     [sfx],y
    sta     $4000,x ; this works since sizeof(sfx_state) is 4 bytes
    iny
    lda     [sfx],y
    sta     $4001,x
    iny
    lda     [sfx],y
    sta     $4002,x
    iny
    lda     [sfx],y
    sta     $4003,x
    iny
    ; increment SFX pointer
    tya
    clc
    adc     mixer.sfx.ptr.lo,x
    sta     mixer.sfx.ptr.lo,x
    bcc     +
    inc     mixer.sfx.ptr.hi,x
  + rts
.endp

.end
