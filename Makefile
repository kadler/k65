SOURCES= \
    blink.s \
    blink_all.s \
    blink_and_count.s \
    rotate.s \
    lcd.s \
    hello_world.s \
    bintodec.s \
    interrupt_game.s

ROMS=$(SOURCES:.s=.bin)

all: $(ROMS)

include $(SOURCES:.s=.bin.d)

%.bin.d: %.s
	vasm6502_oldstyle -quiet -c02 -Fbin -dotdir -depend=make -o $*.bin $< > $@

%.bin: %.s
	vasm6502_oldstyle -c02 -Fbin -dotdir -o $@ $<

%.bin.burn: %.bin
	minipro -p AT28C256 -w $<
