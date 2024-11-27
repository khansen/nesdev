; Sequencer track definitions.

.ifndef TRACK_H
.define TRACK_H

.include <common/ptr.h>

.struc order_state
pos         .byte               ; Position in order table
loop_pos    .byte               ; Order loop position
loop_count  .byte               ; Order loop count
.ends

.struc pattern_state
ptr         .ptr                ; Pointer to pattern
pos         .byte               ; Pattern position (byte offset)
loop_count  .byte               ; Pattern loop count
row         .byte               ; Row in pattern
row_count   .byte               ; Number of rows in pattern
row_status  .byte               ; on/off bits
transpose   .byte               ; Note transpose
.ends

; Structure that describes a sequencer track's state.
.struc track_state
speed               .byte       ; Number of ticks (frames) per row inc
tick                .byte       ; Tick in row
order               .order_state
pattern             .pattern_state
.ends

.endif  ; !TRACK_H
