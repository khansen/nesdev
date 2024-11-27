; Description:
; Core IRQ handling.
; Call set_irq_handler() to set the function to be executed when an
; IRQ happens.

.include "ptr.h"

.dataseg

irq_handler .ptr

.codeseg

.public irq
.public set_irq_handler

; IRQ entrypoint.

.proc irq
    sei
    pha
    txa
    pha
    tya
    pha
    jsr go_irq_handler
    pla
    tay
    pla
    tax
    pla
    rti
.endp

; Dispatches the IRQ handler.

.proc go_irq_handler
    jmp [irq_handler]
.endp

; Sets the IRQ handler routine.
; Params: A, Y = address of handler

.proc set_irq_handler
    sta irq_handler.lo
    sty irq_handler.hi
    rts
.endp

.end
