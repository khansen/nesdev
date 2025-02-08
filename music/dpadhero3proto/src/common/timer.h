.ifndef TIMER_H
.define TIMER_H

; Exported symbols.
.extrn reset_timers:proc
.extrn start_timer:proc
.extrn set_timer_callback:proc
.extrn kill_timer:proc
.extrn update_timers:proc
.extrn start_zerotimer_with_callback:proc
.extrn call_fptr:proc

.endif
