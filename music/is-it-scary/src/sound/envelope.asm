; Description:
; Real-time volume envelope processing.
; Only useful for channels 0, 1 and 3.
; Volume envelope format:
; Byte 0: Start volume (0..240)
; Series of 3-byte tuples: step, end volume, hold length
; Until integer part of step = $FF
; If next byte is also $FF, it's really the end
; Otherwise the envelope is looped from that offset (point)

.include "mixer.h"

.dataseg zeropage

; private variables
env .ptr

.codeseg

; exported API
.public envelope_tick

; external symbols
.extrn mixer:mixer_state

; Copies current volume envelope data pointer to local pointer.
; Params:  X = channel number
.macro set_env_ptr
    lda     mixer.envelopes.ptr.lo,x
    sta     env.lo
    lda     mixer.envelopes.ptr.hi,x
    sta     env.hi         ; set pointer to envelope
.endm

; Fetches next byte from volume envelope data.
; Params:  Y = envelope data offset (auto-incremented)
.macro fetch_env_byte
    lda     [env],y
    iny
.endm

; Does one tick of envelope processing.
; Params:  X = channel number

.proc envelope_tick
    lda     mixer.envelopes.phase,x
    bmi     @@init                ; phase = $80
    asl
    bmi     @@process             ; phase = $40
    asl
    bmi     @@sustain             ; phase = $20
    rts

    ; Initialize envelope
    @@init:
    lsr     mixer.envelopes.phase,x         ; phase = update envelope
    lda     #0
    sta     mixer.envelopes.pos,x           ; reset envelope position
    tay
    set_env_ptr
    fetch_env_byte
    sta     mixer.envelopes.vol,x        ; 1st byte = start volume
    ; Initialize envelope point
    @@point_init:
    fetch_env_byte
    cmp     #$FF                    ; $FF = end of envelope reached
    beq     @@env_end
    ; Point OK, set 3-tuple (step, dest, hold)
    sta     mixer.envelopes.step,x
    fetch_env_byte
    sta     mixer.envelopes.dest,x
    fetch_env_byte
    sta     mixer.envelopes.hold,x
    tya
    sta     mixer.envelopes.pos,x
    bne     @@process
    ; End of envelope reached (step.int = FF)
    @@env_end:
    fetch_env_byte  ; if FF, definitely end... otherwise loop
    cmp     #$FF
    beq     @@env_stop
    tay     ; loop the envelope
    jmp     @@point_init
    ; No more envelope processing
    @@env_stop:
    lda     #$00
    sta     mixer.envelopes.phase,x
  - rts

    ; Sustain volume until hold == 0.
    @@sustain:
    ldy     mixer.envelopes.hold,x
    iny
    beq     -                       ; sustain forever if length = $FF
    dec     mixer.envelopes.hold,x
    bne     -
    asl     mixer.envelopes.phase,x             ; back to phase = process
    jmp     @@next_point

    ; Update volume according to step
    @@process:
    lda     mixer.envelopes.vol,x
    cmp     mixer.envelopes.dest,x
    bcs     @@sub_volume
; CurrentVol < DestVol ==> CurrentVol += Step
    adc     mixer.envelopes.step,x
    bcs     @@reached_dest
    cmp     mixer.envelopes.dest,x
    bcs     @@reached_dest
    sta     mixer.envelopes.vol,x
    rts
; CurrentVol > DestVol ==> CurrentVol -= Step
    @@sub_volume:
    sbc     mixer.envelopes.step,x
    bcc     @@reached_dest
    cmp     mixer.envelopes.dest,x
    beq     @@reached_dest
    bcc     @@reached_dest
    sta     mixer.envelopes.vol,x
    rts
    ; Reached point's destination volume
    @@reached_dest:
    lda     mixer.envelopes.dest,x
    sta     mixer.envelopes.vol,x
    lda     mixer.envelopes.hold,x
    beq     @@next_point
    lsr     mixer.envelopes.phase,x             ; phase = sustain
    rts
    ; Start the next envelope point
    @@next_point:
    set_env_ptr
    ldy     mixer.envelopes.pos,x
    jmp     @@point_init
.endp

.end
