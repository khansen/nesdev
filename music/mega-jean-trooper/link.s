ram{start=$000,end=$1C0}
ram{start=$200,end=$800}
output{file=MegaJeanTrooper.nes}
copy{file=header.bin}
# Bank 0
bank{size=$4000,origin=$C000}
link{file=song.o}
link{file=song2.o}
link{file=progbuf.o}
link{file=bitmasktable.o}
link{file=periodtable.o}
link{file=volumetable.o}
link{file=envelope.o}
link{file=effect.o}
link{file=tonal.o}
link{file=mixer.o}
link{file=sequencer.o}
link{file=sound.o}
link{file=sprite.o}
link{file=tablecall.o}
link{file=palette.o}
link{file=ppu.o}
link{file=ppuwrite.o}
link{file=ppubuffer.o}
link{file=joypad.o}
link{file=irq.o}
link{file=nmi.o}
link{file=reset.o}
link{file=main.o}
link{file=songtable.o}
pad{origin=$FFFA}
link{file=vectors.o}
# CHR banks
bank{size=$1000}
copy{file=font.bin}
copy{file=flag.bin}
bank{size=$1000}
