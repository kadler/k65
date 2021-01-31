; SD card example for Ben Eater's 6502 computer kit
; bit-bangs SPI interface to SD card on 6522 VIA 2
; This program will load an ASCII string from the
; first 128 bytes of the SD card and execute it.
;
; SPDX-License-Identifier: GPL-3.0-or-later

VERBOSE = 1

  .include header.inc.s

  .ifndef ROM
main:
  jmp reset
  .endif

  ; sdio.inc.s needs to come first for PUTS definition
  .include lcd.inc.s
  .include delay.inc.s
  .include sdio.inc.s

  .ifdef ROM
nmi:
irq:
  rti
  .endif

reset:
  jsr lcd_init

  ; Print a startup message
  lda #<STARTUP
  sta R1
  lda #>STARTUP
  sta R1+1
  jsr puts

  jsr sd_init
  bcs .done

  ; Load and print a string
  jsr sd_load_string
  bcs .done

  lda #<SD_DTA
  sta R1
  lda #>SD_DTA
  sta R1+1
  jsr puts

.done:
  .ifdef ROM
  jmp .done
  .else
  rts
  .endif


sd_load_string:
  ; Set block size to 128
  SET_CMD_FIELDS 16, 128, 0

  jsr sd_cmd
  bne .error

  ; Read a block of data (128 bytes)
  SET_CMD_FIELDS 17, 0, SD_FLG_DTA

  lda #<SD_DTA
  sta R1
  lda #>SD_DTA
  sta R1+1

  lda #128
  sta R2
  lda #0
  sta R2+1

  jsr sd_cmd
  bne .error

  clc
  rts

.error:
  sta SD_DTA
  lda #0
  sta SD_DTA+1
  sta SD_DTA+2
  sta SD_DTA+3
  jsr hexdump
  sec
  rts


STARTUP
  .asciiz "Load msg from SD"

; vim: syntax=asm6502
