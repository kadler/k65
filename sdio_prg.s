; SD card example for Ben Eater's 6502 computer kit
; bit-bangs SPI interface to SD card on 6522 VIA 2
; This program will load a C64 PRG-style binary from
; the first 256 bytes of the SD card and execute it.
;
; SPDX-License-Identifier: GPL-3.0-or-later

  .include header.inc.s

syscall_puts:
  jmp puts

syscall_lcd_cmd:
  jmp lcd_cmd

syscall_delayms:
  jmp delayms

  .include lcd.inc.s
  .include delay.inc.s
  .include sdio.inc.s

nmi:
irq:
  rti

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

  ; Load and run program #0
  lda #0
  jsr sd_load_prg
  jsr trampoline

.done:
  jmp .done

trampoline:
  jmp (R1)

; index is in accumulator
; load address will be returned in R1
sd_load_prg:
  pha

  ; Read the load address from the program
  SET_CMD_FIELDS 16, 2, 0

  ; For now, each program is 256 bytes for easy indexing
  ; We can just stick the "index" in to the third byte and
  ; set the rest to 0
  pla
  sta SD_ARG+2
  pha

  jsr sd_cmd
  bne cmd_error

  SET_CMD_FIELDS 17, 0, SD_FLG_DTA

  ; We're going to re-use the SD_DTA field since it's so small
  lda #<SD_DTA
  sta R1
  lda #>SD_DTA
  sta R1+1

  ; Set our data size - 2 bytes for the address
  lda #2
  sta R2
  lda #0
  sta R2+1

  jsr sd_cmd
  bne cmd_error

  ; Now have address in SD_DTA, copy to R2 and read 64 bytes
  ; Need to save the load address for later use
  lda SD_DTA
  tax
  lda SD_DTA+1
  tay

  lda #($40 | 16)
  sta SD_CMD

  SET_CMD_FIELDS 16, 254, 0

  jsr sd_cmd
  bne cmd_error


  ; We already read the first two bytes, so set the address to 2
  SET_CMD_FIELDS 17, 2, SD_FLG_DTA
  ; Pull the index, and store it in the correct place
  pla
  sta SD_ARG+2

  ; We previously saved the load address in x,y
  stx R1
  sty R1+1

  lda #254
  sta R2
  lda #0
  sta R2+1

  jsr sd_cmd
  bne cmd_error

  ; sd_cmd modifies R1, so restore it
  stx R1
  sty R1+1

  rts

cmd_error:
  rts

STARTUP
  .asciiz "Load PRG from SD"

; vim: syntax=asm6502
