.ifndef SFX_H
.define SFX_H

.include <common/ptr.h>

.struc sfx_state
ptr     .ptr
counter .byte
pad0    .byte   ; important that structure is 4 bytes
.ends

; Exported symbols.
.extrn start_sfx:proc
.extrn start_square_sfx:proc
.extrn start_tri_sfx:proc
.extrn start_noise_sfx:proc
.extrn sfx_tick:proc

.endif  ; !SFX_H
