%.bin: %.s
	vasm6502_oldstyle -Fbin -dotdir -o $@ $^
