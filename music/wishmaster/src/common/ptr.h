.ifndef PTR_H
.define PTR_H

; 16-bit pointer.
.struc ptr
lo  .byte   ; low byte
hi  .byte   ; high byte
.ends

.endif  ; !PTR_H
