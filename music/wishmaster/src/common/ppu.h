; PPU defines.

.ifndef PPU_H
.define PPU_H

; Hardware regs.
PPU_CTRL0_REG       .equ    $2000
PPU_CTRL1_REG       .equ    $2001
PPU_STATUS_REG      .equ    $2002
PPU_SCROLL_REG      .equ    $2005
PPU_ADDR_REG        .equ    $2006
PPU_IO_REG          .equ    $2007

; Records which describe PPU reg layouts.
.record ppu_ctrl0 nmi_on_vblank:1, pad0:1, sprite_size:1, bg_table:1, sprite_table:1, ppu_addr_inc:1, name_table:2
.record ppu_ctrl1 emph:3, sprite_on:1, bg_on:1, sprite_clip:1, bg_clip:1, mono:1
.record ppu_status vblank:1, sprite0:1, sprite_overflow:1, pad0:5

; Field masks.
PPU_CTRL0_NMI               .equ    mask ppu_ctrl0::nmi_on_vblank
PPU_CTRL0_SPRITE_SIZE       .equ    mask ppu_ctrl0::sprite_size
PPU_CTRL0_BG_TABLE          .equ    mask ppu_ctrl0::bg_table
PPU_CTRL0_SPRITE_TABLE      .equ    mask ppu_ctrl0::sprite_table
PPU_CTRL0_PPU_ADDR_INC      .equ    mask ppu_ctrl0::ppu_addr_inc
PPU_CTRL0_NAME_TABLE        .equ    mask ppu_ctrl0::name_table

PPU_CTRL1_EMPH              .equ    mask ppu_ctrl1::emph
PPU_CTRL1_SPRITE_VISIBLE    .equ    mask ppu_ctrl1::sprite_on
PPU_CTRL1_BG_VISIBLE        .equ    mask ppu_ctrl1::bg_on
PPU_CTRL1_SPRITE_CLIP       .equ    mask ppu_ctrl1::sprite_clip
PPU_CTRL1_BG_CLIP           .equ    mask ppu_ctrl1::bg_clip
PPU_CTRL1_MONO              .equ    mask ppu_ctrl1::mono

PPU_STATUS_VBLANK           .equ    mask ppu_status::vblank
PPU_STATUS_SPRITE0          .equ    mask ppu_status::sprite0
PPU_STATUS_SPRITE_OVERFLOW  .equ    mask ppu_status::sprite_overflow

; Bitmasks that can be OR'ed together to create PPU_CTRL0_REG-compatible value.
PPU_CTRL0_NMI_ON            .equ    PPU_CTRL0_NMI
PPU_CTRL0_NMI_OFF           .equ    0
PPU_CTRL0_SPRITE_SIZE_8x8   .equ    0
PPU_CTRL0_SPRITE_SIZE_8x16  .equ    PPU_CTRL0_SPRITE_SIZE
PPU_CTRL0_BG_TABLE_0000     .equ    0
PPU_CTRL0_BG_TABLE_1000     .equ    PPU_CTRL0_BG_TABLE
PPU_CTRL0_SPRITE_TABLE_0000 .equ    0
PPU_CTRL0_SPRITE_TABLE_1000 .equ    PPU_CTRL0_SPRITE_TABLE
PPU_CTRL0_PPU_ADDR_INC_1    .equ    0
PPU_CTRL0_PPU_ADDR_INC_32   .equ    PPU_CTRL0_PPU_ADDR_INC

; Bitmasks that can be OR'ed together to create PPU_CTRL1_REG-compatible value.
PPU_CTRL1_SPRITE_ON         .equ    PPU_CTRL1_SPRITE_VISIBLE
PPU_CTRL1_SPRITE_OFF        .equ    0
PPU_CTRL1_BG_ON             .equ    PPU_CTRL1_BG_VISIBLE
PPU_CTRL1_BG_OFF            .equ    0
PPU_CTRL1_SPRITE_CLIP_ON    .equ    PPU_CTRL1_SPRITE_CLIP
PPU_CTRL1_SPRITE_CLIP_OFF   .equ    0
PPU_CTRL1_BG_CLIP_ON        .equ    PPU_CTRL1_BG_CLIP
PPU_CTRL1_BG_CLIP_OFF       .equ    0

; PPU state.
.struc ppu_state
ctrl0       .ppu_ctrl0
ctrl1       .ppu_ctrl1
scroll_x    .byte
scroll_y    .byte
.ends

; Exported symbols.
.extrn reset_screen:proc
.extrn screen_on:proc
.extrn screen_off:proc
.extrn nmi_on:proc
.extrn nmi_off:proc
.extrn fill_nametable:proc
.extrn fill_nametable_0_0:proc
.extrn fill_all_nametables:proc
.extrn get_scroll_xy:proc
.extrn set_scroll_xy:proc
.extrn write_ppu_data_at:label
.extrn copy_string_to_ppu_buffer:proc
.extrn copy_bytes_to_ppu_buffer:proc

.extrn ppu:ppu_state

.endif  ; !PPU_H
