.ifndef FIXEDPOINT_H
.define FIXEDPOINT_H

.include "int16.h"

; 8.8 fixed-point.
.struc fp_8_8
int     .byte   ; integer part
frac    .byte   ; fractional part
.ends

; 16.8 fixed-point.
.struc fp_16_8
int     .int16  ; integer part
frac    .byte   ; fractional part
.ends

.endif  ; !FIXEDPOINT_H
