; Generated from mutesong.xm by xm2nes 6.0.1
mutesong_chn0_ptn0:
.db $40,$01,$D0,$F3,$00,$00,$00,$00,$00,$00,$00
mutesong_chn1_ptn0:
.db $40,$01,$D0,$F3,$00,$00,$00,$00,$00,$00,$00
mutesong_chn2_ptn0:
.db $40,$01,$D0,$F3,$00,$00,$00,$00,$00,$00,$00
mutesong_chn3_ptn0:
.db $40,$01,$D0,$F3,$00,$00,$00,$00,$00,$00,$00
mutesong_pattern_table:
.dw mutesong_chn0_ptn0
.dw mutesong_chn1_ptn0
.dw mutesong_chn2_ptn0
.dw mutesong_chn3_ptn0
mutesong_song:
.db 0,6
.db 3,6
.db 6,6
.db 9,6
.db $FF
.dw mutesong_instrument_table
.dw mutesong_pattern_table
.db $00
.db $FE,0
.db $01
.db $FE,3
.db $02
.db $FE,6
.db $03
.db $FE,9
