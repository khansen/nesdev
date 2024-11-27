.ifndef JOYPAD_H
.define JOYPAD_H

JOYPAD0_IO_REG   .equ $4016
JOYPAD1_IO_REG   .equ $4017

.record joypad _a:1, _b:1, select:1, start:1, up:1, down:1, left:1, right:1

JOYPAD_BUTTON_A         .equ mask joypad::_a
JOYPAD_BUTTON_B         .equ mask joypad::_b
JOYPAD_BUTTON_SELECT    .equ mask joypad::select
JOYPAD_BUTTON_START     .equ mask joypad::start
JOYPAD_BUTTON_UP        .equ mask joypad::up
JOYPAD_BUTTON_DOWN      .equ mask joypad::down
JOYPAD_BUTTON_LEFT      .equ mask joypad::left
JOYPAD_BUTTON_RIGHT     .equ mask joypad::right

; Exported symbols.
.extrn joypad0:joypad
.extrn joypad0_posedge:joypad
.extrn read_joypad:proc
.ifndef NO_JOYPAD1
.extrn joypad1:joypad
.extrn joypad1_posedge:joypad
.extrn read_joypad1:proc
.endif

.endif  ; !JOYPAD_H
