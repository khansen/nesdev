.ifndef SPRITE_H
.define SPRITE_H

; Hardware regs.
SPRITE_ADDR_REG     .equ     $2003
SPRITE_IO_REG       .equ     $2004
SPRITE_DMA_REG      .equ     $4014

; Record that describes a sprite's attributes.
.record sprite_attribs v_flip:1, h_flip:1, pri:1, pad0:3, pal:2

SPRITE_ATTR_V_FLIP  .equ mask sprite_attribs::v_flip
SPRITE_ATTR_H_FLIP  .equ mask sprite_attribs::h_flip
SPRITE_ATTR_PRI     .equ mask sprite_attribs::pri
SPRITE_ATTR_PAL     .equ mask sprite_attribs::pal

; Structure that describes a sprite.
; The field order is such that it can be DMA'ed directly to sprite RAM.
.struc sprite_state
_y      .byte
tile    .byte
attr    .sprite_attribs
_x      .byte
.ends

SPRITE_INDEX_INCR .equ 15*4
SPRITE_BASE_INCR  .equ 17*4

; Exported symbols.
.extrn reset_sprites:proc
.extrn next_sprite_index:proc

.extrn sprites:sprite_state
.extrn sprite_index:byte

.endif  ; !SPRITE_H
