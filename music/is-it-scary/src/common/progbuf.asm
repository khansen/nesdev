.dataseg zeropage

offset .byte
.define MAX_PROGBUF_LENGTH 8
items_lo .byte[MAX_PROGBUF_LENGTH]
items_hi .byte[MAX_PROGBUF_LENGTH]

.codeseg

.public __progbuf_exec
.public progbuf_init
.public progbuf_push

; A, Y = address of initial program
.proc progbuf_init
    ldx #0
    stx offset
    jmp progbuf_push
.endp

.proc __progbuf_exec
    ldx offset
  - dex
    bmi +
    lda items_hi,x
    pha
    lda items_lo,x
    pha
    jmp -
  + inx
    stx offset
    rts
.endp

; A, Y = address of program
.proc progbuf_push
    ldx offset
    sta items_lo,x
    sty items_hi,x
    inc offset
    rts
.endp

.end
