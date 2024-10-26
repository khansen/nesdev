; Description:
; Defines pointers to NMI, RESET, IRQ routines.
; Must be linked in at CPU address $FFFA.

.codeseg

.extrn nmi, reset, irq : word

.dw nmi, reset, irq

.end
