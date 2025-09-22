; Description:
; DMC audio stuff.

.codeseg

; exported API
.public play_dmc_sample
.public process_dmc_pattern_byte

.extrn fetch_pattern_byte:proc
.extrn set_all_tracks_speed:proc
.extrn dmc_sample_table:byte

.ifndef NO_MUTABLE_CHANNELS
.extrn mixer_get_muted_channels:proc
.endif

.proc process_dmc_pattern_byte
    ora     #0
    bmi     @@is_command
; FIXME: actual DMC playback should be commenced by the mixer...
.ifndef NO_MUTABLE_CHANNELS
    tay
    jsr     mixer_get_muted_channels
    and     #$10
    bne     +
    tya
    jsr     play_dmc_sample
  +
.endif
    clc
    rts
    @@is_command:
    ; only supported commands are "set speed" and "end row"
    cmp     #$D0
    bcc     @@is_compact_set_speed_command
    cmp     #$F2
    beq     @@is_extended_set_speed_command
    cmp     #$F3
    beq     @@is_end_row_command
    ; uh-oh, don't know how to handle this command
    clc
    rts

    @@is_compact_set_speed_command:
    and     #$0F ; new speed - 1 in lower 4 bits
.ifndef NO_SPEED_ADJUSTMENT
    adc     #1
.endif
    jsr     set_all_tracks_speed
    sec
    rts

    @@is_extended_set_speed_command:
    jsr     fetch_pattern_byte
.ifndef NO_SPEED_ADJUSTMENT
    clc
    adc     #1
.endif
    jsr     set_all_tracks_speed
    sec
    rts

    @@is_end_row_command:
    clc
    rts
.endp

; Plays a DMC sample.
; Params:   A = sample #
.proc play_dmc_sample
    asl
    asl
    tay
    lda     dmc_sample_table+0,y
    sta     $4010                   ; write sample frequency
    lda     dmc_sample_table+1,y
    sta     $4011                   ; write initial delta value
    lda     dmc_sample_table+2,y
    sta     $4012                   ; write sample address
    lda     dmc_sample_table+3,y
    sta     $4013                   ; write sample length
    lda     #$0F
    sta     $4015                   ; turn bit 4 off...
    lda     #$1F
    sta     $4015                   ; ... then on again
    rts
.endp

.end
