; Description:
; Jump table entrypoint.

.include "ptr.h"

.dataseg zeropage

addr_table .ptr

.codeseg

.public table_call

; Calls one in an array of procedures.
; A: Routine # to execute
; A is used as an index into a table of code addresses.
; The jump table itself MUST be located directly after the JSR to this
; routine, so that its address can be popped from the stack.
.proc table_call
    asl
    tay
    iny     ; b/c stack holds jump table address MINUS 1
    pla     ; low address of table
    sta addr_table.lo
    pla     ; high address of table
    sta addr_table.hi
    lda [addr_table],y
    pha
    iny
    lda [addr_table],y
    pha
    rts     ; jump to address
.endp

.end
