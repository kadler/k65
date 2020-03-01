SOURCES= \
    blink.s \
    blink2.s \
    rotate.s \
    lcd.s \
    hello_world.s

ROMS=$(SOURCES:.s=.bin)

all: $(ROMS)

%.bin: %.s
	vasm6502_oldstyle -Fbin -dotdir -o $@ $^

