.ifndef PROGBUF_H
.define PROGBUF_H

.macro progbuf_load expr
    lda #<(expr)-1
    ldy #>(expr)-1
.endm

.extrn progbuf_init:proc
.extrn progbuf_push:proc

.endif ; PROGBUF_H
