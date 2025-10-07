.codeseg

.public song_song

song_instrument_table:
dw env0
db $00,$00,$00,$40,$00,$00 ; 0
dw env0
db $00,$00,$00,$80,$00,$00 ; 1
dw env0
db $00,$00,$00,$00,$00,$00 ; 2
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
db $00,$00,$00,$68,$00,$00 ; 9
dw env15
db $00,$00,$00,$18,$00,$00 ; 10
dw env13
db $00,$00,$00,$68,$00,$00 ; 11
dw env12
db $00,$00,$00,$18,$00,$00 ; 12 triangle (short)
dw env1
db $00,$00,$00,$18,$00,$00 ; 13 triangle (very short)
dw env2
db $00,$00,$00,$00,$00,$00 ; 14 noise (door creak)
dw env7
db $00,$05,$C0,$68,$00,$00 ; 15

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
db $00,$F0,$02
db $18,$00,$00
db $FF,$FF
env5:
db $F0
db $20,$00,$00
db $FF,$FF
env6:
db $D0
db $0A,$00,$00
db $FF,$FF
env12:
db $F0
db $12,$00,$00
db $FF,$FF
env13:
db $F0
db $10,$10,$00
db $FF,$FF
env15:
db $F0
db $10,$10,$00
db $60,$70,$00
db $04,$10,$00
db $FF,$FF
env1:
db $F0
db $26,$00,$00
db $FF,$FF
env2:
db $F0
db $40,$00,$00
db $F0,$F0,$00
db $40,$00,$00
db $F0,$F0,$00
db $40,$00,$00
db $F0,$F0,$00
db $40,$00,$00
db $FF,$FF
env7:
db $F0
db $28,$10,$00
db $40,$50,$00
db $18,$10,$00
db $FF,$FF

.include "song.inc"

.end
