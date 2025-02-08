.ifndef TARGET_H
.define TARGET_H

.include <common/fixedpoint.h>

MAX_TARGETS .equ 32

; Holds the state of a falling target.
; Types:
; 0 - normal orb
; 1 - skull
; 2 - POW
; 3 - star
; 4 - clock
; 5 - letter (special orb)
; 6 - fake skull
; 7 - ???
.struc target_1
state .db    ; b2..0:lane, b5..b3:type, b7:exploding
pos_y .fp_8_8
pos_x .fp_8_8
pad0 .db
.ends

.struc target_2
speed_y .fp_8_8
speed_x .fp_8_8
duration .db ; number of rows it lasts
next .db     ; next target on linked list
.ends

.if sizeof target_1 != sizeof target_2
.error "target_1 and target_2 must have the same size"
.endif

.endif
