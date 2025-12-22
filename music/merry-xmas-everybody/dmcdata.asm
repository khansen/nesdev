sample0:
.incbin "adjusted_quiet_x2.dmc"
sample1:
.incbin "clap.dmc"
sample1_end:

.public dmc_sample_table
dmc_sample_table:
.db $0F,$48,(sample0-$C000)/64,8 ; 0=bass drum
.db $0F,$48,(sample1-$C000)/64,(sample1_end-sample1)/16-1 ; 1=snare drum
