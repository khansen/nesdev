.ifndef SOUND_H
.define SOUND_H

; Exported symbols.
.extrn start_song:proc
.extrn maybe_start_song:proc
.extrn update_sound:proc
.extrn pause_music:proc
.extrn unpause_music:proc
.extrn is_music_paused:proc
.extrn start_audio_fade_out:proc
.extrn current_song:byte

.endif
