SOURCES= \
    blink.s \
    blink_all.s \
    blink_and_count.s \
    rotate.s \
    lcd.s \
    hello_world.s \
    bintodec.s \
    interrupt_game.s \
    echo.s \
    sdio_hello.s \
    sdio_prg.s \
    fat_test.s \
    xmodem.s

PRG_SOURCES= \
    hello_world_load.s

ROM_SOURCES= \

ROMS=$(SOURCES:.s=.bin) $(ROM_SOURCES:.s=.bin)
PRGS=$(SOURCES:.s=.prg) $(PRG_SOURCES:.s=.prg)

all: $(ROMS) $(PRGS)

include $(SOURCES:.s=.bin.d)
include $(SOURCES:.s=.prg.d)
include $(ROM_SOURCES:.s=.bin.d)
include $(PRG_SOURCES:.s=.prg.d)

%.bin.d: %.s
	vasm6502_oldstyle -quiet -c02 -Fbin -dotdir -opt-branch -DROM -depend=make -o $*.bin $< > $@

%.prg.d: %.s
	vasm6502_oldstyle -quiet -c02 -Fbin -dotdir -opt-branch -depend=make -o $*.prg $< > $@

%.bin: %.s
	vasm6502_oldstyle -c02 -Fbin -dotdir -opt-branch -DROM -L $@.lst -o $@ $<

%.prg: %.s
	vasm6502_oldstyle -c02 -Fbin -dotdir -opt-branch -cbm-prg -L $@.lst -o $@ $<

%.bin.burn: %.bin
	minipro -p AT28C256 -w $<
