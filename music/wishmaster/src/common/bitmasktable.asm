; Description:
; The infamous bitmasktable.

.codeseg

.public bitmasktable

; Index by bit number (0..7) to get the corresponding 8-bit mask.
bitmasktable    .db %00000001
                .db %00000010
                .db %00000100
                .db %00001000
                .db %00010000
                .db %00100000
                .db %01000000
                .db %10000000

.end
