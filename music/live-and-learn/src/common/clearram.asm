.codeseg

.public clear_ram

; Clears RAM at $0000-$07FF (not stack).
; Params: None
; Destroys: A, X

.proc clear_ram
    lda     #$00
    tax
  - sta     $00,x
    sta     $0200,x
    sta     $0300,x
    sta     $0400,x
    sta     $0500,x
    sta     $0600,x
    sta     $0700,x
    inx
    bne     -
    rts
.endp

.end
