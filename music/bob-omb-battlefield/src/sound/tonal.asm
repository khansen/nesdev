; Description:
; Handles pattern commands for channels 0,1,2,3.

.include <common/tablecall.h>
.include "mixer.h"
.include "track.h"

.dataseg

global_transpose .db

.public global_transpose

play_note_callback .ptr

.codeseg

.public process_tonal_pattern_byte
.public set_play_note_callback

.extrn mixer:mixer_state
.extrn table_call:proc
.extrn fetch_pattern_byte:proc
.extrn set_track_speed:proc
.extrn set_all_tracks_speed:proc
.extrn period_table_lo:byte
.extrn period_table_hi:byte
.extrn instrument_table:ptr
.extrn tracks:track_state

; Processes one byte received on channel.
; Params:   A = byte
;           X = offset of channel data
; Returns: CF = 0 if stop processing pattern data
.proc process_tonal_pattern_byte
    cmp     #$B0
    bcc     is_note
    cmp     #$C0
    bcc     is_set_instrument_command
    cmp     #$D0
    bcc     is_set_speed_command
    cmp     #$E0
    bcc     is_set_volume_command
    cmp     #$F0
    and     #$0F
    bcs     is_other_command
    ; set effect + param
    sta     mixer.tonals.effect.kind,x
    beq     +
    jsr     fetch_pattern_byte
    sta     mixer.tonals.effect.slide.amount,x      ; this is a union
    lda     #0
    lda     mixer.tonals.effect.vibrato.delay,x
    sta     mixer.tonals.effect.vibrato.counter,x
    sta     mixer.tonals.effect.vibrato.pos,x
  + sec
    rts

    is_set_instrument_command:
    and     #$0F ; instrument in lower 4 bits
    jsr     set_instrument
    sec
    rts

    is_set_speed_command:
    and     #$0F ; new speed - 1 in lower 4 bits
.ifndef NO_SPEED_ADJUSTMENT
    adc     #1
.endif
    jsr     set_speed
    sec
    rts

    is_set_volume_command:
    and     #$0F
    asl : asl : asl : asl
    ora     #1 ; indicates that volume was explicitly set
    sta     mixer.envelopes.master,x
    sec
    rts

    is_other_command:
    jsr     go_command
    sec
    rts

    is_note:
    clc
    adc     tracks.pattern.transpose,x
    adc     global_transpose
    pha
    lda     #$80
    sta     mixer.tonals.square.period_save,x ; this is a union
    lda     mixer.envelopes.master,x
    lsr     ; CF=1 if the volume has been overridden by a previous volume command
    bcs     +
    lda     #$78
  + asl
    sta     mixer.envelopes.master,x
    lda     #ENV_RESET
    sta     mixer.envelopes.phase,x             ; volume envelope phase = init
    lda     #0
    sta     mixer.tonals.effect.vibrato.pos,x        ; reset vibrato position
    lda     mixer.tonals.effect.vibrato.delay,x
    sta     mixer.tonals.effect.vibrato.counter,x          ; reset vibrato delay
    pla
    ldy     mixer.tonals.effect.kind,x
    cpy     #PORTAMENTO_EFFECT  ; if slide parameter present...
    beq     init_slide          ; ... slide from old to new note
; no slide, set new period immediately
    sta     mixer.tonals.period_index,x
    tay
    lda     period_table_lo,y
    sta     mixer.tonals.period.lo,x
    lda     period_table_hi,y
    sta     mixer.tonals.period.hi,x
; channel-specific init
; ### consider making a plain effect
    lda     mixer.tonals.square.duty_ctrl,x
    pha
    and     #$C0 ; initial duty cycle
    sta     mixer.tonals.square.duty,x
    pla
    and     #$0C
    lsr : lsr ; initial counter
    sta     mixer.tonals.square.counter,x
;
    txa
    pha
    jsr call_play_note_callback
    pla
    tax
    clc
    rts

    init_slide:
    cmp     mixer.tonals.period_index,x              ; CF = slide direction (0=down,1=up)
    sta     mixer.tonals.period_index,x
    tay
    lda     period_table_lo,y
    sta     mixer.tonals.effect.portamento.target.lo,x
    lda     period_table_hi,y
    sta     mixer.tonals.effect.portamento.target.hi,x
;
    lda     #$40
    rol     ; bit 0 = slide direction
    sta     mixer.tonals.effect.portamento.ctrl,x
    rts
.endp

.proc set_play_note_callback
    sta play_note_callback.lo
    sty play_note_callback.hi
    rts
.endp

.proc call_play_note_callback
    jmp [play_note_callback]
.endp

; Processes a channel command.

.proc go_command
    jsr     table_call
TC_SLOT set_instr_command
TC_SLOT release_command
TC_SLOT set_speed_command
TC_SLOT end_row_command
.endp

; Sets instrument.

set_instr_command:
    jsr     fetch_pattern_byte
; fall-through
.proc set_instrument
    sta     mixer.tonals.instrument,x
    asl
    asl
    asl                     ; each instrument is 8 bytes long
    tay
    lda     [instrument_table],y
    sta     mixer.envelopes.ptr.lo,x
    iny
    lda     [instrument_table],y
    sta     mixer.envelopes.ptr.hi,x
    iny
    lda     [instrument_table],y
    sta     mixer.tonals.effect.vibrato.delay,x
    iny
    lda     [instrument_table],y
    sta     mixer.tonals.effect.kind,x
    iny
    lda     [instrument_table],y
    sta     mixer.tonals.effect.slide.amount,x
    iny
    lda     [instrument_table],y
    sta     mixer.tonals.square.duty_ctrl,x ; this is a union
    rts
.endp

; Disables volume envelope looping.

.proc release_command
    lda     #1
    sta     mixer.envelopes.hold,x
    rts
.endp

; Sets the speed.

set_speed_command:
    jsr     fetch_pattern_byte
.ifndef NO_SPEED_ADJUSTMENT
    clc
    adc #1
.endif
; fall-through
.proc set_speed
; ### this is buggy
.if 0
    jsr     set_track_speed
.else
    jsr     set_all_tracks_speed
.endif
    rts
.endp

; this command is used when there is no note for the row, only commands
.proc end_row_command
    lda     mixer.envelopes.master,x
    and     #$FE
    sta     mixer.envelopes.master,x
    pla
    pla
    clc
    rts
.endp

.end
