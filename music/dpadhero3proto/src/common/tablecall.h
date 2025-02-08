.ifndef TABLECALL_H
.define TABLECALL_H

; Define big-endian word
.macro DW_BE value
.db >(value), <(value)
.endm

; Define entry in table call table.
.macro TC_SLOT slot
DW_BE (slot)-1
.endm

; Exported symbols.
.extrn table_call:proc

.endif  ; !TABLECALL_H
