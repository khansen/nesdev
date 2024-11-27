.ifndef SQUARE_H
.define SQUARE_H

.include "apu.h"

.struc square_state
duty_ctrl   .byte
duty        .byte
counter     .byte
period_save .byte
.ends

.endif  ; !SQUARE_H
