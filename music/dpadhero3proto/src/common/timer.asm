.dataseg

MAX_TIMERS .equ 4

ticks_per_decr  .byte[MAX_TIMERS]
tick            .byte[MAX_TIMERS]
count           .byte[MAX_TIMERS]
callback_lo     .byte[MAX_TIMERS]
callback_hi     .byte[MAX_TIMERS]

.codeseg

.public reset_timers
.public start_timer
.public set_timer_callback
.public kill_timer
.public update_timers
.public start_zerotimer_with_callback
.public call_fptr

; Resets all timers.
; Params:  None
; Returns: Nothing
.proc reset_timers
    ldy #MAX_TIMERS-1
    lda #0
  - sta count,y
    dey
    bpl -
    rts
.endp

; Starts a timer.
; Afterwards you should call set_timer_callback() to set the function
; to be called when the timer hits zero.
; Timers are one-shot, i.e. they are automatically killed when they
; hit zero.
; Params:   A = count
;           Y = ticks per count decrement
; Returns:  X = timer ID

.proc start_timer
    pha
    ; find a free slot
    ldx #MAX_TIMERS-1
  - lda count,x
    beq +
    dex
    bpl -
; TODO
;    lda #<@@out_of_timer_handles_msg
;    ldy #>@@out_of_timer_handles_msg
;    jsr fatal_error
    jmp reset
    brk
  + tya
    sta ticks_per_decr,x
    sta tick,x
    pla
    sta count,x
    rts
.endp

; Sets the address of the timer callback.
; Params:  A, Y = address
;          X = timer ID
; Returns: Nothing
.proc set_timer_callback
    sta callback_lo,x
    tya
    sta callback_hi,x
    rts
.endp

; Kills a timer.
; Params:  X = timer ID
.proc kill_timer
    lda #0
    sta count,x
    rts
.endp

; Updates timers.
.proc update_timers
    ldx #MAX_TIMERS-1
  - lda count,x
    beq @@next
    lda tick,x
    sec
    sbc #1  ; ### dec tick,x not possible?
    sta tick,x
    bne @@next
    lda ticks_per_decr,x
    sta tick,x
    lda count,x
    sec
    sbc #1
    sta count,x
    bne @@next
    ; timeout
    txa
    pha
    lda callback_hi,x
    tay
    lda callback_lo,x
    jsr call_fptr
    pla
    tax
    @@next:
    dex
    bpl -
    rts
.endp

; Starts a "zero-timer" (i.e. a timer that will be triggered
; the next time update_timers() is called) with a given
; callback.
; Params:  A,Y = callback
.proc start_zerotimer_with_callback
    pha
    tya
    pha
    lda #1
    tay
    jsr start_timer
    pla
    tay
    pla
    jmp set_timer_callback
.endp

; Calls a function pointer.
; Params:  A, Y = pointer to function
; Destroys: A, X, Y
; Returns: What the function returns
.proc call_fptr
    sec
    sbc #1
    tax
    tya
    sbc #0
    pha
    txa
    pha
    rts
.endp

.end
