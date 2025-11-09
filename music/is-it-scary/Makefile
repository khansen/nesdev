.DELETE_ON_ERROR:

# the path to the directory that contains the shared source code
BASESRCDIR = ./src

# assembler (xasm) flags
AFLAGS = --debug -I. -I$(BASESRCDIR) -DNO_SFX -DNO_JOYPAD1

# linker (xlnk) flags
LFLAGS = 

# command to invoke assembler
XASM = xasm $(AFLAGS)

# command to invoke linker
XLNK = xlnk $(LFLAGS)

COMMON_OBJS = \
    progbuf.o \
    bitmasktable.o \
    sprite.o \
    tablecall.o \
    joypad.o \
    palette.o \
    ppu.o \
    ppuwrite.o \
    ppubuffer.o \
    irq.o \
    nmi.o \
    reset.o \
    vectors.o

SOUND_OBJS = \
    periodtable.o \
    volumetable.o \
    envelope.o \
    effect.o \
    tonal.o \
	dmc.o \
    mixer.o \
    sequencer.o \
    sound.o

OBJS = $(COMMON_OBJS) $(SOUND_OBJS) \
    main.o \
    songtable.o \
    song.o \
	dmcdata.o

CHRS = font.bin moon.bin bat.bin packchr.chr

PROGRAM = IsItScary

# the name of the 16-byte iNES header binary file
HEADERFILE = header.bin

# the name of the linker script
SCRIPTFILE = link.s

# the name of the final binary (NES ROM)
BINFILE = $(PROGRAM).nes

$(BINFILE): $(OBJS) $(SCRIPTFILE) $(CHRS) header.bin
	$(XLNK) $(SCRIPTFILE)

periodtable.o: $(BASESRCDIR)/sound/periodtable.asm
	$(XASM) $< -o $@

volumetable.o: $(BASESRCDIR)/sound/volumetable.asm
	$(XASM) $< -o $@

envelope.o: $(BASESRCDIR)/sound/envelope.asm
	$(XASM) $< -o $@

effect.o: $(BASESRCDIR)/sound/effect.asm
	$(XASM) $< -o $@

tonal.o: $(BASESRCDIR)/sound/tonal.asm
	$(XASM) $< -o $@

dmc.o: $(BASESRCDIR)/sound/dmc.asm
	$(XASM) $< -o $@

sequencer.o: $(BASESRCDIR)/sound/sequencer.asm
	$(XASM) $< -o $@

mixer.o: $(BASESRCDIR)/sound/mixer.asm
	$(XASM) $< -o $@

sound.o: $(BASESRCDIR)/sound/sound.asm
	$(XASM) $< -o $@

progbuf.o: $(BASESRCDIR)/common/progbuf.asm
	$(XASM) $< -o $@

bitmasktable.o: $(BASESRCDIR)/common/bitmasktable.asm
	$(XASM) $< -o $@

sprite.o: $(BASESRCDIR)/common/sprite.asm
	$(XASM) $< -o $@

tablecall.o: $(BASESRCDIR)/common/tablecall.asm
	$(XASM) $< -o $@

joypad.o: $(BASESRCDIR)/common/joypad.asm
	$(XASM) $< -o $@

palette.o: $(BASESRCDIR)/common/palette.asm
	$(XASM) $< -o $@

ppu.o: $(BASESRCDIR)/common/ppu.asm
	$(XASM) $< -o $@

ppuwrite.o: $(BASESRCDIR)/common/ppuwrite.asm
	$(XASM) $< -o $@

ppubuffer.o: $(BASESRCDIR)/common/ppubuffer.asm
	$(XASM) $< -o $@

irq.o: $(BASESRCDIR)/common/irq.asm
	$(XASM) $< -o $@

nmi.o: $(BASESRCDIR)/common/nmi.asm
	$(XASM) $< -o $@

reset.o: $(BASESRCDIR)/common/reset.asm
	$(XASM) $< -o $@

vectors.o: $(BASESRCDIR)/common/vectors.asm
	$(XASM) $< -o $@

main.o: main.asm song.tbl packnam.dat
	$(XASM) $< -o $@

songtable.o: songtable.asm
	$(XASM) $< -o $@

song.o: song.asm song.inc
	$(XASM) $< -o $@

song.inc: song.xm instruments.map
	xm2nes --channels=0,1,2,3,4 --instruments-map=instruments.map $< > $@

dmcdata.o: dmcdata.asm
	$(XASM) $< -o $@

packchr.chr packchr.nam: ghosts.chr
	packchr --null-tile=0 --nametable-base=56 $<

packnam.dat: packchr.nam
	packnam --width=24 --vram-address=0x2024 $<

.PHONY: clean

clean:
	-rm -f $(BINFILE) $(OBJS) song.inc packchr.chr packnam.dat

play: $(BINFILE)
	fceux $(BINFILE)
