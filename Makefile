SOURCES= \
    blink.s \
    blink_all.s \
    blink_and_count.s \
    blink_shift.s \
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
    k65.s

ROMS=$(SOURCES:.s=.bin) $(ROM_SOURCES:.s=.bin)
PRGS=$(SOURCES:.s=.prg) $(PRG_SOURCES:.s=.prg)

all: $(ROMS) $(PRGS)

include $(SOURCES:.s=.bin.d)
include $(SOURCES:.s=.prg.d)
include $(ROM_SOURCES:.s=.bin.d)
include $(PRG_SOURCES:.s=.prg.d)

syscalls.inc.s: k65.bin.lst
	grep -E '(.*)_syscall EXPR' k65.bin.lst > $@.tmp
	sed 's/\(.*\)_syscall.*=0x\([0-9A-Fa-f]*\).*/\1 = $$\2/' $@.tmp > $@
	rm $@.tmp

%.bin.d: %.s
	vasm6502_oldstyle -quiet -c02 -Fbin -dotdir -opt-branch -DROM -depend=make -o $*.bin $< > $@

%.prg.d: %.s
	vasm6502_oldstyle -quiet -c02 -Fbin -dotdir -opt-branch -depend=make -o $*.prg $< > $@

%.bin %.bin.lst: %.s
	vasm6502_oldstyle -c02 -Fbin -dotdir -opt-branch -DROM -L $*.bin.lst -o $*.bin $<

%.bin.lst: %.bin

%.prg: %.s
	vasm6502_oldstyle -c02 -Fbin -dotdir -opt-branch -cbm-prg -L $@.lst -o $@ $<

%.bin.burn: %.bin
	minipro -p AT28C256 -w $<
