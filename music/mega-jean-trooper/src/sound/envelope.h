.ifndef ENVELOPE_H
.define ENVELOPE_H

.include <common/ptr.h>
.include <common/fixedpoint.h>

; Structure that describes a volume envelope's state.
.struc envelope_state
phase   .byte
ptr     .ptr    ; Pointer to envelope data
pos     .byte   ; Position in data
vol     .byte   ; Current volume
step    .byte   ; Volume increment
dest    .byte   ; Destination volume
hold    .byte   ; Hold length at destination
master  .byte
scaled_vol .byte
padding .byte[3] ; to get same size as track_state
.ends

; Flags for envelope_state.phase
ENV_RESET   .equ    $80
ENV_PROCESS .equ    $40
ENV_SUSTAIN .equ    $20

.endif  ; !ENVELOPE_H
