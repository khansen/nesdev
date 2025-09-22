sample0:
.incbin "adjusted_quiet_x2.dmc"
sample1:
.incbin "clap.dmc"
sample2:
.incbin "Kirby_$FE80.dmc"
sample2_end:

.public dmc_sample_table
dmc_sample_table:
.db $0F,$48,(sample0-$C000)/64,(sample1-sample0)/16-1 ; 0=bass drum
.db $0F,$48,(sample1-$C000)/64,(sample2-sample1)/16-1 ; 1=snare drum
.db $0F,$48,(sample2-$C000)/64,(sample2_end-sample2)/16-1 ; 2=conga
