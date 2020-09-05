SOURCES= \
    blink_all.s \
    blink_and_count.s \
    rotate.s \
    lcd.s \
    hello_world.s

ROMS=$(SOURCES:.s=.bin)

all: $(ROMS)

include $(SOURCES:.s=.bin.d)

%.bin.d: %.s
	vasm6502_oldstyle -quiet -Fbin -dotdir -depend=make -o $*.bin $< > $@

%.bin: %.s
	vasm6502_oldstyle -Fbin -dotdir -o $@ $<

%.bin.burn: %.bin
	minipro -p AT28C256 -w $<
