.ifndef PPUBUFFER_H
.define PPUBUFFER_H

; Exported symbols.
.extrn reset_ppu_buffer:proc
.extrn flush_ppu_buffer:proc
.extrn end_ppu_string:proc
.extrn begin_ppu_string:proc
.extrn put_ppu_string_byte:proc

.extrn ppu_buffer:byte
.extrn ppu_buffer_offset:byte

.endif
