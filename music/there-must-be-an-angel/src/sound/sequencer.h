.ifndef SEQUENCER_H
.define SEQUENCER_H

; Exported symbols.
.extrn sequencer_tick:proc
.extrn sequencer_load:proc
.extrn fetch_pattern_byte:proc
.extrn set_track_speed:proc
.extrn set_all_tracks_speed:proc
.ifdef PATTERN_ROW_CALLBACK_SUPPORT
.extrn set_pattern_row_callback:proc
.endif
.ifdef ORDER_SEEKING_SUPPORT
.extrn sequencer_seek_order_relative:proc
.endif

.endif
