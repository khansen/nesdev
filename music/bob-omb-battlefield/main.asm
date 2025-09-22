.include <common/fixedpoint.h>
.include <common/progbuf.h>
.include <common/joypad.h>
.include <common/ppu.h>
.include <common/ppubuffer.h>
.include <common/ldc.h>
.include <common/sprite.h>
.include <common/ptr.h>
.include <sound/track.h>

.struc object
state_0 .byte  ; 0
state_1 .byte  ; 1
pos_x .fp_16_8 ; 2
pos_y .fp_8_8  ; 5
screen_x .byte ; 7
next .ptr      ; 8
.ends

.dataseg zeropage

random .byte
world_page .byte
tp .ptr
current_object .ptr
kill_me .byte
objects_head .ptr
objects_free_head .ptr
spawn_creature_timer .byte

explode_request .byte

.dataseg

MAX_OBJECTS .equ 25
objects_arena .object[MAX_OBJECTS]

.codeseg

.public genesis

.extrn screen_on:proc
.extrn set_play_note_callback:proc
.extrn mixer_reset:proc
.extrn start_song:proc
.extrn set_palette:proc
.extrn write_palette:proc
.extrn reset_sprites:proc
.extrn sound_status:byte
.extrn frame_count:byte

.proc genesis
    jsr screen_off
    lda #0
    jsr fill_all_nametables

    lda ppu.ctrl0
    and #~(PPU_CTRL0_SPRITE_SIZE | PPU_CTRL0_BG_TABLE | PPU_CTRL0_SPRITE_TABLE)
    ora #(PPU_CTRL0_SPRITE_SIZE_8x16 | PPU_CTRL0_BG_TABLE_0000 | PPU_CTRL0_SPRITE_TABLE_1000)
    sta ppu.ctrl0
    lda #6 ; clip off
    sta ppu.ctrl1

    ldcay @@palette
    jsr set_palette
    jsr write_palette

    ldcay @@tilemap_data
    jsr write_ppu_data_at

    jsr init_objects
    ; initialize seed
    lda #237
    sta random

    ldcay noop
    jsr set_play_note_callback
    jsr mixer_reset
    lda #1
    jsr start_song

    jsr screen_on
    progbuf_load main_handler
    jmp progbuf_push

.charmap "song.tbl"
@@tilemap_data:
; Screen 1
; hill
.db $25,$C4,$04,$50,$51,$52,$53
.db $25,$E3,$06,$39,$44,$45,$44,$45,$3A
.db $26,$02,$08,$38,$44,$45,$44,$45,$44,$45,$3B
.db $26,$20,$0C,$50,$51,$44,$45,$44,$45,$44,$45,$44,$45,$52,$53
.db $26,$40,$0E,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$3A,$A0
.db $26,$60,$0E,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$59
.db $26,$80,$10,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$62,$63
.db $26,$A0,$11,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$58
.db $26,$C0,$12,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$59
.db $26,$E0,$14,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$62,$63
.db $27,$00,$15,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$49,$45,$44,$45,$44,$58
.db $27,$20,$16,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$49,$45,$44,$45,$44,$59
.db $27,$40,$18,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$3E,$86,$49,$44,$45,$44,$62,$53
.db $27,$60,$18,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$41,$3E,$3E,$86,$49,$45,$44,$45
.db $27,$80,$51,$3D
.db $27,$91,$07,$3F,$40,$3F,$41,$86,$87,$86
.db $27,$98,$08,$86,$87,$86,$48,$3F,$40,$3F,$3D
.db $27,$A0,$60,$3D
.db $27,$78,$08,$44,$45,$44,$4A,$86,$3E,$3E,$48
.db $27,$3A,$06,$50,$51,$44,$45,$4A,$3E
.db $27,$58,$08,$50,$51,$44,$45,$44,$4A,$3E,$3E
.db $27,$1C,$04,$38,$44,$45,$4A
.db $26,$FD,$03,$39,$44,$45
.db $26,$DE,$02,$50,$51
; flag
.db $25,$66,$02,$94,$95
.db $25,$86,$02,$96,$97
.db $25,$A6,$01,$98
; cacti
.db $26,$11,$04,$78,$79,$7A,$7B
.db $26,$31,$04,$7C,$3E,$3E,$7D
.db $26,$4D,$05,$78,$79,$7A,$7B,$7E
.db $26,$51,$04,$7E,$3E,$3E,$7F
.db $26,$71,$04,$7E,$3E,$3E,$7F
.db $26,$91,$06,$7E,$3E,$80,$81,$7A,$7B
.db $26,$B1,$06,$7E,$3E,$84,$3E,$3E,$7D
.db $26,$D2,$05,$3E,$3E,$3E,$3E,$7F
.db $26,$F4,$03,$3E,$3E,$7F
.db $27,$15,$02,$3E,$7F
.db $27,$36,$01,$7F
.db $26,$6E,$04,$3E,$3E,$7D,$7E
.db $26,$90,$02,$3E,$7E
.db $26,$B1,$01,$7E
; cloud 0
.db $24,$F6,$06,$70,$71,$70,$71,$70,$71
.db $25,$15,$08,$72,$3C,$3C,$3C,$3C,$3C,$3C,$73
.db $25,$35,$08,$74,$75,$76,$75,$76,$75,$76,$77
; cloud 1
.db $24,$67,$02,$70,$71
.db $24,$86,$04,$72,$3C,$3C,$73
.db $24,$A6,$04,$74,$75,$76,$77

.db $24, $E0, 12 : .char "Remixed with"
.db $25, $22, 9  : .char "in Norway"

.db $24, $72, 12 : .char "Requested by"
.db $24, $B4, 9  : .char "@RealSDM2"

.db $25, $8D, 19 : .char "Use D-pad, A & B to"
.db $25, $CF, 15 : .char "toggle channels"

; text & cloud attributes
.db $27,$C0,$58,$55
.db $27,$DB,$45,$55
; heart attributes
.db $27,$CB,$01,$AA
.db $27,$D3,$01,$AA
; patron attributes
.db $27,$CC,$44,$5F
; flag attributes
.db $27,$D1,$01,$A5
.db $27,$D9,$01,$0A

; Screen 0

.db $20, $69, 21 : .char "`Bob-Omb Battlefield`"

.db $20, $EB, 17 : .char "Original music by"
.db $21, $2E, 10 : .char "Koji Kondo"

; big cacti
.db $21,$C4,$04,$78,$79,$7A,$7B
.db $21,$E4,$04,$7C,$3E,$3E,$7D
.db $22,$02,$0A,$78,$79,$82,$83,$3E,$7F,$78,$79,$7A,$7B
.db $22,$22,$0A,$7C,$3E,$3E,$85,$3E,$7F,$7C,$3E,$3E,$7D
.db $22,$42,$0C,$7E,$3E,$80,$81,$82,$83,$3E,$3E,$80,$81,$82,$7B
.db $22,$62,$0C,$7E,$3E,$84,$3E,$3E,$85,$3E,$3E,$84,$3E,$3E,$7D
.db $22,$82,$0C,$7E,$3E,$3E,$3E,$80,$81,$82,$83,$3E,$3E,$3E,$7F
.db $22,$A2,$0C,$7E,$3E,$3E,$3E,$84,$3E,$3E,$85,$3E,$3E,$3E,$7F
; ground
.db $22,$C0,$10,$46,$47,$46,$47,$46,$47,$46,$47,$46,$47,$46,$47,$46,$47,$46,$47
.db $22,$D0,$10,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45
.db $22,$E0,$20,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45
.db $23,$00,$20,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87,$86,$87
.db $23,$20,$60,$3E
.db $23,$40,$60,$3E
.db $23,$60,$20,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40,$3F,$40
.db $23,$80,$60,$3D
.db $23,$A0,$60,$3D
; hill
.db $22,$56,$0A,$50,$51,$46,$47,$46,$47,$46,$47,$46,$47
.db $22,$74,$0C,$50,$51,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45
.db $22,$92,$0E,$50,$51,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45
.db $22,$B0,$10,$50,$51,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45,$44,$45
; small cacti
.db $22,$38,$08,$69,$6B,$6D,$6B,$6D,$6B,$6D,$6F
.db $22,$18,$08,$68,$6A,$6C,$6A,$6C,$6A,$6C,$6E
; cloud 0
.db $21,$4A,$02,$70,$71
.db $21,$69,$04,$72,$3C,$3C,$73
.db $21,$89,$04,$74,$75,$76,$77
; cloud 1
.db $20,$85,$02,$70,$71
.db $20,$A4,$04,$72,$3C,$3C,$73
.db $20,$C4,$04,$74,$75,$76,$77
; cloud 2
.db $21,$7B,$02,$70,$71
.db $21,$9A,$04,$72,$3C,$3C,$73
.db $21,$BA,$04,$74,$75,$76,$77
; cloud & text attributes
.db $23,$C0,$58,$55
.db $23,$DA,$42,$55
.db $23,$DE,$42,$55
.db 0

.char "MADE BY KENT HANSEN" : .db 0

@@palette:
; 0 - background
.db $21,$0F,$2A,$1A
; 1 - cloud and text
.db $21,$0F,$30,$3C
; 2 - heart and flag
.db $21,$23,$13,$0F
; 3 - patron
.db $21,$0F,$2A,$1A
; 0 - bob-omb type 1
.db $21,$20,$06,$0F
; 1 - bob-omb type 2
.db $21,$0F,$17,$20
; 2 - explosion
.db $21,$20,$06,$0F
; 3
.db $21,$20,$06,$0F
.endp

.proc prng
    lda random
    lsr
    bcc +
    eor #$B4
  + sta random
    rts
.endp

.proc main_handler
    jsr reset_sprites
    jsr scroll_screen
    jsr maybe_spawn_creature
    jsr check_explode_request
    jsr update_objects
    jsr update_pulsating_heart
    jsr update_patron_palette
    jsr mute_or_unmute_channels
    progbuf_load main_handler
    jmp progbuf_push
.endp

.proc check_explode_request
    lda explode_request
    bne +
    lda joypad0_posedge
    and #JOYPAD_BUTTON_START
    beq +
    inc explode_request
  + rts
.endp

.proc update_patron_palette
    lda frame_count
    and #31
    beq +
    rts
  + ldy #$3F
    lda #$0D
    ldx #3
    jsr begin_ppu_string
    jsr prng
    and #$3F
    sta ppu_buffer,x
    inx
    jsr prng
    and #$3F
    sta ppu_buffer,x
    inx
    jsr prng
    and #$3F
    sta ppu_buffer,x
    inx
    jmp end_ppu_string
.endp

.proc update_pulsating_heart
    lda frame_count
    and #15
    beq +
    rts
  + ; upper half
    ldy #$24
    lda #$ED
    ldx #2
    jsr begin_ppu_string
    lda frame_count
    lsr : lsr : lsr : lsr
    and #3
    pha
    tay
    lda #$88
    adc @@tile_offsets,y
    sta ppu_buffer,x
    inx
    lda #$89
    adc @@tile_offsets,y
    sta ppu_buffer,x
    inx
    jsr end_ppu_string
    ; lower half
    ldy #$25
    lda #$0D
    ldx #2
    jsr begin_ppu_string
    pla
    tay
    lda #$8A
    adc @@tile_offsets,y
    sta ppu_buffer,x
    inx
    lda #$8B
    adc @@tile_offsets,y
    sta ppu_buffer,x
    inx
    jmp end_ppu_string
    @@tile_offsets:
    db 0, 4, 8, 4
    rts
.endp

.proc scroll_screen
    lda frame_count
    and #15
    bne @@no_scroll
    inc ppu.scroll_x
    bne @@no_scroll
    lda world_page
    clc
    adc #1
    sta world_page
    lda ppu.ctrl0
    eor #1
    sta ppu.ctrl0
    @@no_scroll:
    rts
.endp

.proc mute_or_unmute_channels
    lda joypad0_posedge
    and #JOYPAD_BUTTON_UP
    beq @@up_not_pressed
    ; toggle channel 1
    lda sound_status
    eor #1
    sta sound_status
    @@up_not_pressed:
    lda joypad0_posedge
    and #JOYPAD_BUTTON_DOWN
    beq @@down_not_pressed
    ; toggle channel 2
    lda sound_status
    eor #2
    sta sound_status
    @@down_not_pressed:
    lda joypad0_posedge
    and #JOYPAD_BUTTON_LEFT
    beq @@left_not_pressed
    ; toggle channel 3
    lda sound_status
    eor #4
    sta sound_status
    @@left_not_pressed:
    lda joypad0_posedge
    and #JOYPAD_BUTTON_RIGHT
    beq @@right_not_pressed
    ; toggle channel 4
    lda sound_status
    eor #8
    sta sound_status
    @@right_not_pressed:
    lda joypad0_posedge
    and #(JOYPAD_BUTTON_A | JOYPAD_BUTTON_B)
    beq @@a_or_b_not_pressed
    ; toggle channel 5
    lda sound_status
    eor #16
    sta sound_status
    @@a_or_b_not_pressed:
    rts
.endp

.proc noop
  rts
.endp

.proc init_objects
    lda #>objects_arena
    sta objects_free_head.hi
    sta tp.hi
    lda #<objects_arena
    sta objects_free_head.lo
    sta tp.lo
    ldy #object::next
    ldx #MAX_OBJECTS-1
    @@10:
    clc
    adc #sizeof object
    sta [tp],y ; next.lo
    iny
    pha ; next.lo
    lda tp.hi
    adc #0
    sta [tp],y ; next.hi
    sta tp.hi
    pla ; next.lo
    sta tp.lo
    dey
    dex
    bne @@10
    lda #0
    sta [tp],y ; next.lo
    iny
    sta [tp],y ; next.hi
    sta objects_head.lo
    sta objects_head.hi
    rts
.endp

.proc allocate_object
    ; take the first object from free list
    lda objects_free_head.lo
    sta tp.lo
    lda objects_free_head.hi
    sta tp.hi
    ora tp.lo
    bne @@10
    ; out of memory
    brk
    @@10:
    ldy #object::next
    ; make free next the new free head
    lda [tp],y ; next.lo
    iny
    sta objects_free_head.lo
    lda [tp],y ; next.hi
    sta objects_free_head.hi
    ; make old objects head the next object
    lda objects_head.hi
    sta [tp],y ; next.hi
    dey
    lda objects_head.lo
    sta [tp],y ; next.lo
    ; make allocated object the new objects head
    lda tp.lo
    sta objects_head.lo
    lda tp.hi
    sta objects_head.hi
    rts
.endp

.proc update_objects
    lda #0
    sta kill_me
    lda objects_head.hi
    sta current_object.hi
    lda objects_head.lo
    sta current_object.lo
    pha
    ; clear the objects list
    lda #0
    sta objects_head.lo
    sta objects_head.hi
    pla
    @@object_loop:
    ora current_object.hi
    beq @@exit

    jsr update_object

    ldy #object::next
    lda [current_object],y ; next.lo
    iny
    pha ; next.lo
    lda [current_object],y ; next.hi
    pha ; next.hi
    lsr kill_me
    bcc @@keep_object
  ; move to free list
    lda objects_free_head.hi
    sta [current_object],y ; next.hi
    dey
    lda objects_free_head.lo
    sta [current_object],y ; next.lo
    lda current_object.lo
    sta objects_free_head.lo
    lda current_object.hi
    sta objects_free_head.hi

    pla ; next.hi
    sta current_object.hi
    pla ; next.lo
    sta current_object.lo
    jmp @@object_loop

    @@keep_object:
    ; make current object new head of objects
    lda objects_head.hi
    sta [current_object],y ; next.hi
    dey
    lda objects_head.lo
    sta [current_object],y ; next.lo
    lda current_object.lo
    sta objects_head.lo
    lda current_object.hi
    sta objects_head.hi

    pla ; next.hi
    sta current_object.hi
    pla ; next.lo
    sta current_object.lo
    jmp @@object_loop

    @@exit:
    rts
.endp

.proc update_object
    jmp update_bob_omb
.endp

.proc maybe_spawn_creature
    inc spawn_creature_timer
    lda spawn_creature_timer
    cmp #111
    bcc @@no_spawn
    lda #0
    sta spawn_creature_timer
    beq spawn_creature
@@no_spawn:
    sta spawn_creature_timer
    rts
.endp

.proc spawn_creature
    jsr allocate_object
    jsr prng
    and #3 ; type and direction
    ldy #object::state_0
    sta [tp],y ; state_0
    lda #0
    ldy #object::state_1
    sta [tp],y
    ldy #(object::pos_y + fp_8_8::frac)
    sta [tp],y
    ldy #(object::pos_x + fp_16_8::frac)
    sta [tp],y
    ldx #8
    ldy #object::state_0
    lda [tp], y
    and #2 ; direction (0=right, 1=left)
    beq +
    ldx #255
  + txa
    adc ppu.scroll_x
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    sta [tp],y
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda world_page
    bcc +
    adc #0
  + sta [tp],y
    lsr ; even or odd page
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [tp], y
    tax
    lda screen0_y_coordinate_by_x,x ; speculative fetch
    bcc +
    lda screen1_y_coordinate_by_x,x
  + ldy #(object::pos_y + fp_8_8::int)
    sta [tp],y
    rts
.endp

.proc convert_object_world_position_to_screen_position
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    sec
    sbc ppu.scroll_x
    ldy #object::screen_x
    sta [current_object], y
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    sbc world_page
    beq @@is_on_screen
    ldy #object::state_0
    lda [current_object], y
    ora #$80 ; off screen
    sta [current_object], y
    rts
    @@is_on_screen:
    ldy #object::state_0
    lda [current_object], y
    and #$7F ; on screen
    sta [current_object], y
    rts
.endp

screen0_y_coordinate_by_x:
.db 167,167,167,167,167,167,167,167,167,167,167,167,167,167,167,167
.db 167,167,167,167,167,167,167,167,167,167,167,167,167,167,167,167
.db 167,167,167,167,167,167,167,167,167,167,167,167,167,167,167,167
.db 167,167,167,167,167,167,167,167,167,167,167,167,167,167,167,167
.db 167,167,167,167,167,167,167,167,167,167,167,167,167,167,167,167
.db 167,167,167,167,167,167,167,167,167,167,167,167,167,167,167,167
.db 167,167,167,167,167,167,167,167,167,167,167,167,167,167,167,167
.db 167,167,167,167,167,167,167,167,167,167,167,167,167,167,167,167
.db 167,167,166,166,165,165,164,164,163,163,162,162,161,161,160,160
.db 159,159,158,158,157,157,156,156,155,155,154,154,153,153,152,152
.db 151,151,150,150,149,149,148,148,147,147,146,146,145,145,144,144
.db 143,143,142,142,141,141,140,140,139,139,138,138,137,137,136,136
.db 135,135,135,135,135,135,135,135,135,135,135,135,135,135,135,135
.db 135,135,135,135,135,135,135,135,135,135,135,135,135,135,135,135
.db 135,135,135,135,135,135,135,135,135,135,135,135,135,135,135,135
.db 135,135,135,135,135,135,135,135,135,135,135,135,135,135,135,135
screen1_y_coordinate_by_x:
.db 135,135,134,134,133,133,132,132,131,131,130,130,129,129,128,128
.db 127,126,125,124,123,122,121,120,119,118,117,116,115,114,113,112
.db 111,111,110,110,109,109,108,108,107,107,106,106,105,105,104,104
.db 104,104,105,105,106,106,107,107,108,108,109,109,110,110,111,111
.db 112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127
.db 128,128,129,129,130,130,131,131,132,132,133,133,134,134,135,135
.db 136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151
.db 150,150,151,151,152,152,153,153,154,154,155,155,156,156,157,157
.db 158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173
.db 174,174,175,175,176,176,177,177,178,178,179,179,180,180,181,181
.db 182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197
.db 198,198,199,199,200,200,201,201,202,202,203,204,205,206,207,208
.db 207,207,206,206,205,205,204,204,203,203,202,202,201,201,200,200
.db 199,199,198,198,197,197,196,196,195,195,194,194,193,193,192,192
.db 191,190,189,188,187,186,185,184,183,182,181,180,179,178,177,176
.db 175,175,174,174,173,173,172,172,171,171,170,170,169,169,168,168

.proc update_bob_omb
    ldy #object::state_0
    lda [current_object],y
    and #4 ; exploding?
    beq @@not_exploding
    @@is_exploding:
    ldy #object::state_1
    lda [current_object],y
    clc
    adc #1
    sta [current_object],y
    cmp #32
    bcc +
    inc kill_me
  + jmp draw_bob_omb_exploding
    @@not_exploding:
    ; wants to explode?
    lda explode_request
    beq +
    dec explode_request
    lda [current_object],y
    ora #4
    sta [current_object],y
    bne @@is_exploding
  + ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    lsr ; even or odd page
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    tax
    lda screen0_y_coordinate_by_x,x ; speculative fetch
    bcc + ; even page?
    lda screen1_y_coordinate_by_x,x
  + ldy #(object::pos_y + fp_8_8::int)
    sta [current_object], y
    ldy #object::state_0
    lda [current_object], y
    and #2
    beq @@move_right
    ; move left
    ldy #(object::pos_x + fp_16_8::frac)
    lda [current_object], y
    sec
    sbc #128
    sta [current_object], y
    bcs +
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    sbc #0
    sta [current_object], y
    bcs +
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    sbc #0
    sta [current_object], y
  + jsr convert_object_world_position_to_screen_position
    bmi @@kill_it
    ldy #object::screen_x
    lda [current_object], y
    cmp #8
    bcc @@kill_it
    and #4
    bne +
    jmp draw_bob_omb_left_frame0
    @@kill_it:
    inc kill_me
    rts
  + jmp draw_bob_omb_left_frame1
    @@move_right:
    ldy #(object::pos_x + fp_16_8::frac)
    lda [current_object], y
    clc
    adc #128
    sta [current_object], y
    bcc +
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    adc #0
    sta [current_object], y
    bcc +
    ldy #(object::pos_x + fp_16_8::int + int16::hi)
    lda [current_object], y
    adc #0
    sta [current_object], y
  + jsr convert_object_world_position_to_screen_position
    bmi @@kill_it
    ldy #(object::pos_x + fp_16_8::int + int16::lo)
    lda [current_object], y
    and #4
    bne +
    beq draw_bob_omb_right_frame0
  + jmp draw_bob_omb_right_frame1
.endp

.proc draw_bob_omb_right_frame0
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  ldy #object::state_0
  lda [current_object], y
  and #1 ; type
  pha
  asl : asl : asl
  ora #$03
  sta sprites.tile,x
  pla ; type
  pha
  ora #SPRITE_ATTR_H_FLIP
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  pla ; type
  pha
  asl : asl : asl
  ora #$01
  sta sprites.tile,x
  pla ; type
  ora #SPRITE_ATTR_H_FLIP
  sta sprites.attr,x
  rts
.endp

.proc draw_bob_omb_right_frame1
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  ldy #object::state_0
  lda [current_object], y
  and #1 ; type
  pha
  asl : asl : asl
  ora #$07
  sta sprites.tile,x
  pla ; type
  pha
  ora #SPRITE_ATTR_H_FLIP
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  pla ; type
  pha
  asl : asl : asl
  ora #$05
  sta sprites.tile,x
  pla ; type
  ora #SPRITE_ATTR_H_FLIP
  sta sprites.attr,x
  rts
.endp

.proc draw_bob_omb_left_frame0
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  ldy #object::state_0
  lda [current_object], y
  and #1 ; type
  pha
  asl : asl : asl
  ora #$01
  sta sprites.tile,x
  pla ; type
  pha
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  pla ; type
  pha
  asl : asl : asl
  ora #$03
  sta sprites.tile,x
  pla ; type
  sta sprites.attr,x
  rts
.endp

.proc draw_bob_omb_left_frame1
  ; left half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  sta sprites._x,x
  ldy #object::state_0
  lda [current_object], y
  and #1 ; type
  pha
  asl : asl : asl
  ora #$05
  sta sprites.tile,x
  pla ; type
  pha
  sta sprites.attr,x
  ; right half
  jsr next_sprite_index
  tax
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #8
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  pla ; type
  pha
  asl : asl : asl
  ora #$07
  sta sprites.tile,x
  pla ; type
  sta sprites.attr,x
  rts
.endp

.proc draw_bob_omb_exploding
  ; (0, 0)
  jsr next_sprite_index
  tax
  ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #16
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  ldy #object::state_0
  lda #$11
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; (1, 0)
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  ldy #object::state_0
  lda #$13
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; (2, 0)
  jsr next_sprite_index
  tax
+ ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  ldy #object::state_0
  lda #$15
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; (3, 0)
  jsr next_sprite_index
  tax
  ldy #object::screen_x
  lda [current_object], y
  clc
  adc #8
  bcs +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sec
  sbc #16
  sta sprites._y,x
  ldy #object::state_0
  lda #$17
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; (0, 1)
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #16
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  ldy #object::state_0
  lda #$19
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; (1, 1)
  jsr next_sprite_index
  tax
+ ldy #object::screen_x
  lda [current_object], y
  sec
  sbc #8
  bcc +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  ldy #object::state_0
  lda #$1B
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; (2, 1)
  jsr next_sprite_index
  tax
+ ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  ldy #object::screen_x
  lda [current_object], y
  sta sprites._x,x
  ldy #object::state_0
  lda #$1D
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
  ; (3, 1)
  jsr next_sprite_index
  tax
  ldy #object::screen_x
  lda [current_object], y
  clc
  adc #8
  bcs +
  sta sprites._x,x
  ldy #(object::pos_y + fp_8_8::int)
  lda [current_object], y
  sta sprites._y,x
  ldy #object::state_0
  lda #$1F
  sta sprites.tile,x
  lda #2
  sta sprites.attr,x
+ rts
.endp

.end
