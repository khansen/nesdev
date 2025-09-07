.ifndef MIXER_H
.define MIXER_H

.include "tonal.h"
.include "envelope.h"
.include "sfx.h"
.include "apu.h"

.struc mixer_state
tonals      .tonal_state[4]
envelopes   .envelope_state[4]
sfx         .sfx_state[4]
master_vol  .byte
.ends

; Exported symbols.
.extrn mixer_tick:proc
.extrn mixer_rese:proct
.ifndef NO_MUTABLE_CHANNELS
.extrn mixer_get_muted_channels:proc
.extrn mixer_set_muted_channels:proc
.endif
.extrn mixer_get_master_vol:proc
.extrn mixer_set_master_vol:proc

.extrn mixer:mixer_state

.endif  ; !MIXER_H
