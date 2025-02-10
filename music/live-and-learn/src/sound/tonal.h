.ifndef TONAL_H
.define TONAL_H

.include <common/int16.h>
.include "effect.h"
.include "square.h"

.struc tonal_state
period_index    .byte
period          .int16
effect          .effect_state
.union
square          .square_state
.ends
instrument      .byte
pad0            .byte
.ends

.endif  ; !TONAL_H
