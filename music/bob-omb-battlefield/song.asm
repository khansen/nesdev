.codeseg

.public song_song

song_instrument_table:
dw env0
db $00,$00,$00,$18,$00,$00 ; 0
dw env0
db $00,$00,$00,$68,$00,$00 ; 1
dw env0
db $00,$00,$00,$88,$00,$00 ; 2
dw env0
db $00,$00,$00,$00,$00,$00 ; 3 triangle (infinite)
dw env3
db $00,$00,$00,$00,$00,$00 ; 4 noise (closed)
dw env4
db $00,$00,$00,$00,$00,$00 ; 5 noise (open)
dw env5
db $00,$00,$00,$00,$00,$00 ; 6 noise (snare)
dw env6
db $00,$00,$00,$80,$00,$00 ; 7 weird noise (closed) - reduce
dw env0
db $00,$00,$00,$00,$00,$00 ; 8 noise (infinite)
dw env13
db $00,$00,$00,$18,$00,$00 ; 9
dw env15
db $00,$00,$00,$68,$00,$00 ; 10
dw env13
db $00,$00,$00,$88,$00,$00 ; 11
dw env12
db $00,$00,$00,$18,$00,$00 ; 12

env0:
db $F0
db $00,$F0,$FF
db $F0,$00,$00
db $FF,$FF
env3:
db $F0
db $30,$00,$00
db $FF,$FF
env4:
db $F0
db $14,$00,$00
db $FF,$FF
env5:
db $F0
db $28,$00,$00
db $FF,$FF
env6:
db $D0
db $0A,$00,$00
db $FF,$FF
env12:
db $F0
db $50,$10,$00
db $50,$F0,$00
db $FF,$01
env13:
db $B0
db $0E,$10,$00
db $A0,$B0,$00
db $18,$10,$00
db $A0,$B0,$00
db $08,$28,$00
db $FF,$FF
env15:
db $F0
db $0C,$00,$00
db $FF,$FF    

.include "song.inc"

.end
