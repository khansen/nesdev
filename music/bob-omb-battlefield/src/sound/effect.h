.ifndef EFFECT_H
.define EFFECT_H

.include <common/int16.h>

; The possible kinds of effect.
.enum effect_kind
    NO_EFFECT
    SLIDE_UP_EFFECT
    SLIDE_DOWN_EFFECT
    PORTAMENTO_EFFECT
    VIBRATO_EFFECT
    ARPEGGIO_EFFECT
    VOLUME_SLIDE_EFFECT
    CUT_EFFECT
.ende

; State associated with slide up/down effect generator.
.struc slide_state
amount  .byte
.ends

; State associated with portamento effect generator.
.struc portamento_state
amount  .byte
ctrl    .byte   ; bit 7: halt. bit 0: direction
target  .int16  ; target period
.ends

.record vibrato_param speed:4, depth:4

; State associated with vibrato effect generator.
.struc vibrato_state
param   .vibrato_param
delay   .byte       ; Initial delay
counter .byte       ; Delay counter
pos     .byte       ; Position in vibrato lookup table
.ends

.record arpeggio_param first:4, second:4

; State associated with arpeggio effect generator.
.struc arpeggio_state
param   .arpeggio_param
pos     .byte
.ends

; Structure that describes effect state.
.struc effect_state
kind        .effect_kind
.union
slide       .slide_state        ; kind == SLIDE_*_EFFECT
portamento  .portamento_state   ; kind == PORTAMENTO_EFFECT
vibrato     .vibrato_state      ; kind == VIBRATO_EFFECT
arpeggio    .arpeggio_state     ; kind == ARPEGGIO_EFFECT
tremolo     .vibrato_state      ; kind == TREMOLO_EFFECT
.ends
.ends

.endif  ; !EFFECT_H
