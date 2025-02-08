; Description:
; The sequencer processes song structures and forwards music commands to the
; relevant sound channel handlers.

; Some quick notes on the "song" format.
; --------------------------------------
; It is inspired by MOD-style formats.
; There are five "tracks", one for each sound channel.
; With each track is associated an order table. At its simplest,
; the order table is a list of "pattern" indices. However, it can only
; contain special commands, such as looping and pattern transpose.
; A pattern consists of a number of rows. On the start of each row
; (tick 0), one or more commands can be executed on that track, such as
; "set instrument", "set effect", "set volume", "play note".
; A simple compression is used to keep patterns small. Every 8th row,
; the next pattern byte is a bitmask for the following 8 rows. If a
; bit is 1, that row has commands to be processed. If it is 0, no
; commands are processed for that row. So, for example, if there is a
; run of 8 rows where no note is played, it will occupy 1 byte with the
; value $00, while a run of 8 rows where a new note is triggered every
; row will occupy 1 byte with the value $FF PLUS however many bytes taken
; by the row commands (determined implicitly when they are processed).
;
; See also: mixer.asm, effect.asm, envelope.asm, tonals.asm, dmc.asm

.include "track.h"

.dataseg zeropage

; Pointer to order (temp).
order   .ptr

; Pointer to pattern (temp).
pattern .ptr

; Pointer to pattern pointer table.
pattern_table   .ptr

; Pointer to instrument table.
instrument_table .ptr

.public instrument_table
.public tracks

.dataseg

; Array of track states.
tracks      .track_state[5]

.ifdef ORDER_SEEKING_SUPPORT
; During normal playback, data processing enabled.
; During seeking, it's disabled.
pattern_processing_enabled .db
.endif

.ifdef PATTERN_ROW_CALLBACK_SUPPORT
pattern_row_callback .ptr
.endif

.codeseg

.public sequencer_tick
.public sequencer_load
.public fetch_pattern_byte
.public set_track_speed
.public set_all_tracks_speed
.ifdef PATTERN_ROW_CALLBACK_SUPPORT
.public set_pattern_row_callback
.endif
.ifdef ORDER_SEEKING_SUPPORT
.public sequencer_seek_order_relative
.endif

.extrn bitmasktable:byte

.extrn process_dmc_pattern_byte:proc
.extrn process_tonal_pattern_byte:proc

.ifdef BULLET_TIME_SUPPORT
.extrn time_mode:byte
.endif

; Gets the next byte from track's order data,
; and increments the order position.
; Params:   X = offset of track structure
; Returns:  A = order byte
;           F = flags
; Destroys: Y
.macro fetch_order_byte
    ldy tracks.order.pos,x
    inc tracks.order.pos,x
    lda [order],y
.endm

; Gets the next byte from track's pattern data,
; and increments the pattern position.
; Params:   X = offset of track structure
; Returns:  A = pattern byte
;           F = flags
; Destroys: Y
.proc fetch_pattern_byte
    ldy tracks.pattern.pos,x
    lda [pattern],y
    inc tracks.pattern.pos,x
    bne +
    inc pattern.hi
    inc tracks.pattern.ptr.hi,x
  + rts
.endp

; Updates sequencer tracks.

.proc sequencer_tick
    lda order.lo
    ora order.hi
    bne really_tick
    rts

    really_tick:
    ldx #0
; do one track
    track_tick:
; if order position is $FF, track isn't used
    lda tracks.order.pos,x
    cmp #$FF
    bne next_tick
    jmp next_track

    next_tick:
; increment tick
    inc tracks.tick,x
; check if reached new row
.ifdef BULLET_TIME_SUPPORT
    lda time_mode
    beq +
    asl tracks.speed,x
  +
.endif
    lda tracks.tick,x
    cmp tracks.speed,x
.ifdef BULLET_TIME_SUPPORT
    lda time_mode
    beq +
    php
    lsr tracks.speed,x
    plp
  +
.endif
    bcs next_row
    jmp next_track

    next_row:
.ifdef PATTERN_ROW_CALLBACK_SUPPORT
    cpx #sizeof track_state * 3
    bne +
    lda pattern_row_callback.hi
    beq +
    jsr call_pattern_row_callback
  +
.endif
; next row
    lda #0
    sta tracks.tick,x   ; reset tick
    inc tracks.pattern.row,x
; check if reached end of pattern
    lda tracks.pattern.row,x
    cmp tracks.pattern.row_count,x
    beq end_of_pattern
    jmp no_new_pattern

    end_of_pattern:
; end of pattern
    lda #0
    sta tracks.pattern.row,x    ; reset row
    sta tracks.pattern.pos,x
; check if pattern should be looped
    dec tracks.pattern.loop_count,x
    beq order_fetch_loop

; play same pattern again
    inc tracks.pattern.pos,x    ; skip pattern row count byte
    jmp no_new_pattern

    order_fetch_loop:
; fetch and process order data
    fetch_order_byte
; ### FIXME
    cmp #$F0
    bcs order_special

; pattern number in lower 7 bits
    inc tracks.pattern.loop_count,x ; = 1 (play pattern once)
    asl
    bcc +
    inc pattern_table.hi
  + tay
    lda [pattern_table],y
    iny
    sta tracks.pattern.ptr.lo,x
    sta pattern.lo
    lda [pattern_table],y
    sta tracks.pattern.ptr.hi,x
    sta pattern.hi
    bcc +
    dec pattern_table.hi
; fetch # of rows
  + jsr fetch_pattern_byte
    sta tracks.pattern.row_count,x
    jmp maybe_fetch_row_status

; process special order entry
    order_special:
    cmp #$F0
    bcc set_pattern_loop_count
; command
    cmp     #$FA
    beq     set_speed
    cmp     #$FB
    beq     set_order_loop
    cmp     #$FC
    beq     loop_order
    cmp     #$FD
    beq     set_transpose
    cmp     #$FE
    beq     set_order_pos
    bcs     stop_playing         ; $FF = stop playing the track

    set_speed:
    fetch_order_byte
    sta     tracks.speed,x
    jmp     order_fetch_loop
    
    set_order_loop:
    fetch_order_byte
    sta     tracks.order.loop_count,x
    lda     tracks.order.pos,x
    sta     tracks.order.loop_pos,x
    jmp     order_fetch_loop

    loop_order:
    dec     tracks.order.loop_count,x
    beq     order_fetch_loop
    lda     tracks.order.loop_pos,x
    sta     tracks.order.pos,x
    jmp     order_fetch_loop

    set_transpose:
    fetch_order_byte
    sta     tracks.pattern.transpose,x
    jmp     order_fetch_loop

    set_order_pos:
    fetch_order_byte
    sta     tracks.order.pos,x
    jmp     order_fetch_loop

    stop_playing:
    lda #$FF
    sta tracks.order.pos,x
    bne next_track

    set_pattern_loop_count:
    and #$7F
    sta tracks.pattern.loop_count,x
    jmp order_fetch_loop
;
    no_new_pattern:
    lda     tracks.pattern.ptr.lo,x
    sta     pattern.lo
    lda     tracks.pattern.ptr.hi,x
    sta     pattern.hi
;
    maybe_fetch_row_status:
.ifdef ORDER_SEEKING_SUPPORT
    lda pattern_processing_enabled
    beq next_track
.endif
    lda tracks.pattern.row,x
    and #7
    bne no_row_status_fetch

; fetch row status for upcoming 8 rows
    pha
    jsr fetch_pattern_byte
    sta tracks.pattern.row_status,x
    pla

    no_row_status_fetch:
    tay
.ifdef ORDER_SEEKING_SUPPORT
    lda pattern_processing_enabled
    beq next_track
.endif
    lda bitmasktable,y
    and tracks.pattern.row_status,x
    beq next_track

; fetch and process pattern data
    pattern_fetch_loop:
    jsr fetch_pattern_byte
    jsr process_pattern_byte
    bcs pattern_fetch_loop

    next_track:
    txa
    clc
    adc #sizeof track_state
    tax
    cpx #(sizeof track_state * 5)
    beq tracks_done
    jmp track_tick
    tracks_done:
    rts
.endp

.proc process_pattern_byte
.ifdef NO_DMC
    jmp process_tonal_pattern_byte
.else
    cpx #4*sizeof track_state
    beq +
    jmp process_tonal_pattern_byte
  + jmp process_dmc_pattern_byte
.endif
.endp

; Loads the sequencer tracks/order tables/pattern table.
; Params:   A = Low address of song structure
;           Y = High address of song structure

.proc sequencer_load
    sta order.lo
    sty order.hi
    ldy #0
    ldx #0
; init one track
  - lda [order],y
    iny
    sta tracks.order.pos,x
    cmp #$FF
    beq +
    lda [order],y
.ifndef NO_SPEED_ADJUSTMENT
    adc #1
.endif
    iny
    sta tracks.speed,x
    sta tracks.tick,x
.ifdef BULLET_TIME_SUPPORT
    lda time_mode
    beq ++
    asl tracks.tick,x
 ++
.endif
    dec tracks.tick,x
    lda #1
    sta tracks.pattern.row_count,x
    sta tracks.pattern.loop_count,x
    lda #0
    sta tracks.pattern.row,x
  + txa
    clc
    adc #sizeof track_state
    tax
    cpx #5*sizeof track_state
    bne -
; instrument table
    lda [order],y
    iny
    sta instrument_table.lo
    lda [order],y
    iny
    sta instrument_table.hi    
; pattern ptr table
    lda [order],y
    iny
    sta pattern_table.lo
    lda [order],y
    iny
    sta pattern_table.hi    
; advance order pointer to actual order
    tya
    clc
    adc order.lo
    sta order.lo
    bcc +
    inc order.hi
  +
.ifdef ORDER_SEEKING_SUPPORT
    lda #1
    sta pattern_processing_enabled
.endif
    rts
.endp

.proc set_track_speed
    sta tracks.speed,x
    rts
.endp

; Sets speed of all tracks.
; A = new speed
.proc set_all_tracks_speed
    sta tracks[0].speed
    sta tracks[1].speed
    sta tracks[2].speed
    sta tracks[3].speed
    sta tracks[4].speed
    rts
.endp

.ifdef PATTERN_ROW_CALLBACK_SUPPORT
.proc set_pattern_row_callback
    sta pattern_row_callback.lo
    sty pattern_row_callback.hi
    rts
.endp

.proc call_pattern_row_callback
    jmp [pattern_row_callback]
.endp
.endif

.ifdef ORDER_SEEKING_SUPPORT
; A = number of patterns to skip, starting from current order table position
.proc sequencer_seek_order_relative
 -- pha
    lda #0 : sta pattern_processing_enabled
    jsr sequencer_tick
    ldx #0
  - lda tracks.order.pos,x
    cmp #$FF
    beq +
    ; set current row to row_count - 1
    lda tracks.pattern.row_count,x
    sta tracks.pattern.row,x
    dec tracks.pattern.row,x
    ; set current tick to speed - 1
    lda tracks.speed,x
    sta tracks.tick,x
.ifdef BULLET_TIME_SUPPORT
    lda time_mode
    beq ++
    asl tracks.tick,x
 ++
.endif
    dec tracks.tick,x
  + txa : clc : adc #sizeof track_state : tax
    cpx #5*sizeof track_state
    bne -
    pla
    sec : sbc #1
    bpl --
    lda #1 : sta pattern_processing_enabled
    rts
.endp
.endif

.end
